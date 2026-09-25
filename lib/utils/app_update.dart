import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/digests/sha1.dart';

import 'app_log.dart';
import 'formatter.dart';
import 'update_check.dart';

const String kUpdateChannel = 'tm_updater';

abstract final class UpdateInstallCode {

  static const String ok = 'ok';

  static const String permission = 'permission';

  static const String unavailable = 'unavailable';
}

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

class UpdateInstaller {
  UpdateInstaller._();

  static const MethodChannel _ch = MethodChannel(kUpdateChannel);

  static String? _abiCache;

  static bool _nativeMissing = false;

  static bool get nativeMissing => _nativeMissing;

  @visibleForTesting
  static String? testAbiOverride;

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

  static Future<bool> openUrl(String url) async {
    if (url.isEmpty) return false;
    final bool? ok = await _call<bool>(
        'openUrl', <String, Object?>{'url': url});
    return ok ?? false;
  }

  static Future<String> installApk(String path) async {
    if (_nativeMissing) return UpdateInstallCode.unavailable;
    final String? r = await _call<String>(
        'installApk', <String, Object?>{'path': path});
    return r ?? UpdateInstallCode.unavailable;
  }

  static Future<T?> _call<T>(String method,
      [Map<String, Object?>? args]) async {
    if (_nativeMissing) return null;

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

  static void _log(String msg, {String level = 'WARN'}) {
    try {
      AppLog.instance.net(msg, level: level);
    } catch (_) {

    }
  }

  static Future<UpdateDownloadResult> download(
    UpdateAsset apk, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancel,
  }) async {
    final Dio dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),

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

  static String sha1Hex(List<int> bytes) {
    final Uint8List out = SHA1Digest().process(Uint8List.fromList(bytes));
    final StringBuffer sb = StringBuffer();
    for (final int b in out) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
