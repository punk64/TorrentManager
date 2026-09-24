import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/digests/sha1.dart';

import 'app_log.dart';
import 'formatter.dart';
import 'update_check.dart';

/// 与原生侧约定的通道名（见 MainActivity.kt）。
const String kUpdateChannel = 'tm_updater';

/// 唤起安装器的结果（原生侧返回的字符串）。
abstract final class UpdateInstallCode {
  /// 已成功唤起系统安装界面。
  static const String ok = 'ok';

  /// 系统不允许安装未知来源应用，需要先去设置页授权。
  static const String permission = 'permission';

  /// 平台未实现该通道（非 Android / 鸿蒙侧未接）。
  static const String unavailable = 'unavailable';
}

/// 下载结果：成功给本地文件路径，失败给可读的原因。
class UpdateDownloadResult {
  const UpdateDownloadResult._(this.path, this.error);

  final String? path;

  final String? error;

  bool get ok => path != null;

  static UpdateDownloadResult success(String path) =>
      UpdateDownloadResult._(path, null);

  static UpdateDownloadResult fail(String error) =>
      UpdateDownloadResult._(null, error);
}

/// 更新相关的"落地"能力：平台通道 + 下载 + 完整性校验。
///
/// 设计要点：
/// - 通道调用全部走 `_call`，原生侧没实现时（鸿蒙、桌面）返回 null，
///   由调用方降级为"复制链接"，**不抛异常**。
/// - 下载用 Dio（已有依赖），落 `getTemporaryDirectory()`，无需任何存储权限。
/// - 若 Release 里带 `.sha1` 侧车，下载完先比对 SHA-1，不一致就拒绝安装。
class UpdateInstaller {
  UpdateInstaller._();

  static const MethodChannel _ch = MethodChannel(kUpdateChannel);

  static String? _abiCache;

  static bool _nativeMissing = false;

  /// 平台侧有没有实现更新通道。
  static bool get nativeMissing => _nativeMissing;

  /// 测试专用：直接指定 ABI，跳过通道调用（通道在测试里没人应答）。
  @visibleForTesting
  static String? testAbiOverride;

  /// 本机主 ABI（如 `arm64-v8a`）；拿不到就是 null。
  static Future<String?> deviceAbi() async {
    if (testAbiOverride != null) return testAbiOverride;
    if (_abiCache != null) return _abiCache;
    final String? v = await _call<String>('getAbi');
    if (v != null && v.isNotEmpty) {
      _abiCache = v;
      _log('更新检查：本机 ABI=$v', level: 'INFO');
    }
    return _abiCache;
  }

  /// 用系统浏览器 / 外部应用打开一个 https 地址。
  static Future<bool> openUrl(String url) async {
    if (url.isEmpty) return false;
    final bool? ok = await _call<bool>(
        'openUrl', <String, Object?>{'url': url});
    return ok ?? false;
  }

  /// 唤起系统安装器安装 [path] 指向的 APK。
  ///
  /// 返回 [UpdateInstallCode]。
  static Future<String> installApk(String path) async {
    if (_nativeMissing) return UpdateInstallCode.unavailable;
    final String? r = await _call<String>(
        'installApk', <String, Object?>{'path': path});
    return r ?? UpdateInstallCode.unavailable;
  }

  static Future<T?> _call<T>(String method,
      [Map<String, Object?>? args]) async {
    if (_nativeMissing) return null;

    // ★ flutter test 里**没有任何一方应答这个通道** —— 实测（2026-09-24 第 66 轮）：
    //   invokeMethod 返回的 Future **永远不完成**，把整个测试套件挂死 40 分钟
    //   （进程 CPU 累计只有 0.69 秒，纯等）。
    //   ⚠️ 不能用 `.timeout()` 兜：它内部会 new 一个 Timer，而 Flutter 测试框架
    //   在用例结束时会断言「不允许还有 Timer 挂起」(`!timersPending`)，
    //   结果就是从"挂死"变成"9 个页面测试失败"。
    //   ⇒ 测试环境直接短路，一个请求都不发（与 i18n.dart 判断测试环境同一手法）。
    if (Platform.environment['FLUTTER_TEST'] == 'true') return null;

    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException catch (_) {
      _nativeMissing = true;
      _log('更新通道未实现（$method），功能降级为复制链接');
      return null;
    } on PlatformException catch (e) {
      _log('更新通道 $method 失败：${e.message}');
      return null;
    } catch (e) {
      _log('更新通道 $method 异常：${Formatter.safeErr(e)}');
      return null;
    }
  }

  /// 记日志但**绝不让它影响调用方**：测试环境 / 未初始化时 AppLog 本身
  /// 也可能抛异常，那会让"通道不可用"这种可降级的错误变成崩溃。
  static void _log(String msg, {String level = 'WARN'}) {
    try {
      AppLog.instance.net(msg, level: level);
    } catch (_) {
      // 忽略：日志写不进去也要能继续走降级路径。
    }
  }

  /// 下载安装包到本地缓存目录，并在有 `.sha1` 侧车时校验。
  static Future<UpdateDownloadResult> download(
    UpdateAsset apk, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancel,
  }) async {
    final Dio dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      // ⚠️ receiveTimeout 是"两次数据包的间隔上限"，不是整个下载的时限，
      //    所以大文件也能下完；设 60s 只是为了避免卡死的连接无限等下去。
      receiveTimeout: const Duration(seconds: 60),
      headers: const <String, dynamic>{
        'User-Agent': 'TorrentManager-UpdateCheck',
      },
      followRedirects: true,
      validateStatus: (int? s) => s != null && s >= 200 && s < 300,
    ));

    try {
      final Directory dir = await getTemporaryDirectory();
      if (!await dir.exists()) await dir.create(recursive: true);

      final File f = File('${dir.path}/${Formatter.safeFileName(apk.name)}');
      if (await f.exists()) await f.delete();

      final Response<dynamic> r = await dio.get<dynamic>(
        apk.url,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (int c, int t) => onProgress?.call(c, t),
        cancelToken: cancel,
      );

      final Object? data = r.data;
      if (data is! List<int> || data.isEmpty) {
        return UpdateDownloadResult.fail('下载内容为空');
      }

      final String? expect = await _fetchSha1(apk.sha1Url, dio);
      if (expect != null) {
        final String actual = sha1Hex(data);
        if (actual != expect) {
          _log('更新包 SHA-1 校验失败：$actual ≠ $expect', level: 'ERROR');
          return UpdateDownloadResult.fail('安装包校验不一致，已放弃安装');
        }
        _log('更新包 SHA-1 校验通过', level: 'INFO');
      }

      await f.writeAsBytes(data, flush: true);
      _log('更新包已下载：${apk.name}（${data.length} 字节）', level: 'INFO');
      return UpdateDownloadResult.success(f.path);
    } catch (e) {
      return UpdateDownloadResult.fail(Formatter.safeErr(e));
    } finally {
      dio.close(force: true);
    }
  }

  static Future<String?> _fetchSha1(String? url, Dio dio) async {
    if (url == null || url.isEmpty) return null;
    try {
      final Response<dynamic> r = await dio.get<dynamic>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final String s = (r.data?.toString() ?? '').trim();
      final RegExpMatch? m = RegExp(r'[0-9a-fA-F]{40}').firstMatch(s);
      return m?.group(0)?.toLowerCase();
    } catch (_) {
      return null;
    }
  }

  /// 算一段字节的 SHA-1（十六进制小写，40 位）。
  static String sha1Hex(List<int> bytes) {
    final Uint8List out = SHA1Digest().process(Uint8List.fromList(bytes));
    final StringBuffer sb = StringBuffer();
    for (final int b in out) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
