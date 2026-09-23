import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'formatter.dart';


















class IpGeo {
  IpGeo._();

  static final IpGeo instance = IpGeo._();

  
  static const int maxActive = 3;

  
  static const Duration timeout = Duration(seconds: 6);

  
  static const int maxCache = 500;

  
  
  
  
  
  
  static bool offline = false;

  
  
  
  
  
  
  
  
  final Map<String, String?> _cache = <String, String?>{};

  
  final Map<String, Future<String?>> _running = <String, Future<String?>>{};

  final List<Completer<void>> _waiters = <Completer<void>>[];
  int _active = 0;

  Dio? _dio;

  
  
  Dio get _client {
    return _dio ??= Dio(BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
    ));
  }

  
  bool has(String ip) => _cache.containsKey(ip);

  
  String? cached(String ip) =>
      _cache.containsKey(ip) ? _touch(ip) : null;

  
  String? _touch(String ip) {
    final String? v = _cache.remove(ip);
    _cache[ip] = v;
    return v;
  }

  
  
  
  Future<String?> lookup(String ip) async {
    final String key = ip.trim();
    if (key.isEmpty) return null;
    if (_cache.containsKey(key)) return _touch(key);
    final Future<String?>? r = _running[key];
    if (r != null) return r;
    
    if (offline) {
      final Future<String?> f = Completer<String?>().future;
      _running[key] = f;
      return f;
    }
    final Future<String?> f = _run(key);
    _running[key] = f;
    return f;
  }

  Future<String?> _run(String ip) async {
    await _slot();
    try {
      String? text = await _fetchIpApi(ip);
      text ??= await _fetchIpWhois(ip);
      _put(ip, text);
      return text;
    } catch (_) {
      _put(ip, null);
      return null;
    } finally {
      _release();
      _running.remove(ip);
    }
  }

  void _put(String ip, String? text) {
    
    
    if (!_cache.containsKey(ip) && _cache.length >= maxCache) {
      _cache.remove(_cache.keys.first);
    }
    _cache.remove(ip);
    _cache[ip] = (text == null || text.isEmpty) ? null : text;
  }

  
  Future<void> _slot() async {
    if (_active < maxActive) {
      _active++;
      return;
    }
    final Completer<void> c = Completer<void>();
    _waiters.add(c);
    await c.future;
    
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else if (_active > 0) {
      _active--;
    }
  }

  

  
  Future<String?> _fetchIpApi(String ip) async {
    try {
      final Response<dynamic> resp = await _client.get<dynamic>(
        'http://ip-api.com/json/${Uri.encodeComponent(ip)}',
        queryParameters: <String, dynamic>{
          'fields': 'status,country,regionName,city,isp',
          'lang': 'zh-CN',
        },
      );
      final Map<String, dynamic> m = _asMap(resp.data);
      if (m['status'] != 'success') return null;
      return _join(<dynamic>[
        m['country'],
        m['regionName'],
        m['city'],
        m['isp'],
      ]);
    } catch (_) {
      return null;
    }
  }

  
  Future<String?> _fetchIpWhois(String ip) async {
    try {
      final Response<dynamic> resp = await _client
          .get<dynamic>('https://ipwho.is/${Uri.encodeComponent(ip)}');
      final Map<String, dynamic> m = _asMap(resp.data);
      if (m['success'] != true) return null;
      final dynamic conn = m['connection'];
      final String isp =
          conn is Map ? Formatter.getString(conn, 'isp') : '';
      return _join(<dynamic>[
        m['country'],
        m['region'],
        m['city'],
        isp,
      ]);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.isNotEmpty) {
      try {
        final dynamic d = jsonDecode(data);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }

  
  
  String? _join(List<dynamic> parts) {
    final List<String> out = <String>[];
    for (final dynamic v in parts) {
      final String s = v?.toString().trim() ?? '';
      if (s.isEmpty) continue;
      if (out.isNotEmpty && out.last == s) continue;
      out.add(s);
    }
    return out.isEmpty ? null : out.join(' · ');
  }
}
