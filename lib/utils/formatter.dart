import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/local/secure_prefs.dart';
import '../data/models/server_data.dart';
import '../data/models/torrent.dart';
import '../widgets/app_toast.dart';
import '../widgets/bottom_panel.dart';
import 'net_error.dart';
import 'strings.dart';
import 'app_log.dart';
import 'i18n.dart';

class Formatter {
  Formatter._();

  static String getString(Map? json, String key, {String def = ''}) {
    if (json == null) return def;
    final dynamic v = json[key];
    if (v == null) return def;
    if (v is String) return v;
    return v.toString();
  }

  static String? getStringOrNull(Map? json, String key) {
    if (json == null) return null;
    final dynamic v = json[key];
    if (v == null) return null;
    final String s = v is String ? v : v.toString();
    return s.isEmpty ? null : s;
  }

  static int getInt(Map? json, String key, {int def = 0}) {
    if (json == null) return def;
    final dynamic v = json[key];
    if (v == null) return def;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    if (v is String) {
      final double? d = double.tryParse(v.trim());
      return d == null ? def : d.toInt();
    }
    if (v is bool) return v ? 1 : 0;
    return def;
  }

  static double getDouble(Map? json, String key, {double def = 0}) {
    if (json == null) return def;
    final dynamic v = json[key];
    if (v == null) return def;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) {
      final double? d = double.tryParse(v.trim());
      return d ?? def;
    }
    return def;
  }

  static bool getBool(Map? json, String key, {bool def = false}) {
    if (json == null) return def;
    final dynamic v = json[key];
    if (v == null) return def;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final String s = v.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no' || s.isEmpty) return false;
    }
    return def;
  }

  static List<dynamic> getList(Map? json, String key) {
    if (json == null) return <dynamic>[];
    final dynamic v = json[key];
    return v is List ? v : <dynamic>[];
  }

  static Map<String, dynamic> getMap(Map? json, String key) {
    if (json == null) return <String, dynamic>{};
    final dynamic v = json[key];
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  static const int fmtCacheSize = 2048;

  static final _FmtCache<String> _cacheSize =
      _FmtCache<String>(fmtCacheSize);
  static final _FmtCache<String> _cacheSizeCompact =
      _FmtCache<String>(fmtCacheSize);
  static final _FmtCache<String> _cacheSpeed =
      _FmtCache<String>(fmtCacheSize);
  static final _FmtCache<String> _cacheRatio =
      _FmtCache<String>(fmtCacheSize);
  static final _FmtCache<String> _cacheProgress =
      _FmtCache<String>(fmtCacheSize);
  static final _FmtCache<IconData> _cacheIcon =
      _FmtCache<IconData>(fmtCacheSize);
  static final _FmtCache<int> _cacheColorKind =
      _FmtCache<int>(fmtCacheSize);

  @visibleForTesting
  static void clearFormatCache() {
    _cacheSize.clear();
    _cacheSizeCompact.clear();
    _cacheSpeed.clear();
    _cacheRatio.clear();
    _cacheProgress.clear();
    _cacheIcon.clear();
    _cacheColorKind.clear();
  }

  static String setSize(num bytes) {
    final String? hit = _cacheSize.get(bytes);
    if (hit != null) return hit;
    final String out = _calcSize(bytes);
    _cacheSize.put(bytes, out);
    return out;
  }

  static String _calcSize(num bytes) {
    final double b = bytes.toDouble();
    if (b < 0) return '0 B';
    if (b < 1024) return '${b.toStringAsFixed(0)} B';
    const List<String> units = <String>['KB', 'MB', 'GB', 'TB', 'PB'];
    double v = b / 1024;
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    final String s = v >= 100 ? v.toStringAsFixed(1) : v.toStringAsFixed(2);
    return '$s ${units[i]}';
  }

  static String bytes(int bytes) => setSize(bytes);

  static String setSizeCompact(num bytes) {
    final String? hit = _cacheSizeCompact.get(bytes);
    if (hit != null) return hit;
    final String out = _calcSizeCompact(bytes);
    _cacheSizeCompact.put(bytes, out);
    return out;
  }

  static String _calcSizeCompact(num bytes) {
    final double b = bytes.toDouble();
    if (b < 0) return '0B';
    if (b < 1024) return '${b.toStringAsFixed(0)}B';
    const List<String> units = <String>['K', 'M', 'G', 'T', 'P'];
    double v = b / 1024;
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(1)}${units[i]}';
  }

  static String setSpeed(num bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    final String? hit = _cacheSpeed.get(bytesPerSec);
    if (hit != null) return hit;
    final String out = '${setSize(bytesPerSec)}/s';
    _cacheSpeed.put(bytesPerSec, out);
    return out;
  }

  static String speed(int bytesPerSec) => setSpeed(bytesPerSec);

  static String setTime(int seconds) {
    if (seconds <= 0) return '-';

    final int d = seconds ~/ 86400;
    final int h = (seconds % 86400) ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;
    if (d > 0) return '$d${S.unitDay}$h${S.unitHour}';
    if (h > 0) return '$h${S.unitHour}$m${S.unitMinute}';
    if (m > 0) return '$m${S.unitMinute}$s${S.unitSecond}';
    return '$s${S.unitSecond}';
  }

  static String setDuration(int seconds) => setTime(seconds);

  static String setEta(int seconds) {
    if (seconds <= 0 || seconds >= 8640000) return '-';
    return setTime(seconds);
  }

  static String setDate(int? epochSeconds) {
    if (epochSeconds == null || epochSeconds <= 0) return '-';
    return DateFormat('yyyy-MM-dd HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000));
  }

  static String setShortDate(int? epochSeconds) {
    if (epochSeconds == null || epochSeconds <= 0) return '-';
    return DateFormat('MM-dd HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000));
  }

  static String setLastActivity(int? epochSeconds) {
    if (epochSeconds == null || epochSeconds <= 0) return S.activeNever;
    final Duration diff =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(
      epochSeconds * 1000,
    ));
    if (diff.inMinutes < 1) return S.activeJustNow;
    if (diff.inMinutes < 60) return '${diff.inMinutes}${S.unitMinute}${S.activeAgo}';
    if (diff.inHours < 24) return '${diff.inHours}${S.unitHour}${S.activeAgo}';
    return '${diff.inDays}${S.unitDay}${S.activeAgo}';
  }

  static String setRatio(num ratio) {
    final String? hit = _cacheRatio.get(ratio);
    if (hit != null) return hit;
    final String out = ratio <= 0 ? '0' : ratio.toStringAsFixed(2);
    _cacheRatio.put(ratio, out);
    return out;
  }

  static String setProgress(double progress) {
    final String? hit = _cacheProgress.get(progress);
    if (hit != null) return hit;
    final String out = '${(progress.clamp(0, 1) * 100).toStringAsFixed(1)}%';
    _cacheProgress.put(progress, out);
    return out;
  }

  static String setStatus(String state) {
    final String s = state.toLowerCase();
    if (s.isEmpty) return S.stUnknownState;

    if (s.contains('error')) return S.error;
    if (s.contains('missingfiles')) return S.stMissingFiles;
    if (s.contains('moving')) return S.stMoving;
    if (s.contains('allocating')) return S.stAllocating;
    if (s.contains('checkingresumedata')) return S.stCheckingResume;
    if (s.contains('checking')) return S.stVerifyColon.replaceAll(': ', '');

    if (s.contains('metadl')) return S.stMetaDl;

    if (s.contains('pausedup') ||
        s.contains('pausedseed') ||
        s.contains('stoppedup')) {
      return S.stPausedUp;
    }
    if (s.contains('pauseddl') ||
        s.contains('paused') ||
        s.contains('stoppeddl')) {
      return S.stPausedDl;
    }

    // ★ forcedDL/forcedUP/stalledDL/stalledUP 必须插在通用 dl/up 判断**之前**：
    // 它们本身就含 'dl' / 'up'，放后面会被通用分支吃掉、退化成「下载中/做种中」，
    // 于是出现「筛选里选了强制下载、卡片却显示下载中」的自相矛盾。
    if (s.contains('forceddl')) return S.stForcedDl;
    if (s.contains('forcedup')) return S.stForcedUp;
    if (s.contains('stalleddl')) return S.stStalledDl;
    if (s.contains('stalledup')) return S.stStalledUp;

    if (s.contains('queued')) return S.stQueued;

    if (s == 'stopped') return S.stPaused;

    if (s.contains('up') || s.contains('seed') || s.contains('upload')) {
      return S.stSeeding;
    }
    if (s.contains('dl') || s.contains('download')) return S.fieldDlLoading;

    return S.stUnknownState;
  }

  static Color setStatusColor(String state, ColorScheme cs) {
    switch (_statusColorKind(state)) {
      case 0:
        return cs.error;
      case 1:
        return cs.outline;
      case 2:
        return cs.tertiary;
      case 3:
        return cs.primary;
      case 4:
        return cs.secondary;
      default:
        return cs.onSurfaceVariant;
    }
  }

  static int _statusColorKind(String state) {
    final int? hit = _cacheColorKind.get(state);
    if (hit != null) return hit;
    final String s = state.toLowerCase();
    final int out;
    if (s.contains('error') || s.contains('missingfiles')) {
      out = 0;
    } else if (s.contains('paused') || s.contains('stop')) {
      out = 1;
    } else if (s.contains('check') ||
        s.contains('moving') ||
        s.contains('allocating')) {
      out = 2;
    } else if (s.contains('up') ||
        s.contains('seed') ||
        s.contains('upload')) {
      out = 3;
    } else if (s.contains('dl') ||
        s.contains('download') ||
        s.contains('meta')) {
      out = 4;
    } else {
      out = 5;
    }
    _cacheColorKind.put(state, out);
    return out;
  }

  static IconData statusIcon(String state) {
    final IconData? hit = _cacheIcon.get(state);
    if (hit != null) return hit;
    final IconData out = _calcStatusIcon(state);
    _cacheIcon.put(state, out);
    return out;
  }

  static IconData _calcStatusIcon(String state) {
    final String s = state.toLowerCase();
    if (s.contains('error') || s.contains('missingfiles')) return Icons.error;

    if (s.contains('paused') || s.contains('stop')) return Icons.pause;
    if (s.contains('check')) return Icons.fact_check_outlined;
    if (s.contains('moving') || s.contains('allocating')) return Icons.sync;
    if (s.contains('queued')) return Icons.pending_outlined;
    if (s.contains('meta')) return Icons.language;
    if (s.contains('up') || s.contains('seed') || s.contains('upload')) {
      return Icons.arrow_circle_up;
    }
    if (s.contains('dl') || s.contains('download')) {
      return Icons.arrow_circle_down;
    }
    return Icons.help_outline;
  }

  static IconData iconExtension(String fileName) {
    final String n = fileName.toLowerCase().trim();
    if (n.isEmpty) return Icons.insert_drive_file;
    if (!n.contains('.')) return Icons.folder;

    final String ext = n.split('.').last;
    const Set<String> image = <String>{
      'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff', 'heic', 'svg',
    };
    const Set<String> audio = <String>{
      'mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'ape', 'wma', 'dsf',
    };
    const Set<String> video = <String>{
      'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'rmvb', 'ts', 'm2ts', 'mpg',
    };
    const Set<String> archive = <String>{
      'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso',
    };
    const Set<String> doc = <String>{
      'pdf', 'doc', 'docx', 'txt', 'epub', 'mobi', 'azw3', 'chm', 'rtf', 'md',
    };

    if (image.contains(ext)) return Icons.image;
    if (audio.contains(ext)) return Icons.audio_file;
    if (video.contains(ext)) return Icons.local_movies;
    if (archive.contains(ext)) return Icons.compress;
    if (doc.contains(ext)) return Icons.description;
    if (ext == 'exe' || ext == 'msi' || ext == 'apk') return Icons.memory;
    return Icons.insert_drive_file;
  }

  static String getSeederCount(int totalSeeds, int totalLeechs, int active) =>
      '$totalSeeds/$totalLeechs($active)';

  static const Set<String> _logFileExt = <String>{
    'txt', 'log', 'json', 'xml', 'yaml', 'yml', 'ini', 'conf', 'cfg',
    'csv', 'dat', 'db', 'rar', 'zip', 'tar', 'gz', 'iso', 'img', 'bin',
    'exe', 'dll', 'so', 'apk', 'sh', 'bat', 'py', 'dart', 'java',
    'mp3', 'mp4', 'flac', 'wav', 'aac', 'm4a', 'ape', 'avi', 'mov', 'mkv',
    'flv', 'wmv', 'srt', 'ass', 'nfo', 'torrent', 'jpg', 'jpeg', 'gif',
    'webp', 'bmp', 'svg', 'png',
  };

  static final RegExp _reLogIp =
      RegExp(r'\b((?:\d{1,3}\.){3}\d{1,3})(:\d{1,5})?\b');

  static final RegExp _reLogHost = RegExp(
      r'\b([A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,})(?![\w-])(:\d{1,5})?');
  static final RegExp _reStartsWithDigit = RegExp(r'^\d');

  static String maskLogText(String raw) {
    if (raw.isEmpty) return raw;
    String out = raw.replaceAllMapped(_reLogIp, (Match m) {
      final String port = m.group(2) ?? '';
      return '***.***.***.***${port.isEmpty ? '' : ':***'}';
    });
    out = out.replaceAllMapped(_reLogHost, (Match m) {
      final String host = m.group(1) ?? '';
      final String port = m.group(2) ?? '';

      if (host.isEmpty || _reStartsWithDigit.hasMatch(host)) return m.group(0)!;

      if (_logFileExt.contains(host.split('.').last.toLowerCase())) {
        return m.group(0)!;
      }
      return '${maskSite(host)}${port.isEmpty ? '' : ':***'}';
    });
    return out;
  }

  static String maskSite(String host) {
    final String s = host.trim();
    if (s.isEmpty) return s;

    final List<String> seg = s.split('.');
    if (seg.length < 2) {
      if (s.length <= 4) return '***';
      return '${s.substring(0, 1)}***${s.substring(s.length - 1)}';
    }

    final String tail = '.${seg.last}';
    final String main = seg[seg.length - 2];
    if (main.length <= 2) return '***$tail'; 

    return '${main.substring(0, 1)}***$tail';
  }

  static int? sumSeederCount(dynamic stats, bool isSeeder) {
    if (stats is! List) return null;
    final String key = isSeeder ? 'seederCount' : 'leecherCount';
    int total = 0;
    int used = 0;
    for (final dynamic e in stats) {
      if (e is! Map) continue;
      final int v = getInt(e, key, def: -1);
      if (v < 0) continue;
      total += v;
      used++;
    }
    return used == 0 ? null : total;
  }

  static Map<String, int> getTotalCounts(List<Torrent> list) {
    final Map<String, int> map = <String, int>{
      'total': list.length,
      'downloading': 0,
      'seeding': 0,
      'pausedDL': 0,
      'pausedUP': 0,
      'checking': 0,
      'error': 0,
      'uploading': 0,
      'stalled': 0,
    };
    for (final Torrent t in list) {
      if (t.isDownloading) map['downloading'] = map['downloading']! + 1;
      if (t.isSeeding) map['seeding'] = map['seeding']! + 1;
      if (t.isPausedDL) map['pausedDL'] = map['pausedDL']! + 1;
      if (t.isPausedUP) map['pausedUP'] = map['pausedUP']! + 1;
      if (t.isChecking) map['checking'] = map['checking']! + 1;
      if (t.isError) map['error'] = map['error']! + 1;
      if (t.isUploading) map['uploading'] = map['uploading']! + 1;
      if (t.isStalled) map['stalled'] = map['stalled']! + 1;
    }
    return map;
  }

  static int getTotalTrackers(List<Torrent> list) =>
      list.fold(0, (int a, Torrent t) => a + t.trackerCount);

  static Map<String, dynamic> getServerData(
    ServerData server,
    List<Torrent> list,
  ) {
    return <String, dynamic>{
      'name': server.name,
      'type': server.type,
      'address': server.displayAddress,
      'total': list.length,
      'dlSpeed': list.fold(0, (int a, Torrent t) => a + t.dlSpeed),
      'upSpeed': list.fold(0, (int a, Torrent t) => a + t.upSpeed),
      'size': list.fold(0, (int a, Torrent t) => a + t.size),
      'counts': getTotalCounts(list),
    };
  }

  static List<double> updateLineChartData(List<num> samples) {
    if (samples.isEmpty) return <double>[0, 0];
    final List<double> out =
        samples.map((num e) => e.toDouble()).toList(growable: false);
    if (out.length == 1) return <double>[0, out.first];
    return out;
  }

  static List<double> sortChart(List<num> samples, {int keep = 60}) {
    final List<double> data = updateLineChartData(samples);
    if (data.length <= keep) return data;
    return data.sublist(data.length - keep);
  }

  static String setGlobalRatio(num session, num alltime) =>
      '${setRatio(session)} / ${setRatio(alltime)}';

  static String thousands(num v) => NumberFormat.decimalPattern().format(v);

  static Map<String, List<ServerData>> getServersGroupData(
    List<ServerData> servers, {
    bool enableGroup = true,
  }) {
    final Map<String, List<ServerData>> map = <String, List<ServerData>>{};
    for (final ServerData s in servers) {
      final String key = enableGroup ? s.groupName : S.all;
      map.putIfAbsent(key, () => <ServerData>[]).add(s);
    }
    return map;
  }

  static const String _globalPrefix = 'torrentmanager.global.';

  static bool persistSuspended = false;

  static const String _themeKeyPrefix = 'torrentmanager.theme';

  static Future<void> saveGlobalData(String key, Object? value) {
    if (persistSuspended && key.startsWith(_themeKeyPrefix)) {
      return Future<void>.value();
    }
    return SecurePrefs.set('$_globalPrefix$key', value);
  }

  static Future<Object?> getGlobalData(String key) =>
      SecurePrefs.get('$_globalPrefix$key');

  static Future<bool> getGlobalBool(String key, {bool def = false}) async {
    final Object? v = await getGlobalData(key);
    if (v is bool) return v;
    return def;
  }

  static Future<int> getGlobalInt(String key, {int def = 0}) async {
    final Object? v = await getGlobalData(key);
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? def;
    return def;
  }

  static List<String> getFilterFields() => <String>[
        'name',
        'state',
        'category',
        'tags',
        'size',
        'progress',
        'ratio',
        'dlspeed',
        'upspeed',
        'eta',
        'added_on',
        'last_activity',
        'save_path',
        'tracker',
      ];

  static String safeErr(Object e) => NetError.describe(e);

  static Future<bool> checkConnection() async {
    try {
      final List<InternetAddress> r =
          await InternetAddress.lookup('example.com')
              .timeout(const Duration(seconds: 3));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String safeFileName(String raw) {
    String s = raw
        .replaceAll(RegExp(r'[\x00-\x1F\x7F/\\:*?"<>|]'), '_')
        .trim();

    s = s.replaceAll(RegExp(r'[.\s]+$'), '');
    if (s.isEmpty || s == '.' || s == '..') s = 'torrent';
    if (s.length > 80) s = s.substring(0, 80);
    return s;
  }

  static bool isValidUrl(String url) {
    final String v = url.trim();
    if (v.isEmpty) return false;
    final Uri? u = Uri.tryParse(v);
    if (u == null) return false;
    if (u.scheme != 'http' && u.scheme != 'https') return false;
    return u.host.isNotEmpty;
  }

  static String maskUrl(String url) {
    try {
      final Uri uri = Uri.parse(url);
      final Map<String, String> query = <String, String>{};
      uri.queryParameters.forEach((String key, String value) {
        if (key.toLowerCase() == 'passkey') {
          query[key] = _mask(value);
        } else {
          query[key] = value;
        }
      });
      final Uri masked = uri.replace(
        userInfo: uri.userInfo.isNotEmpty ? '***:***' : null,
        queryParameters: query,
      );
      return masked.toString();
    } catch (_) {
      return url;
    }
  }

  static String maskHost(String host) {
    final String h = host.trim();
    if (h.isEmpty) return '***';
    if (h.startsWith('[')) return '[***]';
    final List<String> parts = h.split('.');
    final bool isIpv4 = parts.length == 4 &&
        parts.every((String p) => p.isNotEmpty && int.tryParse(p) != null);
    if (isIpv4) return '${parts[0]}.*.*.*';
    if (parts.length >= 2) return '***.${parts.last}';
    return '***';
  }

  static String maskPasskey(String passkey) => _mask(passkey);

  static String _mask(String value) {
    if (value.length <= 4) return '****';
    return '${value.substring(0, 2)}****${value.substring(value.length - 2)}';
  }

  static String getAuthentication(String user, String pass) {
    final String raw = '$user:$pass';
    return 'Basic ${base64EncodeUtf8(raw)}';
  }

  static final RegExp _reTrackerWithScheme =
      RegExp(r'(?:https?|udp)://(?:www\.)?([^/&:?\s]+)');
  static final RegExp _reTrackerBare = RegExp(r'&tr=(?:www\.)?([^/&:?\s]+)');

  static String? trackerHost(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final String text = _percentDecode(raw);

      final String withScheme =
          _reTrackerWithScheme.firstMatch(text)?.group(1) ?? '';

      final String bare = _reTrackerBare.firstMatch(text)?.group(1) ?? '';
      final String host = withScheme.isNotEmpty ? withScheme : bare;
      if (host.isEmpty) return null;

      final String lower = host.toLowerCase();
      if (lower == 'http' || lower == 'https' || lower == 'udp') return null;
      return decodeIdn(host);
    } catch (_) {
      return null;
    }
  }

  /// 常见「两级后缀」：只取最后两段会得到 `example.com.cn` 里的 `com.cn`，
  /// 站点归类就没意义了 ⇒ 这些后缀要多带一级。
  static const Set<String> _twoLevelSuffixes = <String>{
    'co.uk', 'org.uk', 'me.uk', 'ac.uk', 'gov.uk',
    'com.cn', 'net.cn', 'org.cn', 'gov.cn', 'edu.cn', 'ac.cn',
    'com.hk', 'net.hk', 'org.hk', 'edu.hk', 'gov.hk',
    'com.tw', 'net.tw', 'org.tw', 'edu.tw',
    'co.jp', 'or.jp', 'ne.jp', 'ac.jp', 'go.jp',
    'co.kr', 'or.kr', 'ne.kr',
    'com.au', 'net.au', 'org.au', 'edu.au',
    'com.br', 'net.br', 'org.br',
    'com.sg', 'net.sg', 'org.sg',
    'com.mx', 'com.ar', 'com.tr', 'com.pl', 'com.ua', 'com.vn',
  };

  /// 把完整 host（或 URL）裁成「主域名.根域名」，用于站点归类与去重。
  ///
  /// 例：`tracker.example.com` → `example.com`；`a.b.example.co.uk` → `example.co.uk`；
  /// punycode（`xn--`）会经 [decodeIdn] 还原成可读域名。
  /// 输入不是有效 host（空串 / 纯 IP 之外的杂串）时原样返回小写结果。
  static String registrableDomain(String? raw) {
    if (raw == null) return '';
    String s = raw.trim().toLowerCase();
    if (s.isEmpty) return '';

    final int scheme = s.indexOf('://');
    if (scheme >= 0) s = s.substring(scheme + 3);

    for (final String sep in <String>['/', '?', '#']) {
      final int i = s.indexOf(sep);
      if (i >= 0) s = s.substring(0, i);
    }

    final int at = s.lastIndexOf('@');
    if (at >= 0) s = s.substring(at + 1);

    // 去端口：IPv6 字面量 `[::1]:51413` 不能按冒号切，要先找 `]`。
    if (s.startsWith('[')) {
      final int close = s.indexOf(']');
      if (close >= 0) s = s.substring(0, close + 1);
    } else {
      final int colon = s.indexOf(':');
      if (colon >= 0) s = s.substring(0, colon);
    }

    final String host = decodeIdn(s);
    final List<String> parts =
        host.split('.').where((String e) => e.isNotEmpty).toList();
    if (parts.length < 2) return host;
    // 纯 IPv4（4 段全数字）没有「主域名」概念 ⇒ 原样返回。
    if (parts.length == 4 && parts.every(_isDigits)) return host;

    final String last2 = '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
    final int take = _twoLevelSuffixes.contains(last2) ? 3 : 2;
    if (parts.length <= take) return parts.join('.');
    return parts.sublist(parts.length - take).join('.');
  }

  static bool _isDigits(String s) {
    if (s.isEmpty) return false;
    for (int i = 0; i < s.length; i++) {
      final int c = s.codeUnitAt(i);
      if (c < 48 || c > 57) return false;
    }
    return true;
  }

  static String _percentDecode(String s) {
    if (!s.contains('%')) return s;
    try {
      final String d = Uri.decodeFull(s);
      return d.isEmpty ? s : d;
    } catch (_) {
      return s;
    }
  }

  static String decodeIdn(String host) {
    if (!host.toLowerCase().contains('xn--')) return host;
    return host.split('.').map(decodePunycodeLabel).join('.');
  }

  static String decodePunycodeLabel(String label) {
    const int base = 36;
    const int tmin = 1;
    const int tmax = 26;
    const int initialN = 128;
    const int initialBias = 72;
    final String lower = label.toLowerCase();
    if (!lower.startsWith('xn--')) return label;
    final String body = lower.substring(4);
    final int pos = body.lastIndexOf('-');

    final List<int> output =
        pos > 0 ? body.substring(0, pos).codeUnits.toList() : <int>[];
    final String rest = pos >= 0 ? body.substring(pos + 1) : body;
    if (rest.isEmpty) return label;
    int i = 0;
    int n = initialN;
    int bias = initialBias;
    int idx = 0;
    while (idx < rest.length) {
      final int oldi = i;
      int w = 1;
      int k = base;
      while (true) {
        if (idx >= rest.length) return label; 
        final int digit = _punycodeDigit(rest.codeUnitAt(idx));
        idx++;
        if (digit < 0) return label;
        i = i + digit * w;
        final int t = k <= bias ? tmin : (k >= bias + tmax ? tmax : k - bias);
        if (digit < t) break;
        w = w * (base - t);
        k += base;
      }
      bias = _punycodeAdapt(i - oldi, output.length + 1, oldi == 0);
      n = n + i ~/ (output.length + 1);
      i = i % (output.length + 1);
      output.insert(i, n);
      i++;
    }
    return String.fromCharCodes(output);
  }

  static int _punycodeDigit(int code) {
    if (code >= 0x61 && code <= 0x7A) return code - 0x61;
    if (code >= 0x41 && code <= 0x5A) return code - 0x41;
    if (code >= 0x30 && code <= 0x39) return code - 0x30 + 26;
    return -1;
  }

  static int _punycodeAdapt(int delta, int numPoints, bool firstTime) {
    const int base = 36;
    const int tmin = 1;
    const int tmax = 26;
    const int skew = 38;
    const int damp = 700;
    int d = firstTime ? delta ~/ damp : delta ~/ 2;
    d = d + d ~/ numPoints;
    int k = 0;
    while (d > ((base - tmin) * tmax) ~/ 2) {
      d = d ~/ (base - tmin);
      k = k + base;
    }
    return k + (((base - tmin + 1) * d) ~/ (d + skew));
  }

  static String getIpInfo(String ip) {
    final String v = ip.trim();
    if (v.isEmpty) return S.unknown;
    final List<String> parts = v.split('.');
    if (parts.length != 4) return v.contains(':') ? 'IPv6' : S.unknown;
    final int? a = int.tryParse(parts[0]);
    final int? b = int.tryParse(parts[1]);
    if (a == null || b == null) return S.unknown;
    if (a == 10) return L.t('内网 IP');
    if (a == 172 && b >= 16 && b <= 31) return L.t('内网 IP');
    if (a == 192 && b == 168) return L.t('内网 IP');
    if (a == 127) return L.t('本机');
    if (a == 169 && b == 254) return L.t('链路本地');

    return 'IPv4';
  }

  static bool ipNeedsLookup(String ip) {
    final String info = getIpInfo(ip);
    return info == 'IPv4' || info == 'IPv6';
  }

  static bool getNewVersion(String remote, String local) =>
      compareVersions(remote, local) > 0;

  static int compareVersions(String remote, String local) {
    final List<int> r = _versionParts(remote);
    final List<int> l = _versionParts(local);
    final int n = math.max(r.length, l.length);
    for (int i = 0; i < n; i++) {
      final int rv = i < r.length ? r[i] : 0;
      final int lv = i < l.length ? l[i] : 0;
      if (rv != lv) return rv.compareTo(lv);
    }
    return 0;
  }

  static List<int> _versionParts(String v) {
    final String cleaned = v.trim().replaceAll(RegExp(r'^[vV]'), '');
    final List<int> out = <int>[];
    for (final String seg in cleaned.split(RegExp(r'[.\-+]'))) {
      final int? n = int.tryParse(seg.replaceAll(RegExp(r'\D'), ''));
      out.add(n ?? 0);
    }
    return out;
  }

  static void showToast(
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    AppLog.instance.ui(_oneLine(message), isError: isError);
    AppToast.show(message, isError: isError, isWarning: isWarning);
  }

  static String _oneLine(String s) {
    final String one = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return one.length <= NetError.maxFallbackLength
        ? one
        : '${one.substring(0, NetError.maxFallbackLength)}\u2026';
  }

  static Future<T?> showCustomBottomSheet<T>({
    required Widget child,
    String? title,
    double? heightFactor,
    BuildContext? context,
  }) =>
      BottomPanel.show<T>(
        child: child,
        title: title,
        heightFactor: heightFactor,
        context: context,
      );

  static Future<void> showTerms(BuildContext context) =>
      _showLegal(context, S.termsTitle, S.termsBody);

  static Future<void> showPrivacy(BuildContext context) =>
      _showLegal(context, S.privacyTitle, S.privacyBody);

  static Future<void> showOpenSource(BuildContext context) =>
      _showLegal(context, S.openSourceTitle, S.openSourceBody);

  static Future<void> _showLegal(
    BuildContext context,
    String title,
    String body,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child:
              Text(body, style: const TextStyle(fontSize: 12, height: 1.5)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.ok),
          ),
        ],
      ),
    );
  }

  static Future<DeleteOptions?> showDeleteTorrent(
    BuildContext context, {
    int count = 1,
    bool defaultDeleteFiles = false,
    bool defaultDeleteSub = false,
    bool defaultNoSubDeleteFiles = false,
  }) {
    bool delFiles = defaultDeleteFiles;
    bool delSub = defaultDeleteSub;
    bool noSubDel = defaultNoSubDeleteFiles;

    return showDialog<DeleteOptions>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setState) => AlertDialog(
          title: Text('${S.delete}（${S.torrentCount(count)}）'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ★ D8：删本地文件是**不可逆**的，不能和另外两个开关长得一模一样。
              //   勾上就整块变红 + 顶出红字说明，让人在点「确认执行」前一定看见。
              if (delFiles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    S.deleteFilesWarn(count),
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              CheckboxListTile(
                value: delFiles,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.red,
                title: Text(
                  S.setDelTorrentWithFiles,
                  style: TextStyle(
                    fontSize: 12,
                    color: delFiles ? Colors.red : null,
                    fontWeight: delFiles ? FontWeight.w600 : null,
                  ),
                ),
                onChanged: (bool? v) => setState(() => delFiles = v ?? false),
              ),
              CheckboxListTile(
                value: delSub,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(S.setDelTorrentWithSub,
                    style: const TextStyle(fontSize: 12)),
                onChanged: (bool? v) => setState(() => delSub = v ?? false),
              ),
              CheckboxListTile(
                value: noSubDel,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(S.setDelTorrentNoSubDelFiles,
                    style: const TextStyle(fontSize: 12)),
                onChanged: (bool? v) => setState(() => noSubDel = v ?? false),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(S.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(
                DeleteOptions(
                  deleteFiles: delFiles,
                  deleteSub: delSub,
                  noSubDeleteFiles: noSubDel,
                ),
              ),
              // 勾了删文件 ⇒ 确认按钮也转红（配上上方红字，双保险）。
              style: delFiles
                  ? TextButton.styleFrom(foregroundColor: Colors.red)
                  : null,
              child: Text(S.confirmExecute),
            ),
          ],
        ),
      ),
    );
  }

  static const String _kBgKey = 'torrentmanager.theme.background';
  static const String _kMenuBgKey = 'torrentmanager.theme.menuBackground';

  static Future<String?> getBackgroundImage() async {
    final String? local = await _readPath(_kBgKey);
    if (local != null) return local;
    return 'assets/images/drawer_menu_default.webp';
  }

  static Future<String?> getMenuBackgroundImage() => _readPath(_kMenuBgKey);

  static Future<void> saveBackgroundImage(String path) =>
      _writePath(_kBgKey, path);

  static Future<void> saveMenuBackgroundImage(String path) =>
      _writePath(_kMenuBgKey, path);

  static Future<String?> _readPath(String key) async {
    final Object? v = await SecurePrefs.get(key);
    if (v is! String) return null;
    return v.isEmpty ? null : v;
  }

  static Future<void> _writePath(String key, String path) =>
      SecurePrefs.set(key, path);

  static BoxDecoration? themeBackground({
    String? path,
    double brightness = 0,
  }) {
    if (path == null || path.isEmpty) return null;
    final ImageProvider<Object> image = path.startsWith('assets/')
        ? AssetImage(path) as ImageProvider<Object>
        : FileImage(File(path));
    return BoxDecoration(
      image: DecorationImage(
        image: image,
        fit: BoxFit.cover,
        colorFilter: brightness == 0
            ? null
            : ColorFilter.mode(
                brightness > 0
                    ? Colors.white.withValues(alpha: brightness * 0.6)
                    : Colors.black.withValues(alpha: -brightness * 0.6),
                BlendMode.srcOver,
              ),
      ),
    );
  }
}

class DeleteOptions {
  const DeleteOptions({
    this.deleteFiles = false,
    this.deleteSub = false,
    this.noSubDeleteFiles = false,
  });

  final bool deleteFiles;

  final bool deleteSub;

  final bool noSubDeleteFiles;

  @override
  String toString() =>
      'DeleteOptions(files=$deleteFiles, sub=$deleteSub, noSub=$noSubDeleteFiles)';
}

String base64EncodeUtf8(String raw) => base64.encode(utf8.encode(raw));

class _FmtCache<V> {
  _FmtCache(this.limit);

  final int limit;

  final LinkedHashMap<Object, V> _map = LinkedHashMap<Object, V>();

  V? get(Object key) => _map[key];

  void put(Object key, V value) {
    if (_map.length >= limit && !_map.containsKey(key)) {
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }

  int get length => _map.length;

  void clear() => _map.clear();
}
