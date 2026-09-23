import 'dart:convert';

import 'package:dio/dio.dart';

import '../app/app_version.dart';
import 'formatter.dart';























class UpdateChecker {
  UpdateChecker({UpdateFetcher? fetcher, this.timeout = const Duration(seconds: 8)}) {
    
    _fetch = fetcher ?? _httpGet;
  }

  
  late final UpdateFetcher _fetch;

  
  
  
  
  
  final Duration timeout;

  
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

    
    final String? latest = parseLatestVersion(body);
    if (latest == null) {
      return UpdateCheckResult.failed('响应里解析不出版本号');
    }

    
    
    if (Formatter.compareVersions(latest, local) <= 0) {
      return UpdateCheckResult.upToDate(latest);
    }
    return UpdateCheckResult.newer(latest);
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


typedef UpdateFetcher = Future<String> Function(String url);


class UpdateCheckResult {
  const UpdateCheckResult._(this.status, {this.latest, this.reason});

  final UpdateCheckStatus status;

  
  final String? latest;

  
  final String? reason;

  
  bool get hasUpdate => status == UpdateCheckStatus.hasUpdate;

  static const UpdateCheckResult disabled =
      UpdateCheckResult._(UpdateCheckStatus.disabled, reason: '未配置检查地址');

  static UpdateCheckResult failed(String reason) =>
      UpdateCheckResult._(UpdateCheckStatus.failed, reason: reason);

  
  
  static UpdateCheckResult upToDate(String latest) =>
      UpdateCheckResult._(UpdateCheckStatus.noUpdate, latest: latest);

  static UpdateCheckResult newer(String latest) =>
      UpdateCheckResult._(UpdateCheckStatus.hasUpdate, latest: latest);
}




enum UpdateCheckStatus {
  
  disabled,

  
  failed,

  
  noUpdate,

  
  hasUpdate,
}
