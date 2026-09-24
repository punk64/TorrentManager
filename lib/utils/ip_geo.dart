import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'i18n.dart';
import 'ip_geo_sources.dart';

class IpGeo {
  IpGeo._();

  static final IpGeo instance = IpGeo._();

  static const int maxActive = 3;

  static const Duration timeout = Duration(seconds: 6);

  static const int maxCache = 500;

  static bool offline = false;

  static const Duration minSourceInterval = Duration(milliseconds: 250);

  static const int failStreakLimit = 3;

  static const Duration cooldownFail = Duration(minutes: 10);

  static const Duration cooldownRateLimit = Duration(minutes: 30);

  static const int maxAttemptsPerTier = 4;

  static const int maxBodyChars = 32 * 1024;

  static const int _maxResultChars = 96;

  static const int _maxFieldChars = 32;

  final Map<String, String?> _cache = <String, String?>{};

  final Map<String, Future<String?>> _running = <String, Future<String?>>{};

  final List<Completer<void>> _waiters = <Completer<void>>[];
  int _active = 0;

  Dio? _dio;

  final math.Random _rand = math.Random();
  final Map<String, List<String>> _bags = <String, List<String>>{};
  final Map<String, DateTime> _lastUsed = <String, DateTime>{};
  final Map<String, int> _failStreak = <String, int>{};
  final Map<String, DateTime> _cooldownUntil = <String, DateTime>{};

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
      final bool v6 = ip.contains(':');
      final List<IpGeoSource> primary = L.isEnglish ? kEnGeoPool : kZhGeoPool;
      final List<IpGeoSource> backup = L.isEnglish ? kZhGeoPool : kEnGeoPool;
      final Set<String> tried = <String>{};

      String? r =
          await _attemptTier(ip, primary, L.isEnglish ? 'en' : 'zh', v6, tried);
      r ??= await _attemptTier(
          ip, backup, L.isEnglish ? 'zh-bk' : 'en-bk', v6, tried);

      _put(ip, r);
      return r;
    } finally {
      _release();
      _running.remove(ip);
    }
  }

  Future<String?> _attemptTier(String ip, List<IpGeoSource> pool, String sig,
      bool v6, Set<String> tried) async {
    for (int attempt = 0; attempt < maxAttemptsPerTier; attempt++) {
      final IpGeoSource? src = _pickFrom(pool, sig, v6: v6, exclude: tried);
      if (src == null) return null;
      tried.add(src.id);
      try {
        final String? text = await _fetchWith(src, ip);
        if (text != null) {
          _failStreak.remove(src.id);
          return text;
        }
        _noteFailure(src.id, rateLimited: false);
      } catch (_) {
        _noteFailure(src.id, rateLimited: false);
      }
    }
    return null;
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

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  IpGeoSource? _pickFrom(List<IpGeoSource> base, String sig,
      {required bool v6, Set<String> exclude = const <String>{}}) {
    List<IpGeoSource> pool = base;
    if (v6) {
      final List<IpGeoSource> v6Pool =
          base.where((IpGeoSource s) => s.ipv6).toList();
      if (v6Pool.isNotEmpty) pool = v6Pool;
    }
    final String key = '$sig|${v6 ? '6' : '4'}';
    final List<String> bag = _bags.putIfAbsent(
      key,
      () => pool.map<String>((IpGeoSource s) => s.id).toList()..shuffle(_rand),
    );

    final DateTime now = DateTime.now();
    final int n = bag.length;
    for (int i = 0; i < n; i++) {
      final String id = bag.removeAt(0);
      IpGeoSource? src;
      for (final IpGeoSource s in pool) {
        if (s.id == id) {
          src = s;
          break;
        }
      }
      if (src == null) continue;
      if (exclude.contains(id)) {
        bag.add(id);
        continue;
      }
      final DateTime? cd = _cooldownUntil[id];
      if (cd != null && now.isBefore(cd)) {
        bag.add(id);
        continue;
      }
      final DateTime? lu = _lastUsed[id];
      if (lu != null && now.difference(lu) < minSourceInterval) {
        bag.add(id);
        continue;
      }
      _lastUsed[id] = now;
      return src;
    }

    IpGeoSource? oldest;
    DateTime? oldestAt;
    for (final IpGeoSource s in pool) {
      if (exclude.contains(s.id)) continue;
      final DateTime? cd = _cooldownUntil[s.id];
      if (cd != null && now.isBefore(cd)) continue;
      final DateTime? lu = _lastUsed[s.id];
      if (oldest == null || (lu ?? _epoch).isBefore(oldestAt ?? _epoch)) {
        oldest = s;
        oldestAt = lu;
      }
    }
    if (oldest != null) {
      _lastUsed[oldest.id] = now;
      return oldest;
    }
    return null;
  }

  void _noteFailure(String id, {required bool rateLimited}) {
    if (rateLimited) {
      _cooldownUntil[id] = DateTime.now().add(cooldownRateLimit);
      _failStreak.remove(id);
      return;
    }
    final int streak = (_failStreak[id] ?? 0) + 1;
    if (streak >= failStreakLimit) {
      _cooldownUntil[id] = DateTime.now().add(cooldownFail);
      _failStreak.remove(id);
    } else {
      _failStreak[id] = streak;
    }
  }

  Future<String?> _fetchWith(IpGeoSource src, String ip) async {
    final Response<dynamic> resp = await _client.get<dynamic>(
      src.buildUrl(Uri.encodeComponent(ip)),
      options: Options(
        responseType: ResponseType.plain,

        validateStatus: (int? s) => s != null && s >= 200 && s < 600,
        headers: <String, String>{
          'User-Agent': 'Mozilla/5.0 (Linux; Android) TorrentManager',
        },
      ),
    );

    final int code = resp.statusCode ?? 0;
    if (code == 429 || code == 403) {
      _noteFailure(src.id, rateLimited: true);
      return null;
    }
    if (code != 200) return null;

    final dynamic data = resp.data;
    if (data is! String || data.isEmpty) return null;
    if (data.length > maxBodyChars) return null;

    final Map<String, dynamic> m = _asMap(data);
    if (m.isEmpty) return null;

    if (!_loopbackOk(m, ip)) return null;

    final List<String>? parts = src.parse(m);
    if (parts == null) return null;
    return _join(parts);
  }

  Dio get _client {
    return _dio ??= Dio(BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
    ));
  }

  bool _loopbackOk(Map<String, dynamic> m, String ip) {
    final String? reported = _findReportedIp(m, 0);
    if (reported == null) return true;
    return _ipEquals(reported, ip);
  }

  String? _findReportedIp(dynamic node, int depth) {
    if (depth > 2 || node == null) return null;
    if (node is Map) {
      for (final String k in const <String>[
        'ip',
        'query',
        'ipAddress',
        'ip_address',
        'origip',
      ]) {
        final dynamic v = node[k];
        if (v is String && v.trim().isNotEmpty) return v;
      }
      for (final dynamic v in node.values) {
        final String? r = _findReportedIp(v, depth + 1);
        if (r != null) return r;
      }
    }
    return null;
  }

  bool _ipEquals(String a, String b) {
    final String x = a.trim().toLowerCase();
    final String y = b.trim().toLowerCase();
    if (x == y) return true;
    try {
      final Object u = Uri.parseIPv6Address(x);
      final Object v = Uri.parseIPv6Address(y);
      return u.toString() == v.toString();
    } catch (_) {
      return false;
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

  static final RegExp _stripChars = RegExp(
      r'[\u0000-\u001F\u007F\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF\u00AD]');

  static final RegExp _allowedChars =
      RegExp(r"[^\p{L}\p{N} .,'()\-&/]", unicode: true);

  static String _clean(String raw) {
    String s =
        raw.replaceAll(_stripChars, '').replaceAll(_allowedChars, '').trim();
    if (s.length > _maxFieldChars) s = s.substring(0, _maxFieldChars);
    return s;
  }

  String? _join(List<String> parts) {
    final List<String> out = <String>[];
    for (final String raw in parts) {
      final String s = _clean(raw);
      if (s.isEmpty) continue;
      if (out.contains(s)) continue;
      out.add(s);
    }
    if (out.isEmpty) return null;
    String r = out.join(' · ');
    if (r.length > _maxResultChars) r = r.substring(0, _maxResultChars);
    return r;
  }

  @visibleForTesting
  void injectDioForTest(Dio dio) {
    _dio = dio;
  }

  @visibleForTesting
  void resetStateForTest() {
    _cache.clear();
    _running.clear();
    _waiters.clear();
    _active = 0;
    _bags.clear();
    _lastUsed.clear();
    _failStreak.clear();
    _cooldownUntil.clear();
  }

  @visibleForTesting
  Map<String, DateTime> get cooldownUntilForTest =>
      Map<String, DateTime>.from(_cooldownUntil);

  @visibleForTesting
  Map<String, int> get failStreakForTest => Map<String, int>.from(_failStreak);
}
