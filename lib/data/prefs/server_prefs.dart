import '../models/server_data.dart';
import '../qbittorrent/qb_method.dart';
import '../transmission/tr_method.dart';

class PrefKey {
  PrefKey._();

  static const String upLimit = 'up_limit';
  static const String dlLimit = 'dl_limit';
  static const String altUpLimit = 'alt_up_limit';
  static const String altDlLimit = 'alt_dl_limit';

  static const String altSpeedEnabled = 'alt_speed_enabled';

  static const String dht = 'dht';
  static const String pex = 'pex';
  static const String lsd = 'lsd';
  static const String anonymousMode = 'anonymous_mode';
  static const String encryption = 'encryption';

  static const String savePath = 'save_path';
  static const String tempPath = 'temp_path';
  static const String tempPathEnabled = 'temp_path_enabled';

  static const String queueingEnabled = 'queueing_enabled';
  static const String maxActiveUploads = 'max_active_uploads';
  static const String maxActiveDownloads = 'max_active_downloads';
  static const String maxActiveTorrents = 'max_active_torrents';

  static const String maxRatio = 'max_ratio';

  static const String maxRatioEnabled = 'max_ratio_enabled';
  static const String maxSeedingTime = 'max_seeding_time';
  static const String maxSeedingTimeEnabled = 'max_seeding_time_enabled';
  static const String maxInactiveSeedingTime = 'max_inactive_seeding_time';
  static const String maxInactiveSeedingTimeEnabled =
      'max_inactive_seeding_time_enabled';

  static const String maxConnec = 'max_connec';
  static const String maxConnecPerTorrent = 'max_connec_per_torrent';
  static const String maxUploads = 'max_uploads';
  static const String maxUploadsPerTorrent = 'max_uploads_per_torrent';

  static const String autoTmmEnabled = 'auto_tmm_enabled';
  static const String preallocateAll = 'preallocate_all';
  static const String incompleteFilesExt = 'incomplete_files_ext';

  static const String ipFilterEnabled = 'ip_filter_enabled';
  static const String ipFilterTrackers = 'ip_filter_trackers';
  static const String bannedIps = 'banned_IPs';

  static const String blocklistUrl = 'blocklist_url';

  static const String blocklistSize = 'blocklist_size';
}

typedef PrefsTargetResolver = ServerData Function(ServerData s);

abstract class ServerPrefsApi {
  const ServerPrefsApi();

  bool get isQb;

  QbMethod? get qb;

  void attach(ServerData s);

  Future<bool> ensureSession();

  void reopenSession();

  String? get lastError;

  bool get lastBanned;

  bool get lastMissingCreds;

  Future<Map<String, dynamic>> read();

  Future<Map<String, dynamic>?> readServerState();

  Future<void> write(Map<String, dynamic> patch);

  bool supports(String key);
}

class QbPrefsApi extends ServerPrefsApi {
  QbPrefsApi({required QbMethod client, required PrefsTargetResolver resolve})
      : _c = client,
        _resolve = resolve;

  final QbMethod _c;
  final PrefsTargetResolver _resolve;

  ServerData? _server;

  @override
  bool get isQb => true;

  @override
  QbMethod? get qb => _c;

  @override
  void attach(ServerData s) {
    _server = s;
    _c.setServer(_resolve(s));
  }

  @override
  Future<bool> ensureSession() async {
    final ServerData? s = _server;
    if (s == null) return false;
    return _c.checkQbServerCookie(_resolve(s));
  }

  @override
  void reopenSession() {}

  @override
  String? get lastError => _c.lastLoginError;

  @override
  bool get lastBanned => _c.lastLoginBanned;

  @override
  bool get lastMissingCreds => _c.lastLoginMissingCreds;

  @override
  Future<Map<String, dynamic>> read() async {
    final Map<String, dynamic> p = await _c.getPreferences();

    final Map<String, dynamic> out = <String, dynamic>{};
    for (final String k in _knownKeys) {
      if (p.containsKey(k)) out[k] = p[k];
    }
    return out;
  }

  @override
  Future<Map<String, dynamic>?> readServerState() async {
    try {
      final Map<String, dynamic> md = await _c.getMaindata();
      final dynamic raw = md['server_state'];
      if (raw is! Map) return null;
      final Map<String, dynamic> ss = Map<String, dynamic>.from(raw);

      ss[PrefKey.altSpeedEnabled] = _asBool(ss['use_alt_speed_limits']) ?? false;
      return ss;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> patch) async {
    if (patch.isEmpty) return;
    final Map<String, dynamic> prefs = <String, dynamic>{};
    for (final MapEntry<String, dynamic> e in patch.entries) {
      if (e.value == null) continue;
      if (e.key == PrefKey.altSpeedEnabled) {
        final Map<String, dynamic>? st = await readServerState();
        final bool? cur = _asBool(st?[PrefKey.altSpeedEnabled]);
        if (cur != null && cur != (e.value == true)) {
          await _c.toggleSpeedLimitsMode();
        }
      } else {
        prefs[e.key] = e.value;
      }
    }
    if (prefs.isNotEmpty) await _c.setPreferences(prefs);
  }

  static bool? _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == 'true';
    return null;
  }

  @override
  bool supports(String key) => true;

  static const List<String> _knownKeys = <String>[
    PrefKey.upLimit,
    PrefKey.dlLimit,
    PrefKey.altUpLimit,
    PrefKey.altDlLimit,
    PrefKey.dht,
    PrefKey.pex,
    PrefKey.lsd,
    PrefKey.anonymousMode,
    PrefKey.encryption,
    PrefKey.savePath,
    PrefKey.tempPath,
    PrefKey.tempPathEnabled,
    PrefKey.queueingEnabled,
    PrefKey.maxActiveUploads,
    PrefKey.maxActiveDownloads,
    PrefKey.maxActiveTorrents,
    PrefKey.maxRatio,
    PrefKey.maxRatioEnabled,
    PrefKey.maxSeedingTime,
    PrefKey.maxSeedingTimeEnabled,
    PrefKey.maxInactiveSeedingTime,
    PrefKey.maxInactiveSeedingTimeEnabled,
    PrefKey.maxConnec,
    PrefKey.maxConnecPerTorrent,
    PrefKey.maxUploads,
    PrefKey.maxUploadsPerTorrent,
    PrefKey.autoTmmEnabled,
    PrefKey.preallocateAll,
    PrefKey.incompleteFilesExt,
    PrefKey.ipFilterEnabled,
    PrefKey.ipFilterTrackers,
    PrefKey.bannedIps,
  ];
}

class TrPrefsApi extends ServerPrefsApi {
  TrPrefsApi({required TrMethod client, required PrefsTargetResolver resolve})
      : _c = client,
        _resolve = resolve;

  final TrMethod _c;
  final PrefsTargetResolver _resolve;

  ServerData? _server;

  static const Set<String> _unsupported = <String>{
    PrefKey.maxActiveTorrents,
    PrefKey.maxSeedingTime,
    PrefKey.maxSeedingTimeEnabled,
    PrefKey.maxUploads,
    PrefKey.autoTmmEnabled,
    PrefKey.preallocateAll,
    PrefKey.ipFilterTrackers,
    PrefKey.bannedIps,
    PrefKey.anonymousMode,
  };

  @override
  bool get isQb => false;

  @override
  QbMethod? get qb => null;

  @override
  void attach(ServerData s) {
    _server = s;
    _c.setServer(_resolve(s));
  }

  @override
  Future<bool> ensureSession() async {
    final ServerData? s = _server;
    if (s == null) return false;
    final TrLoginResult r = await _c.checkTrServerCookie(_resolve(s));

    noteLoginResult(r);
    return r.ok;
  }

  @override
  void reopenSession() => _c.invalidateSession();

  String? _lastError;
  bool _lastMissing = false;

  @override
  String? get lastError => _lastError;

  @override
  bool get lastBanned => false;

  @override
  bool get lastMissingCreds => _lastMissing;

  void noteLoginResult(TrLoginResult r) {
    _lastError = r.ok ? null : r.reason;
    _lastMissing = r.missingCreds;
  }

  @override
  Future<Map<String, dynamic>> read() async {
    final Map<String, dynamic> s = await _c.sessionGet();
    final Map<String, dynamic> out = <String, dynamic>{};
    for (final MapEntry<String, String> e in _fromTr.entries) {
      if (!s.containsKey(e.key)) continue;
      out[e.value] = _scaleIn(e.key, s[e.key]);
    }
    return out;
  }

  @override
  Future<Map<String, dynamic>?> readServerState() async {
    try {
      final Map<String, dynamic> s = await _c.sessionGet();
      final dynamic v = s['alt-speed-enabled'];
      final bool? alt = v is bool ? v : (v is num ? v != 0 : null);
      if (alt == null) return null;

      return <String, dynamic>{PrefKey.altSpeedEnabled: alt};
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> patch) async {
    if (patch.isEmpty) return;
    final Map<String, dynamic> fields = <String, dynamic>{};
    for (final MapEntry<String, dynamic> e in patch.entries) {
      if (e.value == null) continue;
      final String? trKey = _toTr[e.key];

      if (trKey == null) continue;
      fields[trKey] = _scaleOut(trKey, e.value);

      // TR 4.1 改名键：同时补发旧键（session-set 忽略未知键，4.0/4.1 各取所需）
      final String? legacy = _trLegacyAlias[trKey];
      if (legacy != null) fields[legacy] = fields[trKey];

      if (trKey == 'speed-limit-up' || trKey == 'speed-limit-down') {
        fields['$trKey-enabled'] = (e.value as num) > 0;
      }

      if (trKey == 'download-queue-enabled') {
        fields['seed-queue-enabled'] = e.value;
      }

      // 注意：不在数值键写入时夹带 enabled 开关（idle-seeding-limit-enabled /
      // seed-ratio-limited），启用状态由设置页开关行单独管理
    }
    if (fields.isEmpty) return;
    try {
      await _c.sessionSet(fields);
    } catch (e) {
      noteLoginResult(TrLoginResult.fail('$e'));
      rethrow;
    }

    if (patch.containsKey(PrefKey.blocklistUrl)) {
      await _c.blocklistUpdate();
    }
  }

  @override
  bool supports(String key) => !_unsupported.contains(key);

  static const Map<String, String> _toTr = <String, String>{
    PrefKey.upLimit: 'speed-limit-up',
    PrefKey.dlLimit: 'speed-limit-down',
    PrefKey.altUpLimit: 'alt-speed-up',
    PrefKey.altDlLimit: 'alt-speed-down',
    PrefKey.altSpeedEnabled: 'alt-speed-enabled',
    PrefKey.dht: 'dht-enabled',
    PrefKey.pex: 'pex-enabled',
    PrefKey.lsd: 'lpd-enabled',
    PrefKey.encryption: 'encryption',
    PrefKey.savePath: 'download-dir',
    PrefKey.tempPath: 'incomplete-dir',
    PrefKey.tempPathEnabled: 'incomplete-dir-enabled',
    PrefKey.queueingEnabled: 'download-queue-enabled',
    PrefKey.maxActiveDownloads: 'download-queue-size',
    PrefKey.maxActiveUploads: 'seed-queue-size',
    // TR 4.1 起以下三键改为 kebab-case（≤4.0 为 camelCase/旧长键），见 _trLegacyAlias
    PrefKey.maxRatio: 'seed-ratio-limit',
    PrefKey.maxRatioEnabled: 'seed-ratio-limited',
    PrefKey.maxInactiveSeedingTime: 'idle-seeding-limit',
    PrefKey.maxInactiveSeedingTimeEnabled: 'idle-seeding-limit-enabled',
    PrefKey.maxConnec: 'peer-limit-global',
    PrefKey.maxConnecPerTorrent: 'peer-limit-per-torrent',
    PrefKey.maxUploadsPerTorrent: 'upload-limit',
    PrefKey.incompleteFilesExt: 'rename-partial-files',
    PrefKey.ipFilterEnabled: 'blocklist-enabled',
    PrefKey.blocklistUrl: 'blocklist-url',
  };

  /// TR 4.1 改名键的旧别名（≤4.0）：写时双发（session-set 忽略未知键，两端安全）、
  /// 读时 _fromTr 双收（4.0 返回旧键、4.1 返回新键）
  static const Map<String, String> _trLegacyAlias = <String, String>{
    'seed-ratio-limit': 'seedRatioLimit',
    'seed-ratio-limited': 'seedRatioLimited',
    'upload-limit': 'upload-slots-per-torrent',
  };

  static final Map<String, String> _fromTr = <String, String>{
    for (final MapEntry<String, String> e in _toTr.entries) e.value: e.key,
    // TR ≤4.0 返回的旧键名（4.1+ 返回 kebab 新键，已由上面循环覆盖）
    'seedRatioLimit': PrefKey.maxRatio,
    'seedRatioLimited': PrefKey.maxRatioEnabled,
    'upload-slots-per-torrent': PrefKey.maxUploadsPerTorrent,
    'blocklist-size': PrefKey.blocklistSize,
  };

  static dynamic _scaleIn(String trKey, dynamic v) {
    if (trKey == 'speed-limit-up' ||
        trKey == 'speed-limit-down' ||
        trKey == 'alt-speed-up' ||
        trKey == 'alt-speed-down') {
      if (v is num) return v * 1024;
    }
    if (trKey == 'encryption') {
      if (v == 'required') return 1;
      if (v == 'preferred' || v == 'tolerated') return 0;
      if (v is num) return v.toInt();
    }
    return v;
  }

  static dynamic _scaleOut(String trKey, dynamic v) {
    if (trKey == 'speed-limit-up' ||
        trKey == 'speed-limit-down' ||
        trKey == 'alt-speed-up' ||
        trKey == 'alt-speed-down') {
      if (v is num) return v ~/ 1024;
    }
    if (trKey == 'encryption') {
      final int n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
      return n == 1 ? 'required' : 'preferred';
    }
    return v;
  }
}

ServerPrefsApi createPrefsApi({
  required ServerData server,
  required QbMethod qbClient,
  required TrMethod trClient,
  required PrefsTargetResolver resolve,
}) {
  if (server.isQbittorrent) {
    return QbPrefsApi(client: qbClient, resolve: resolve);
  }
  return TrPrefsApi(client: trClient, resolve: resolve);
}
