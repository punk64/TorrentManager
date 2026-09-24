import 'dart:convert';

import 'package:dio/dio.dart';

import '../app/app_version.dart';
import 'formatter.dart';

/// Release 里一个可下载的安装包资产，外加它的 `.sha1` 侧车地址。
class UpdateAsset {
  const UpdateAsset({
    required this.name,
    required this.url,
    this.size = 0,
    this.sha1Url,
  });

  /// 资产文件名，例如 `TorrentManager-V0.2.12-arm64-v8a.apk`。
  final String name;

  /// `browser_download_url` 直链（GitHub 会 302 到 CDN）。
  final String url;

  /// 字节数；接口没给就是 0（界面上不显示大小）。
  final int size;

  /// 同名 `.sha1` 侧车的直链；Release 里没有就是 null ⇒ 跳过完整性校验。
  final String? sha1Url;
}

/// 从一次响应里解析出的 Release 摘要（不含"有没有更新"的判断）。
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    this.url,
    this.notes,
    this.assets = const <UpdateAsset>[],
  });

  final String version;

  /// Release 页面地址（`html_url`），给用户点开看详情用。
  final String? url;

  /// Release 说明正文（`body`）。
  final String? notes;

  final List<UpdateAsset> assets;
}

class UpdateChecker {
  UpdateChecker({
    UpdateFetcher? fetcher,
    this.timeout = const Duration(seconds: 8),
    this.deviceAbi,
  }) {
    _fetch = fetcher ?? _httpGet;
  }

  late final UpdateFetcher _fetch;

  final Duration timeout;

  /// 本机主 ABI（如 `arm64-v8a`）。
  ///
  /// ⚠️ 非空时**只认名字里带它的安装包**：ABI 对不上装了也跑不起来，
  /// 所以这种情况按"没有可用更新"处理，不提示。null 表示不做 ABI 匹配
  /// （非 Android 平台或拿不到 ABI 时），退化为取第一个安装包。
  final String? deviceAbi;

  Future<UpdateCheckResult> check({
    String url = kUpdateCheckUrl,
    String local = kAppVersion,
  }) async {
    final String u = url.trim();

    if (u.isEmpty) {
      return UpdateCheckResult.disabled;
    }

    if (!u.toLowerCase().startsWith('https://')) {
      return UpdateCheckResult.failed(
          '更新检查地址不是 https（已按"查不到"处理，不发请求）');
    }

    String body;
    try {
      body = await _fetch(u);
    } catch (e) {
      return UpdateCheckResult.failed('请求失败：$e');
    }

    final ReleaseInfo? info = parseRelease(body);
    if (info == null) {
      return UpdateCheckResult.failed('响应里解析不出版本号');
    }

    if (Formatter.compareVersions(info.version, local) <= 0) {
      return UpdateCheckResult.upToDate(info.version,
          releaseUrl: info.url, notes: info.notes);
    }

    // ★ 严格口径：版本号更大还不够 —— 必须有能装在本机上的安装包才算"有更新"。
    //   只有源码 zip / 空 assets / ABI 对不上，都不提示（避免"有新版却装不了"）。
    final UpdateAsset? apk = pickInstaller(info.assets, deviceAbi);
    if (apk == null) {
      return UpdateCheckResult.noInstaller(info.version,
          releaseUrl: info.url, notes: info.notes);
    }

    return UpdateCheckResult.newer(
      latest: info.version,
      apk: apk,
      releaseUrl: info.url,
      notes: info.notes,
    );
  }

  /// 从响应体里解析出一份 Release 摘要；解析不出版本号返回 null。
  static ReleaseInfo? parseRelease(Object? body) {
    if (body == null) return null;
    final String s = body.toString().trim();
    if (s.isEmpty) return null;

    String raw = s;
    String? url;
    String? notes;
    List<UpdateAsset> assets = const <UpdateAsset>[];

    if (s.startsWith('{')) {
      Object? decoded;
      try {
        decoded = jsonDecode(s);
      } catch (_) {
        decoded = null;
      }
      if (decoded is Map) {
        raw = _firstString(decoded, _kVersionKeys) ?? '';
        url = _firstString(decoded, _kUrlKeys);
        notes = _firstString(decoded, _kNotesKeys);
        assets = parseAssets(decoded['assets']);
      } else {
        // 畸形 JSON：交给下面的正则兜底抠版本号（保持旧行为）。
        raw = s;
      }
    }

    final String? version = parseLatestVersion(raw);
    if (version == null) return null;

    return ReleaseInfo(
      version: version,
      url: url,
      notes: notes,
      assets: assets,
    );
  }

  /// 解析 `assets` 数组：只保留 `.apk`，并把同名 `.sha1` 侧车挂到它身上。
  static List<UpdateAsset> parseAssets(Object? raw) {
    if (raw is! List || raw.isEmpty) return const <UpdateAsset>[];

    final List<_RawAsset> apks = <_RawAsset>[];
    final Map<String, String> sha1 = <String, String>{};

    for (final Object? e in raw) {
      if (e is! Map) continue;
      final Object? n = e['name'];
      final Object? u = e['browser_download_url'];
      if (n is! String || u is! String) continue;
      if (n.isEmpty || u.isEmpty) continue;

      final String lower = n.toLowerCase();
      if (lower.endsWith('.sha1')) {
        sha1[n.substring(0, n.length - '.sha1'.length)] = u;
        continue;
      }
      if (!lower.endsWith('.apk')) continue;

      final Object? size = e['size'];
      apks.add(_RawAsset(
        name: n,
        url: u,
        size: size is num ? size.toInt() : 0,
      ));
    }

    if (apks.isEmpty) return const <UpdateAsset>[];

    return apks
        .map((_RawAsset a) => UpdateAsset(
              name: a.name,
              url: a.url,
              size: a.size,
              sha1Url: sha1[a.name],
            ))
        .toList(growable: false);
  }

  /// 挑出本机装得上的那个安装包；挑不出就 null。
  static UpdateAsset? pickInstaller(List<UpdateAsset> assets, String? abi) {
    if (assets.isEmpty) return null;
    if (abi == null || abi.isEmpty) return assets.first;

    final String want = abi.toLowerCase();
    for (final UpdateAsset a in assets) {
      if (a.name.toLowerCase().contains(want)) return a;
    }
    return null;
  }

  static String? _firstString(Map<dynamic, dynamic> m, List<String> keys) {
    for (final String k in keys) {
      final Object? v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static String? parseLatestVersion(Object? body) {
    if (body == null) return null;
    String s = body.toString().trim();
    if (s.isEmpty) return null;

    if (s.startsWith('{')) {
      try {
        final Object? decoded = jsonDecode(s);
        if (decoded is Map) {
          for (final String key in _kVersionKeys) {
            final Object? v = decoded[key];
            if (v is String && v.trim().isNotEmpty) {
              s = v.trim();
              break;
            }
          }
        }
      } catch (_) {
      }
    }

    final RegExpMatch? m = RegExp(r'[vV]?(\d+(?:\.\d+)+)').firstMatch(s);
    return m?.group(1);
  }

  static const List<String> _kVersionKeys = <String>[
    'version',
    'latest',
    'latestVersion',
    'latest_version',
    'tag_name',
    'name',
  ];

  static const List<String> _kUrlKeys = <String>['html_url', 'url'];

  static const List<String> _kNotesKeys = <String>['body', 'notes'];

  Future<String> _httpGet(String url) async {
    final Dio dio = Dio(BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,

      headers: const <String, dynamic>{
        'User-Agent': 'TorrentManager-UpdateCheck',
      },

      responseType: ResponseType.plain,
      validateStatus: (int? s) => s != null && s >= 200 && s < 300,
    ));
    try {
      final Response<dynamic> r = await dio.get<dynamic>(url);
      final Object? data = r.data;
      return data == null ? '' : data.toString();
    } finally {
      dio.close(force: true);
    }
  }
}

class _RawAsset {
  const _RawAsset({required this.name, required this.url, required this.size});

  final String name;
  final String url;
  final int size;
}

typedef UpdateFetcher = Future<String> Function(String url);

class UpdateCheckResult {
  const UpdateCheckResult._(this.status,
      {this.latest, this.reason, this.releaseUrl, this.apk, this.notes});

  final UpdateCheckStatus status;

  final String? latest;

  final String? reason;

  /// Release 页面地址，供"用浏览器打开"。
  final String? releaseUrl;

  /// 选定要下载的安装包；只有 `hasUpdate` 时才非空。
  final UpdateAsset? apk;

  /// Release 说明正文。
  final String? notes;

  bool get hasUpdate => status == UpdateCheckStatus.hasUpdate;

  /// 有没有拿到可下载的安装包。
  bool get hasInstaller => apk != null;

  static const UpdateCheckResult disabled =
      UpdateCheckResult._(UpdateCheckStatus.disabled, reason: '未配置检查地址');

  static UpdateCheckResult failed(String reason) =>
      UpdateCheckResult._(UpdateCheckStatus.failed, reason: reason);

  static UpdateCheckResult upToDate(String latest,
          {String? releaseUrl, String? notes}) =>
      UpdateCheckResult._(UpdateCheckStatus.noUpdate,
          latest: latest, releaseUrl: releaseUrl, notes: notes);

  /// 版本确实更新，但 Release 里没有本机装得上的安装包 ⇒ 不提示"有更新"。
  static UpdateCheckResult noInstaller(String latest,
          {String? releaseUrl, String? notes}) =>
      UpdateCheckResult._(UpdateCheckStatus.noUpdate,
          latest: latest,
          reason: '最新 Release 未附带适配本机的安装包',
          releaseUrl: releaseUrl,
          notes: notes);

  static UpdateCheckResult newer({
    required String latest,
    required UpdateAsset apk,
    String? releaseUrl,
    String? notes,
  }) =>
      UpdateCheckResult._(UpdateCheckStatus.hasUpdate,
          latest: latest, apk: apk, releaseUrl: releaseUrl, notes: notes);
}

enum UpdateCheckStatus {
  disabled,

  failed,

  noUpdate,

  hasUpdate,
}
