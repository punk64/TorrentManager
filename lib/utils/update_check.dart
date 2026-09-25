import 'dart:convert';

import 'package:dio/dio.dart';

import '../app/app_version.dart';
import 'formatter.dart';

class UpdateAsset {
  const UpdateAsset({
    required this.name,
    required this.url,
    this.size = 0,
    this.sha1Url,
  });

  final String name;

  final String url;

  final int size;

  final String? sha1Url;
}

class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    this.url,
    this.notes,
    this.assets = const <UpdateAsset>[],
  });

  final String version;

  final String? url;

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

  final String? releaseUrl;

  final UpdateAsset? apk;

  final String? notes;

  bool get hasUpdate => status == UpdateCheckStatus.hasUpdate;

  bool get hasInstaller => apk != null;

  static const UpdateCheckResult disabled =
      UpdateCheckResult._(UpdateCheckStatus.disabled, reason: '未配置检查地址');

  static UpdateCheckResult failed(String reason) =>
      UpdateCheckResult._(UpdateCheckStatus.failed, reason: reason);

  static UpdateCheckResult upToDate(String latest,
          {String? releaseUrl, String? notes}) =>
      UpdateCheckResult._(UpdateCheckStatus.noUpdate,
          latest: latest, releaseUrl: releaseUrl, notes: notes);

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
