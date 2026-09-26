import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../data/local/local_store.dart';
import '../data/models/server_data.dart';
import '../data/models/server_state.dart';
import '../data/models/torrent.dart';
import '../data/prefs/server_prefs.dart';
import '../data/qbittorrent/qb_method.dart';
import '../data/transmission/tr_method.dart';
import '../utils/app_log.dart';
import '../utils/crypto_box.dart';
import '../utils/file_export.dart';
import '../utils/formatter.dart';
import '../utils/lan_detector.dart';
import '../utils/net_error.dart';
import '../utils/strings.dart';
import 'torrent_controller.dart';

enum ConnStatus { idle, connecting, ok, failed }

enum ConnStage {
  handshake,

  loading;

  String get text => switch (this) {
        ConnStage.handshake => '正在连接服务器…',
        ConnStage.loading => '正在获取种子列表…',
      };
}

class ServerPrefsSnap {
  const ServerPrefsSnap({
    this.prefs = const <String, dynamic>{},
    this.serverState = const <String, dynamic>{},
    this.categories = const <String>[],
    this.tags = const <String>[],
    required this.at,
  });

  final Map<String, dynamic> prefs;

  final Map<String, dynamic> serverState;

  final List<String> categories;

  final List<String> tags;

  final DateTime at;
}

class ServerSpeedLimit {
  const ServerSpeedLimit({this.dl = 0, this.up = 0});

  factory ServerSpeedLimit.fromQbState(
    ServerState st, {
    Map<String, dynamic> altPrefs = const <String, dynamic>{},
  }) {
    int dl = st.dlRateLimit;
    int up = st.upRateLimit;
    if (st.useAltSpeedLimits) {
      dl = Formatter.getInt(altPrefs, 'alt_dl_limit', def: dl);
      up = Formatter.getInt(altPrefs, 'alt_up_limit', def: up);
    }
    return ServerSpeedLimit(dl: dl, up: up);
  }

  factory ServerSpeedLimit.fromTrSession(Map<String, dynamic> sess) {
    final bool alt = sess['alt-speed-enabled'] == true;
    int dl = 0;
    int up = 0;
    if (alt) {
      dl = Formatter.getInt(sess, 'alt-speed-down') * 1024;
      up = Formatter.getInt(sess, 'alt-speed-up') * 1024;
    } else {
      if (sess['speed-limit-down-enabled'] == true) {
        dl = Formatter.getInt(sess, 'speed-limit-down') * 1024;
      }
      if (sess['speed-limit-up-enabled'] == true) {
        up = Formatter.getInt(sess, 'speed-limit-up') * 1024;
      }
    }
    return ServerSpeedLimit(dl: dl, up: up);
  }

  final int dl;

  final int up;
}

class ServerController extends GetxController with WidgetsBindingObserver {
  final servers = <ServerData>[].obs;
  final current = Rxn<ServerData>();

  Future<Directory> Function()? backupFallbackDirProvider;

  @visibleForTesting
  TrMethod Function()? trProbeFactory;

  ServerController({QbMethod? qb, TrMethod? tr})
      : _qbInjected = qb,
        _trInjected = tr;

  final QbMethod? _qbInjected;
  final TrMethod? _trInjected;

  QbMethod? _qbFallback;
  TrMethod? _trFallback;

  QbMethod get qb => clientForQb(current.value?.id);
  TrMethod get tr => clientForTr(current.value?.id);

  ServerData targetFor(ServerData s) =>
      s.connectionTarget(viaLan: lanUsing[s.id] == true);

  QbMethod clientForQb(String? id) {
    final QbMethod? injected = _qbInjected;
    if (id == null) return _qbFallback ??= (injected ?? QbMethod());
    return _bgQb.putIfAbsent(id, () => injected ?? qbFactory());
  }

  TrMethod clientForTr(String? id) {
    final TrMethod? injected = _trInjected;
    if (id == null) return _trFallback ??= (injected ?? TrMethod());
    return _bgTr.putIfAbsent(id, () => injected ?? trFactory());
  }

  final lanUsing = <String, bool>{}.obs;

  final Map<String, bool> _lanMemory = <String, bool>{};

  final lanChecking = <String>{}.obs;

  final connStatus = <String, ConnStatus>{}.obs;

  final connError = <String, String>{}.obs;

  final suspendKind = <String, ConnErrorKind>{}.obs;

  final retryAttempt = <String, int>{}.obs;

  final Map<String, DateTime> _retryNotBefore = <String, DateTime>{};

  @visibleForTesting
  DateTime Function() nowProvider = DateTime.now;

  static const List<int> kBackoffSeconds = <int>[3, 6, 12, 30];

  static const int kMaxConsecutiveFailures = 10;

  static const int kMaxServers = 50;

  static bool prefsPrefetchEnabled = false;

  static const Duration kPrefsCacheTtl = Duration(minutes: 5);

  bool isSuspended(String id) => suspendKind.containsKey(id);

  bool shouldSkipRefresh(String id, {bool force = false}) {
    if (force) return false;
    if (isSuspended(id)) return true;
    final DateTime? at = _retryNotBefore[id];
    if (at != null && nowProvider().isBefore(at)) return true;
    return false;
  }

  void resumeServer(String id) {
    final bool had = suspendKind.remove(id) != null;
    retryAttempt.remove(id);
    _retryNotBefore.remove(id);
    if (had) {
      suspendKind.refresh();
      AppLog.instance.op('解除挂起，恢复自动重试：${_nameOf(id)}',
            scope: LogScope(id, _nameOf(id)));
    }
    retryAttempt.refresh();
  }

  void resumeAll() {
    if (suspendKind.isEmpty && retryAttempt.isEmpty && _retryNotBefore.isEmpty) {
      return;
    }
    suspendKind.clear();
    retryAttempt.clear();
    _retryNotBefore.clear();
    suspendKind.refresh();
    retryAttempt.refresh();
    AppLog.instance.op('手动刷新：解除全部服务器的挂起与退避');
  }

  void _resumeIfWasMissingConfig(String id) {
    if (suspendKind[id] == ConnErrorKind.missingConfig) {
      resumeServer(id);
    }
  }

  String _nameOf(String id) {
    final int i = servers.indexWhere((ServerData e) => e.id == id);
    return i >= 0 ? servers[i].name : id;
  }

  void _failWith(String id, ConnErrorKind kind, String why) {
    _maybeReprobeLanOnFailure(id, kind);

    _connStage.remove(id);
    connStatus[id] = ConnStatus.failed;
    connError[id] = why;
    connStatus.refresh();
    connError.refresh();

    final int n = (retryAttempt[id] ?? 0) + 1;
    retryAttempt[id] = n;
    retryAttempt.refresh();

    if (kind.isFatal) {
      suspendKind[id] = kind;
      suspendKind.refresh();
      AppLog.instance.net('$why ｜ 已暂停该服务器的自动重试（${kind.name}）',
          scope: LogScope(id, _nameOf(id)));
      return;
    }
    if (n >= kMaxConsecutiveFailures) {
      suspendKind[id] = kind;
      suspendKind.refresh();
      AppLog.instance.net(
          '$why ｜ 连续失败 $n 次，已挂起自动重试（${kind.name}）',
          scope: LogScope(id, _nameOf(id)));
      return;
    }
    final int delay = kBackoffSeconds[
        n - 1 < kBackoffSeconds.length ? n - 1 : kBackoffSeconds.length - 1];
    _retryNotBefore[id] = nowProvider().add(Duration(seconds: delay));
    AppLog.instance.net('$why ｜ 第 $n 次失败，${delay}s 后重试',
        scope: LogScope(id, _nameOf(id)));
  }

  void _maybeReprobeLanOnFailure(String id, ConnErrorKind kind) {
    if (kind != ConnErrorKind.unreachable && kind != ConnErrorKind.unknown) {
      return;
    }
    if (retryAttempt[id] != null) return;
    if (_lanMemory[id] != true) return;
    if (_lanFailReprobeInFlight.contains(id)) return;
    final int i = servers.indexWhere((ServerData s) => s.id == id);
    if (i < 0 || !servers[i].hasLan) return;

    _lanFailReprobeInFlight.add(id);

    _lanMemory.remove(id);
    _lanMemoryGen.remove(id);
    AppLog.instance.net('连接失败，立即重探局域网可达性：${_nameOf(id)}',
        scope: LogScope(id, _nameOf(id)));
    unawaited(_startLanProbe(servers[i]).whenComplete(() {
      _lanFailReprobeInFlight.remove(id);
    }));
  }

  void _succeed(String id) {
    connStatus[id] = ConnStatus.ok;
    connError.remove(id);
    connStatus.refresh();
    connError.refresh();
    if (retryAttempt.remove(id) != null) retryAttempt.refresh();
    _retryNotBefore.remove(id);
    if (suspendKind.remove(id) != null) {
      suspendKind.refresh();
      AppLog.instance.op('连接恢复，已解除挂起：${_nameOf(id)}',
          scope: LogScope(id, _nameOf(id)));
    }
  }

  static ConnErrorKind? configProblemOf(ServerData s) {
    final String t = s.type.trim().toLowerCase();
    if (t != 'qbittorrent' && t != 'transmission') {
      return ConnErrorKind.missingConfig;
    }
    if (s.host.trim().isEmpty || s.normalizedHost.isEmpty) {
      return ConnErrorKind.missingConfig;
    }
    if (s.port <= 0 || s.port > 65535) return ConnErrorKind.missingConfig;
    return null;
  }

  void reportConnecting(String id) {
    final bool changed = connStatus[id] != ConnStatus.connecting;
    _setConn(id, ConnStatus.connecting, null);
    _connStage[id] = ConnStage.handshake;
    if (changed) {
      AppLog.instance.view(
        '服务器卡片[${_nameOf(id)}] 连接中…（建连 / 登录）',
        key: '卡片:$id:connecting',
        scope: LogScope(id, _nameOf(id)),
      );
    }
  }

  void reportConnected(String id, {Duration? took, bool sessionOnly = false}) {
    _connStage.remove(id);
    _succeed(id);
    final String t = took == null ? '' : ' ｜ 用时 ${secs(took)}';
    AppLog.instance.view(
      sessionOnly
          ? '服务器卡片[${_nameOf(id)}] 会话已建立（先显示全局速率，种子统计随后）$t'
          : '服务器卡片[${_nameOf(id)}] 数据已获取'
              '$t ｜ 种子 ${torrentsOf(id).length} 个',
      key: sessionOnly ? '卡片:$id:session' : '卡片:$id:connected',
      scope: LogScope(id, _nameOf(id)),
    );
  }

  void reportRefreshed(String id, {required String detail}) {
    AppLog.instance.view(
      '服务器卡片[${_nameOf(id)}] 信息已刷新：$detail',
      key: '卡片:$id:refreshed',
      scope: LogScope(id, _nameOf(id)),
    );
  }

  static String secs(Duration d) =>
      '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';

  final Map<String, ConnStage> _connStage = <String, ConnStage>{};

  void reportStage(String id, ConnStage stage) {
    _connStage[id] = stage;
  }

  String? stageTextOf(String id) => _connStage[id]?.text;

  @visibleForTesting
  Future<void> runNetworkPollForTest() => _onNetworkPoll();

  @visibleForTesting
  void primeLanMemory(Map<String, bool> m) => _lanMemory.addAll(m);

  final serverVersion = <String, String>{}.obs;

  final serverApiVersion = <String, String>{}.obs;

  final Set<String> _versionInFlight = <String>{};

  final ioJobs = <String, int>{}.obs;

  final manualRefreshing = <String>{}.obs;

  bool get isManualRefreshing => manualRefreshing.isNotEmpty;

  Future<void> ensureVersion(ServerData s) async {
    if (s.id.isEmpty) return;
    final String cached = serverVersion[s.id] ?? '';
    if (cached.isNotEmpty) return;
    if (!_versionInFlight.add(s.id)) return;
    try {
      String api = '';
      final String raw;
      if (s.isQbittorrent) {
        final Map<String, String> info = await qb.updateQbInfo();
        raw = info['version'] ?? '';
        api = (info['webapiVersion'] ?? '').trim();
      } else {
        raw = await tr.getVersion();
      }
      final String v = raw.trim();
      if (v.isEmpty) return;
      serverVersion[s.id] = v;
      if (api.isNotEmpty) {
        serverApiVersion[s.id] = api;
        serverApiVersion.refresh();
      }

      serverVersion.refresh();
      AppLog.instance.net(
          api.isEmpty ? '${s.name} 版本号：$v' : '${s.name} 版本：$v（WebAPI $api）',
          scope: s.logScope,
      );
    } catch (e) {
      AppLog.instance.net('取版本号失败（不影响连接）：${NetError.describe(e)}',
          scope: s.logScope);
    } finally {
      _versionInFlight.remove(s.id);
    }
  }

  void reportFailure(String id, Object e) {
    final String why = NetError.describe(e);
    ConnErrorKind kind = NetError.classify(e);

    if (!kind.isRetryable && _isNetworkReason(why)) {
      kind = ConnErrorKind.unreachable;
    }

    _failWith(id, kind, why);
    AppLog.instance.net('连接失败：$why', scope: LogScope(id, _nameOf(id)));
    _logCardFailed(id, why);
  }

  void reportFailureKind(String id, ConnErrorKind kind, String why) {
    _failWith(id, kind, why);
    AppLog.instance.net('连接失败：$why', scope: LogScope(id, _nameOf(id)));
    _logCardFailed(id, why);
  }

  void reportAuthFailure(String id, String reason) {
    final String why = '登录失败：$reason';

    final ConnErrorKind kind = _isNetworkReason(reason)
        ? ConnErrorKind.unreachable
        : ConnErrorKind.authFailed;
    _failWith(id, kind, why);
    AppLog.instance.net(why, scope: LogScope(id, _nameOf(id)));
    _logCardFailed(id, why);
  }

  static bool _isNetworkReason(String reason) {
    const List<String> keys = <String>[
      '无法解析',
      '连接超时',
      '网络不可达',
      '连接被拒绝',
      '网络',
      'SocketException',
    ];
    return keys.any(reason.contains);
  }

  void _logCardFailed(String id, String why) {
    AppLog.instance.view(
      '服务器卡片[${_nameOf(id)}] 连接失败：$why',
      key: '卡片:$id:failed',
      scope: LogScope(id, _nameOf(id)),
      level: 'ERROR',
    );
  }

  Future<bool> relogin(ServerData s) async {
    resumeServer(s.id);
    _setConn(s.id, ConnStatus.connecting, null);
    try {
      if (s.isQbittorrent) {
        qb.setServer(s);
        final bool ok = await qb.updateQbServerCookie(s);
        if (!ok) {
          reportFailureKind(
            s.id,
            qbKindOf(qb),
            qb.lastLoginError ?? '登录失败：服务器拒绝了登录，请检查账号与密码',
          );
          return false;
        }
      } else {
        tr.setServer(s);
        tr.invalidateSession();
        final TrLoginResult r = await tr.updateTrServerCookie(s);
        if (!r.ok) {
          if (r.missingCreds) {
            reportFailureKind(
                s.id, ConnErrorKind.missingConfig, S.srvCredsMissing);
          } else {
            reportAuthFailure(
                s.id, r.reason ?? '服务器拒绝了登录，请检查账号与密码');
          }
          return false;
        }
      }
      reportConnected(s.id);

      if (Get.isRegistered<TorrentController>()) {
        unawaited(Get.find<TorrentController>().refresh());
      }
      return true;
    } catch (e) {
      reportFailure(s.id, e);
      return false;
    }
  }

  static ConnErrorKind qbKindOf(QbMethod c) {
    final ConnErrorKind? net = c.lastLoginKind;
    if (net != null && net != ConnErrorKind.none) {
      if (net.isRetryable) return net;
      if (_isNetworkReason(c.lastLoginError ?? '')) {
        return ConnErrorKind.unreachable;
      }
      return net;
    }
    if (c.lastLoginBanned) return ConnErrorKind.ipBanned;
    if (c.lastLoginMissingCreds) return ConnErrorKind.missingConfig;
    if (_isNetworkReason(c.lastLoginError ?? '')) {
      return ConnErrorKind.unreachable;
    }
    return ConnErrorKind.authFailed;
  }

  void _setConn(String id, ConnStatus st, String? why) {
    connStatus[id] = st;
    if (why == null) {
      connError.remove(id);
    } else {
      connError[id] = why;
    }

    connStatus.refresh();
    connError.refresh();
  }

  static Map<String, dynamic>? _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  final Set<String> _serverInFlight = <String>{};

  final Map<String, DateTime> _serverInFlightAt = <String, DateTime>{};

  @visibleForTesting
  QbMethod Function() qbFactory = QbMethod.new;

  @visibleForTesting
  TrMethod Function() trFactory = TrMethod.new;

  final Map<String, int> _bgRid = <String, int>{};

  int ridOf(String id) => _bgRid[id] ?? 0;

  void setRid(String id, int rid) => _bgRid[id] = rid;

  void resetRid(String id) => _bgRid.remove(id);

  final Map<String, ServerState> _bgState = <String, ServerState>{};

  final Map<String, QbMethod> _bgQb = <String, QbMethod>{};
  final Map<String, TrMethod> _bgTr = <String, TrMethod>{};

  void _dropBgClients(String id) {
    _bgQb.remove(id);
    _bgTr.remove(id);
  }

  final Map<String, Future<Object?>> _sessionInFlight = <String, Future<Object?>>{};

  Future<T> guardSession<T>(String id, Future<T> Function() run) {
    final Future<Object?>? existing = _sessionInFlight[id];
    if (existing != null) {
      return existing.then((Object? _) => run());
    }
    final Future<T> f = run();
    _sessionInFlight[id] = f;
    return f.whenComplete(() => _sessionInFlight.remove(id));
  }

  Future<void> refreshAllServers({
    bool showProgress = false,
    bool force = false,
  }) async {
    if (servers.isEmpty) return;

    final bool hard = force || showProgress;
    if (hard) resumeAll();

    final List<ServerData> targets = <ServerData>[];
    for (final ServerData s in List<ServerData>.of(servers)) {
      if (shouldSkipRefresh(s.id, force: hard)) continue;

      if (!_serverInFlight.contains(s.id)) targets.add(s);
    }
    if (targets.isEmpty) return;

    if (showProgress) {
      for (final ServerData s in targets) {
        manualRefreshing.add(s.id);

        if (connStatus[s.id] != ConnStatus.ok) reportConnecting(s.id);
      }
      manualRefreshing.refresh();
    }

    await Future.wait(targets.map(
      (ServerData s) => _refreshOneServer(s, showProgress: showProgress),
    ));

    if (showProgress) {
      AppLog.instance.op('手动刷新全部服务器（${targets.length} 台）');
    }
  }

  Future<void> retryOne(ServerData s) async {
    resumeServer(s.id);
    AppLog.instance.op('手动重试服务器：${s.name}', scope: s.logScope);

    if (connStatus[s.id] != ConnStatus.ok) reportConnecting(s.id);
    await _refreshOneServer(s, showProgress: false);
  }

  static const int _kMinRefreshVisibleMs = 700;

  Future<void> _refreshOneServer(
    ServerData s, {
    required bool showProgress,
  }) async {
    if (!_serverInFlight.add(s.id)) {
      final DateTime? at = _serverInFlightAt[s.id];
      final String held = at == null
          ? '未知'
          : '${DateTime.now().difference(at).inMilliseconds}ms';
      if (showProgress) {
        AppLog.instance.warn(
          '手动刷新[${s.name}] 被跳过：已有一笔在飞（已持续 $held）',
          scope: s.logScope,
        );
        manualRefreshing.remove(s.id);
        manualRefreshing.refresh();
      } else {
        AppLog.instance.view(
          '服务器卡片[${s.name}] 轮询被跳过：已有一笔在飞（已持续 $held）',
          key: '卡片:${s.id}:inflight-skip',
          level: 'WARN',
          scope: s.logScope,
        );
      }
      return;
    }
    _serverInFlightAt[s.id] = DateTime.now();

    if (!hasAnyCache(s.id)) {
      torrentStatsPending[s.id] = true;
      torrentStatsPending.refresh();
    }

    final Stopwatch sw = Stopwatch()..start();
    try {
      if (s.hasLan &&
          _lanMemoryGen[s.id] != _netEpoch &&
          lanProbeOf(s.id) == null) {
        _startLanProbe(s);
      }

      final Future<void>? probe = lanProbeOf(s.id);
      if (probe != null) await probe;
      await _refreshBackground(s);
    } catch (e) {
      reportFailure(s.id, e);
    } finally {
      if (showProgress) {
        final int rest = _kMinRefreshVisibleMs - sw.elapsedMilliseconds;
        if (rest > 0) {
          await Future<void>.delayed(Duration(milliseconds: rest));
        }
        manualRefreshing.remove(s.id);
        manualRefreshing.refresh();
      }
      _clearStatsPending(s.id);
      _serverInFlight.remove(s.id);

      _serverInFlightAt.remove(s.id);
    }
  }

  final torrentStatsPending = <String, bool>{}.obs;

  void _clearStatsPending(String id) {
    if (torrentStatsPending[id] != true) return;
    torrentStatsPending[id] = false;
    torrentStatsPending.refresh();
  }

  final Set<String> _statsLoadedIds = <String>{};

  bool statsLoadedOnce(String id) => _statsLoadedIds.contains(id);

  ServerState stateOf(String id) => _bgState[id] ?? ServerState();

  Future<bool> _loadQbTransferInfo(ServerData s, QbMethod c) async {
    try {
      final Map<String, dynamic> info = await c.getTransferInfo();
      if (info.isEmpty) return false;
      _bgState.putIfAbsent(s.id, ServerState.new).updateQbData(info);
      if (current.value?.id == s.id) {
        state.value.updateQbData(info);
        state.refresh();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshBackground(ServerData s) async {
    if (connStatus[s.id] != ConnStatus.ok) reportConnecting(s.id);

    final ConnErrorKind? bad = configProblemOf(s);
    if (bad != null) {
      reportFailureKind(s.id, bad, S.srvConfigIncomplete);
      return;
    }

    final ServerData target =
        s.connectionTarget(viaLan: lanUsing[s.id] == true);

    if (s.isQbittorrent) {
      final Stopwatch sw = Stopwatch()..start();

      final QbMethod c = clientForQb(s.id);
      c.setServer(target);

      final bool ok =
          await guardSession<bool>(s.id, () => c.checkQbServerCookie(target));
      if (!ok) {
        reportFailureKind(
          s.id,
          qbKindOf(c),
          c.lastLoginBanned
              ? S.srvIpBanned
              : (c.lastLoginMissingCreds
                  ? S.srvCredsMissing
                  : '登录失败：服务器拒绝了登录，请检查账号与密码'),
        );
        return;
      }

      final Duration loginTook = sw.elapsed;
      final int rid = _bgRid[s.id] ?? 0;
      final bool firstLoad = rid == 0;
      final bool hasSnapshot = hasFullCache(s.id);
      if (firstLoad) {
        if (!hasSnapshot) {
          torrentStatsPending[s.id] = true;
          torrentStatsPending.refresh();
        }
        if (await _loadQbTransferInfo(s, c)) {
          reportConnected(s.id, took: sw.elapsed, sessionOnly: true);
        }
      }
      final Map<String, dynamic> md = await c.getMaindata(rid: rid);
      _bgRid[s.id] = Formatter.getInt(md, 'rid', def: rid);

      final bool full = rid == 0 || Formatter.getBool(md, 'full_update');

      final Map<String, dynamic>? ss = _asMap(md['server_state']);
      if (ss != null) {
        final ServerState st = _bgState.putIfAbsent(s.id, ServerState.new);
        st.updateQbData(ss);

        if (ss.containsKey('queued_io_jobs')) {
          ioJobs[s.id] = st.queuedIoJobs;
          ioJobs.refresh();
        }

        if (current.value?.id == s.id) {
          state.value.updateQbData(ss);
          state.refresh();
        }
      }
      cacheTorrents(
        s.id,
        TorrentController.mergeQbMaindata(torrentsOf(s.id), md, full: full),
      );
      torrentCache.refresh();
      if (firstLoad) {
        torrentStatsPending[s.id] = false;
        torrentStatsPending.refresh();
      }
      _statsLoadedIds.add(s.id);
      reportConnected(s.id, took: sw.elapsed);

      reportRefreshed(
        s.id,
        detail: '种子 ${torrentsOf(s.id).length} 个'
            ' ｜ I/O ${ioJobs[s.id] ?? '-'}'
            ' ｜ 阶段 建连登录 ${secs(loginTook)} · 取数 ${secs(sw.elapsed - loginTook)}'
            ' ｜ 合计 ${secs(sw.elapsed)}',
      );
      await _fetchVersionWith(s, qbClient: c);
      unawaited(_prefetchPrefs(s, qbServerState: ss));
      unawaited(collectSpeedLimits(s));
    } else if (s.isTransmission) {
      final Stopwatch sw = Stopwatch()..start();
      final TrMethod c = clientForTr(s.id);
      c.setServer(target);

      final TrLoginResult r = await guardSession<TrLoginResult>(
          s.id, () => c.checkTrServerCookie());
      if (!r.ok) {
        if (r.routeChanged) {
          AppLog.instance.net(
              '${s.name}：路由切换中，本轮跳过（不判定为登录失败，下一轮重试）',
              scope: s.logScope);
          return;
        }
        if (r.missingCreds) {
          reportFailureKind(s.id, ConnErrorKind.missingConfig, S.srvCredsMissing);
        } else {
          reportAuthFailure(s.id, r.reason ?? '登录失败');
        }
        return;
      }
      final Duration loginTook = sw.elapsed;

      final List<Map<String, dynamic>> raw = await c.torrentGet(lite: true);

      cacheTorrents(s.id, TorrentController.fromTr(raw, scope: s.logScope));
      torrentCache.refresh();
      _clearStatsPending(s.id);

      _statsLoadedIds.add(s.id);
      reportConnected(s.id, took: sw.elapsed);
      reportRefreshed(
        s.id,
        detail: '种子 ${torrentsOf(s.id).length} 个'
            ' ｜ 阶段 建连登录 ${secs(loginTook)} · 取数 ${secs(sw.elapsed - loginTook)}'
            ' ｜ 合计 ${secs(sw.elapsed)}',
      );
      await _fetchVersionWith(s, trClient: c);
      unawaited(_prefetchPrefs(s));
      unawaited(collectSpeedLimits(s));
    }
  }

  Future<void> _fetchVersionWith(
    ServerData s, {
    QbMethod? qbClient,
    TrMethod? trClient,
  }) async {
    if ((serverVersion[s.id] ?? '').isNotEmpty) return;
    try {
      String raw =
          s.isQbittorrent ? (qbClient?.probedVersion[s.id] ?? '') : '';
      if (raw.isEmpty) {
      raw = s.isQbittorrent
          ? (await qbClient!.updateQbInfo())['version'] ?? ''
          : await trClient!.getVersion();
      }
      final String v = raw.trim();
      if (v.isEmpty) return;
      serverVersion[s.id] = v;
      if (s.isQbittorrent) {

        String api = qbClient?.probedApiVersion[s.id] ?? '';
        if (api.trim().isEmpty) {
          api = (await qbClient!.updateQbInfo())['webapiVersion'] ?? '';
        }
        if (api.trim().isNotEmpty) {
          serverApiVersion[s.id] = api.trim();
          serverApiVersion.refresh();
        }
      }
      serverVersion.refresh();
    } catch (e) {
      AppLog.instance.net('取版本号失败（不影响连接）：${NetError.describe(e)}',
          scope: s.logScope);
    }
  }

  final isBusy = false.obs;
  final isSynced = false.obs;

  final backupAt = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();

    loadLocal();
    loadBackupInfo();
    loadBackupDir();

    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _startNetworkWatch();
    }

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    _netWatchTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  static const Duration _netWatchInterval = Duration(seconds: 5);

  Timer? _netWatchTimer;
  Set<String> _lastLocalIps = <String>{};

  bool _ipChangePending = false;

  static const Duration _lanReprobeCooldown = Duration(seconds: 30);

  DateTime? _lastLanReprobeAt;

  final Map<String, int> _lanMemoryGen = <String, int>{};

  final Set<String> _lanFailReprobeInFlight = <String>{};

  int _netEpoch = 0;

  bool _netDown = false;

  final Map<String, int> _lanProbeGenOf = <String, int>{};

  void _startNetworkWatch() {
    _refreshLocalIps();
    _netWatchTimer?.cancel();
    _netWatchTimer = Timer.periodic(_netWatchInterval, (_) => _onNetworkPoll());
  }

  Future<void> _onNetworkPoll() async {
    final bool changed = await _refreshLocalIps();

    final bool offline = _lastLocalIps.isEmpty;
    if (offline) {
      if (!_netDown) {
        _netDown = true;
        _markAllOffline();
      }
      _ipChangePending = false;
      return;
    }
    if (_netDown) {
      _netDown = false;
      _onNetworkBack();
    }

    final ServerData? cur = current.value;
    if (cur == null || !cur.hasLan) {
      _ipChangePending = false;
      return;
    }

    if (changed) {
      if (!_ipChangePending) {
        _ipChangePending = true;
        return;
      }
    } else {
      _ipChangePending = false;
      return;
    }
    _ipChangePending = false;

    final DateTime now = DateTime.now();
    final DateTime? last = _lastLanReprobeAt;
    if (last != null && now.difference(last) < _lanReprobeCooldown) return;
    _lastLanReprobeAt = now;

    _netEpoch++;
    AppLog.instance.net('网络已变化（连续两轮确认），重新探测局域网可达性',
        scope: cur.logScope);

    for (final ServerData s in servers) {
      if (!s.hasLan || s.id == cur.id) continue;
      if (_lanMemoryGen[s.id] == _netEpoch) continue;
      if (lanProbeOf(s.id) != null) continue;
      lanChecking.add(s.id);
      lanChecking.refresh();
      unawaited(_startLanProbe(s));
    }
    await _detectAndApplyLan(cur);
  }

  void _markAllOffline() {
    const String why = '网络已断开（设备当前没有可用网络）';
    int n = 0;
    for (final ServerData s in List<ServerData>.of(servers)) {
      final ConnStatus st = connStatus[s.id] ?? ConnStatus.idle;
      if (st != ConnStatus.ok && st != ConnStatus.connecting) continue;
      reportFailureKind(s.id, ConnErrorKind.unreachable, why);
      n++;
    }
    AppLog.instance.net(
      n > 0
          ? '检测到断网：$n 台服务器标记为连接失败（网络恢复后会自动重试）'
          : '检测到断网（当前没有在线的服务器）',
    );
  }

  void _onNetworkBack() {
    AppLog.instance.net('网络已恢复：解除退避 / 挂起，立即重试全部服务器');
    resumeAll();
    unawaited(refreshAllServers(force: true));
  }

  Future<bool> _refreshLocalIps() async {
    try {
      final List<NetworkInterface> ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final Set<String> now = <String>{
        for (final NetworkInterface n in ifaces)
          for (final InternetAddress a in n.addresses) a.address,
      };
      if (_lastLocalIps.isEmpty) {
        _lastLocalIps = now;
        return false;
      }
      if (now.length == _lastLocalIps.length &&
          now.every(_lastLocalIps.contains)) {
        return false;
      }
      _lastLocalIps = now;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final ServerData? cur = current.value;
    if (cur != null && cur.hasLan) {
      lanUsing.remove(cur.id);
      lanChecking.add(cur.id);
      lanChecking.refresh();
      _startLanProbe(cur);
    }
  }

  Future<void> loadLocal() async {
    try {
      isBusy.value = true;
      servers.value = await LocalStore.loadServers();

      _lanMemory.clear();
      _lanMemoryGen.clear();

      final ServerData? cur = current.value;
      final bool stillThere =
          cur != null && servers.any((ServerData e) => e.id == cur.id);
      if (!stillThere && servers.isNotEmpty) {
        select(servers.first);
      }
    } finally {
      isBusy.value = false;
    }

    unawaited(refreshAllServers());
  }

  Future<void> persist() async {
    await LocalStore.saveServers(servers);
    isSynced.value = false;
  }

  final Map<String, ServerPrefsSnap> _prefsCache = <String, ServerPrefsSnap>{};

  final RxMap<String, ServerSpeedLimit> speedLimits =
      <String, ServerSpeedLimit>{}.obs;

  final Map<String, DateTime> _limitAt = <String, DateTime>{};

  final Map<String, String> _limitSig = <String, String>{};

  static const Duration kLimitCacheTtl = Duration(minutes: 5);

  ServerPrefsSnap? prefsSnapOf(String id) => _prefsCache[id];

  void putPrefsSnap(String id, ServerPrefsSnap snap) => _prefsCache[id] = snap;

  void dropPrefsSnap(String id) => _prefsCache.remove(id);

  Future<void> _prefetchPrefs(ServerData s,
      {Map<String, dynamic>? qbServerState}) async {
    if (!prefsPrefetchEnabled) return;
    final ServerPrefsSnap? cur = _prefsCache[s.id];
    if (cur != null && DateTime.now().difference(cur.at) < kPrefsCacheTtl) {
      return;
    }
    try {
      final ServerPrefsApi api = createPrefsApi(
        server: s,
        qbClient: clientForQb(s.id),
        trClient: clientForTr(s.id),
        resolve: targetFor,
      );
      final Map<String, dynamic> prefs = await api.read();
      List<String> cats = const <String>[];
      List<String> tags = const <String>[];
      final QbMethod? qb = api.qb;
      if (qb != null) {
        try {
          final Map<String, dynamic> c = await qb.getCategories();
          cats = c.keys.map((dynamic k) => k.toString()).toList();
          tags = await qb.getTags();
        } catch (_) {}
      }
      Map<String, dynamic> ss = const <String, dynamic>{};
      if (qbServerState != null) {
        ss = Map<String, dynamic>.from(qbServerState);
        final dynamic v = qbServerState['use_alt_speed_limits'];
        ss[PrefKey.altSpeedEnabled] = v is bool
            ? v
            : (v is num ? v != 0 : (v is String ? v == 'true' : false));
      } else {
        final Map<String, dynamic>? r = await api.readServerState();
        if (r != null) ss = r;
      }
      _prefsCache[s.id] = ServerPrefsSnap(
        prefs: prefs,
        serverState: ss,
        categories: cats,
        tags: tags,
        at: DateTime.now(),
      );
    } catch (_) {}
  }

  ServerSpeedLimit limitOf(String id) =>
      speedLimits[id] ?? const ServerSpeedLimit();

  String _limitSigOf(ServerData s) {
    if (s.isQbittorrent) {
      final ServerState? st = _bgState[s.id];
      if (st == null) return '';
      final Map<String, dynamic> prefs =
          _prefsCache[s.id]?.prefs ?? const <String, dynamic>{};
      return '${st.dlRateLimit}|${st.upRateLimit}|${st.useAltSpeedLimits}'
          '|${prefs['alt_dl_limit']}|${prefs['alt_up_limit']}';
    }
    final Map<String, dynamic>? sess = clientForTr(s.id).lastSession;
    if (sess == null) return '';
    return '${sess['alt-speed-enabled']}|${sess['alt-speed-down']}'
        '|${sess['alt-speed-up']}|${sess['speed-limit-down-enabled']}'
        '|${sess['speed-limit-down']}|${sess['speed-limit-up-enabled']}'
        '|${sess['speed-limit-up']}';
  }

  Future<void> collectSpeedLimits(ServerData s, {bool force = false}) async {
    final DateTime? at = _limitAt[s.id];
    final bool unchanged = at != null &&
        DateTime.now().difference(at) < kLimitCacheTtl &&
        _limitSig[s.id] == _limitSigOf(s);
    if (unchanged && !force) return;
    if (s.isQbittorrent) {
      await _collectQbLimit(s);
    } else if (s.isTransmission) {
      await _collectTrLimit(s);
    }
  }

  Future<void> invalidateSpeedLimit(String id) async {
    _limitAt.remove(id);
    _limitSig.remove(id);
    for (final ServerData s in servers) {
      if (s.id != id) continue;
      if (s.isTransmission) {
        try {
          await clientForTr(id).sessionGet();
        } catch (_) {}
      }
      await collectSpeedLimits(s, force: true);
      return;
    }
  }

  Future<void> _collectQbLimit(ServerData s) async {
    final ServerState? st = _bgState[s.id];
    if (st == null) return;
    Map<String, dynamic> altPrefs = const <String, dynamic>{};
    if (st.useAltSpeedLimits) {
      final ServerPrefsSnap? snap = _prefsCache[s.id];
      if (snap != null) altPrefs = snap.prefs;
    }
    speedLimits[s.id] = ServerSpeedLimit.fromQbState(st, altPrefs: altPrefs);
    _limitAt[s.id] = DateTime.now();
    _limitSig[s.id] = _limitSigOf(s);
  }

  Future<void> _collectTrLimit(ServerData s) async {
    try {
      final TrMethod c = clientForTr(s.id);
      final Map<String, dynamic> sess = c.lastSession ?? await c.sessionGet();
      speedLimits[s.id] = ServerSpeedLimit.fromTrSession(sess);
      _limitAt[s.id] = DateTime.now();
      _limitSig[s.id] = _limitSigOf(s);
    } catch (_) {}
  }

  Future<void> loadBackupInfo() async {
    backupAt.value = await LocalStore.loadBackupAt();
  }

  Future<bool> addServer(ServerData s) async {
    if (servers.length >= kMaxServers) return false;
    servers.add(s);
    await persist();

    AppLog.instance.op('添加服务器：${s.name}（${s.type}）', scope: s.logScope);

    unawaited(_refreshOneServer(s, showProgress: false));
    return true;
  }

  Future<bool> updateServer(ServerData s) async {
    final int i = servers.indexWhere((ServerData e) => e.id == s.id);
    if (i >= 0) {
      servers[i] = s;
    } else {
      if (servers.length >= kMaxServers) return false;
      servers.add(s);
    }
    await persist();

    resumeServer(s.id);

    _dropBgClients(s.id);
    AppLog.instance.op('${i >= 0 ? '修改' : '添加'}服务器：${s.name}（${s.type}）',
        scope: s.logScope);

    unawaited(_refreshOneServer(s, showProgress: false));
    return true;
  }

  Future<void> deleteServer(String id) async {
    final bool wasCurrent = current.value?.id == id;

    final int at = servers.indexWhere((ServerData e) => e.id == id);
    final String name = at >= 0 ? servers[at].name : id;
    servers.removeWhere((ServerData e) => e.id == id);
    if (wasCurrent) {
      current.value = null;

      _resetTorrentView(loading: false);
    }
    _clearRuntimeOf(id);
    await persist();
    AppLog.instance.op(
        '删除服务器：$name${wasCurrent ? '（原为当前服务器，已清空种子视图）' : ''}',
        scope: LogScope(id, name));
  }

  void _clearRuntimeOf(String id) {
    _dropCache(id);
    dropPrefsSnap(id);

    lanUsing.remove(id);
    lanChecking.remove(id);
    connStatus.remove(id);
    connError.remove(id);

    serverVersion.remove(id);
    serverApiVersion.remove(id);

    ioJobs.remove(id);

    _bgRid.remove(id);

    _bgState.remove(id);

    _dropBgClients(id);
    _serverInFlight.remove(id);
    _serverInFlightAt.remove(id);
    manualRefreshing.remove(id);

    _connStage.remove(id);

    suspendKind.remove(id);
    retryAttempt.remove(id);
    _retryNotBefore.remove(id);

    _lanMemory.remove(id);
    _lanMemoryGen.remove(id);

    _lanProbeGenOf.remove(id);

    torrentCache.refresh();
    lanUsing.refresh();
    lanChecking.refresh();
    connStatus.refresh();
    connError.refresh();
    serverVersion.refresh();
    serverApiVersion.refresh();
    ioJobs.refresh();
    manualRefreshing.refresh();
    suspendKind.refresh();
    retryAttempt.refresh();
  }

  Future<void> reorderServer(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= servers.length) return;
    final ServerData s = servers.removeAt(oldIndex);
    final int at = newIndex.clamp(0, servers.length);
    servers.insert(at, s);
    await persist();
    AppLog.instance.op('调整服务器排序：${s.name} → 第 ${at + 1} 位', scope: s.logScope);
  }

  Future<void> reorderWithinGroup(
    List<String> orderedIds,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex < 0 || oldIndex >= orderedIds.length) return;
    final List<String> next = List<String>.of(orderedIds);
    final String moved = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), moved);

    final Set<String> inGroup = next.toSet();
    int k = 0;
    final List<ServerData> result = List<ServerData>.of(servers);
    for (int i = 0; i < result.length; i++) {
      if (!inGroup.contains(result[i].id)) continue;
      final String want = next[k++];

      final int at = servers.indexWhere((ServerData s) => s.id == want);
      if (at < 0) continue;
      result[i] = servers[at];
    }
    servers.assignAll(result);
    await persist();
    AppLog.instance.op('调整分组内服务器排序（本组 ${next.length} 台）');
  }

  void select(ServerData s) {
    current.value = s;

    _connStage.remove(s.id);
    _clearStatsPending(s.id);

    _resetTorrentView();

    final bool rememberedLan = s.hasLan && _lanMemory[s.id] == true;
    final ServerData target = s.connectionTarget(viaLan: rememberedLan);

    AppLog.instance.view(
      '服务器卡片[${s.name}] 首笔请求路由：${rememberedLan ? '局域网' : '公网'}'
      '${s.hasLan ? (rememberedLan ? '' : '（待探测）') : '（未配置局域网）'}'
      ' → ${target.baseUrl}',
      key: '卡片:${s.id}:route',
      scope: s.logScope,
    );
    if (s.isQbittorrent) {
      qb.setServer(target);
    } else if (s.isTransmission) {
      tr.setServer(target);
    }

    if (rememberedLan) {
      lanUsing[s.id] = true;
    } else {
      lanUsing.remove(s.id);
    }

    if (s.hasLan && _lanMemoryGen[s.id] != _netEpoch) {
      lanChecking.add(s.id);
      lanChecking.refresh();
      _startLanProbe(s);
    }
    AppLog.instance.op('切换当前服务器：${s.name}（${s.type}）', scope: s.logScope);
  }

  void _resetTorrentView({bool loading = true}) {
    if (!Get.isRegistered<TorrentController>()) return;
    Get.find<TorrentController>().resetForServerSwitch(loading: loading);
  }

  final Map<String, Future<void>> _lanProbeFutures = <String, Future<void>>{};

  Future<void>? lanProbeOf(String id) => _lanProbeFutures[id];

  Future<void> _startLanProbe(ServerData s) {
    final Future<void> f = _detectAndApplyLan(s);
    _lanProbeFutures[s.id] = f;
    unawaited(f.whenComplete(() {
      if (identical(_lanProbeFutures[s.id], f)) {
        _lanProbeFutures.remove(s.id);
      }
    }));
    return f;
  }

  Future<void> _detectAndApplyLan(ServerData s) async {
    final Stopwatch sw = Stopwatch()..start();
    AppLog.instance.view(
      '局域网探测[${s.name}] 开始：${s.lanHost}:${s.lanPort}',
      key: '局域网:${s.id}:start',
      scope: s.logScope,
    );

    final int gen = _lanProbeGenOf[s.id] = (_lanProbeGenOf[s.id] ?? 0) + 1;
    final bool onLan = await LanDetector.isOnLan(s);

    lanChecking.remove(s.id);
    lanChecking.refresh();

    if (gen != _lanProbeGenOf[s.id]) {
      AppLog.instance.view(
        '局域网探测[${s.name}] 结果已被更新的探测取代（本次结论作废）'
        ' ｜ 用时 ${secs(sw.elapsed)}',
        key: '局域网:${s.id}:superseded',
        scope: s.logScope,
      );
      return;
    }

    final bool useLan =
        onLan && s.isTransmission ? await _trLanIsSameInstance(s) : onLan;

    if (gen != _lanProbeGenOf[s.id]) {
      AppLog.instance.view(
        '局域网探测[${s.name}] 结果已被更新的探测取代（本次结论作废）'
        ' ｜ 用时 ${secs(sw.elapsed)}',
        key: '局域网:${s.id}:superseded',
        scope: s.logScope,
      );
      return;
    }

    lanUsing[s.id] = useLan;

    _lanMemory[s.id] = useLan;

    _lanMemoryGen[s.id] = _netEpoch;
    lanUsing.refresh();

    final ServerData? cur = current.value;
    if (cur == null || cur.id != s.id) {
      final String why = useLan
          ? '可达 → 该台此后走局域网'
          : (onLan
              ? '端口可达但身份校验未通过 → 该台此后走公网'
              : '不可达 → 该台此后走公网');
      AppLog.instance.view(
        '局域网探测[${s.name}] $why'
        '（非当前服务器，仅记录结论） ｜ 用时 ${secs(sw.elapsed)}',
        key: '局域网:${s.id}:result',
        scope: s.logScope,
      );
      return;
    }

    final ServerData target = useLan ? cur.connectionTarget(viaLan: true) : cur;
    if (cur.isQbittorrent) {
      qb.setServer(target);
    } else if (cur.isTransmission) {
      tr.setServer(target);
    }
    if (onLan && !useLan) {
      AppLog.instance.view(
        '局域网探测[${cur.name}] 端口可达，但身份校验未通过（不是同一台 Transmission）'
        ' → 仍走公网 ｜ 用时 ${secs(sw.elapsed)}',
        key: '局域网:${s.id}:result',
        scope: cur.logScope,
      );
    } else if (useLan) {
      AppLog.instance.net('局域网可达，已切换至局域网连接：${cur.name} (${target.baseUrl})',
          scope: cur.logScope);
      AppLog.instance.view(
        '局域网探测[${cur.name}] 可达 → 改走局域网 ｜ 用时 ${secs(sw.elapsed)}',
        key: '局域网:${s.id}:result',
        scope: cur.logScope,
      );
    } else {
      AppLog.instance.net(
          '未检测到局域网（${s.lanHost}:${s.lanPort} 连不上），回落到公网：${cur.name} (${target.baseUrl})',
          scope: cur.logScope);
      AppLog.instance.view(
        '局域网探测[${cur.name}] 不可达（${s.lanHost}:${s.lanPort}）→ 走公网'
        ' ｜ 用时 ${secs(sw.elapsed)}',
        key: '局域网:${s.id}:result',
        scope: cur.logScope,
      );
    }
  }

  Future<bool> _trLanIsSameInstance(ServerData s) async {
    final TrMethod probe = trProbeFactory?.call() ?? TrMethod();
    try {
      final String? wan =
          await _trConfigDir(probe, s.connectionTarget(viaLan: false).baseUrl);
      final String? lan =
          await _trConfigDir(probe, s.connectionTarget(viaLan: true).baseUrl);

      if (wan == null || lan == null) {
        AppLog.instance.net(
            '局域网身份校验跳过：未能取到 config-dir'
            '（公网 ${wan ?? '-'} / 局域网 ${lan ?? '-'}）',
            level: 'WARN',
            scope: s.logScope);
        return true;
      }
      if (wan == lan) {
        AppLog.instance.net('局域网身份校验通过（config-dir 一致：$lan）',
            scope: s.logScope);
        return true;
      }

      AppLog.instance.net(
          '局域网地址指向的 Transmission 与公网不是同一台：'
          'config-dir 局域网=$lan ≠ 公网=$wan ⇒ 放弃走局域网，改用公网',
          level: 'ERROR',
          scope: s.logScope);
      return false;
    } catch (e) {
      AppLog.instance.net(
          '局域网身份校验失败（按同一台处理）：${Formatter.safeErr(e)}',
          level: 'WARN',
          scope: s.logScope);
      return true;
    }
  }

  Future<String?> _trConfigDir(TrMethod c, String baseUrl) async {
    final Map<String, dynamic> m = await c.sessionGet(baseUrl: baseUrl);
    final String v = Formatter.getString(m, 'config-dir');
    return v.isEmpty ? null : v;
  }

  QbMethod? get qbActive => current.value?.isQbittorrent == true ? qb : null;
  TrMethod? get trActive => current.value?.isTransmission == true ? tr : null;

  final backupDir = RxnString();

  static const String _kBackupDir = 'torrentmanager.backup.dir';

  static const String backupFileName = 'torrentmanager_backup.json';

  String? get backupFilePath {
    final String? d = backupDir.value;
    if (d == null || d.isEmpty) return null;
    return '$d/$backupFileName';
  }

  Future<void> loadBackupDir() async {
    final Object? v = await Formatter.getGlobalData(_kBackupDir);
    final String s = v is String ? v : '';
    backupDir.value = s.isEmpty ? null : s;
  }

  Future<bool> pickBackupDir() async {
    final String? dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null || dir.isEmpty) return false;
    backupDir.value = dir;

    await Formatter.saveGlobalData(_kBackupDir, dir);
    AppLog.instance.op('设置备份文件夹：${_logFileName(dir)}');
    return true;
  }

  Future<File> get _fallbackBackupFile async {
    final Directory dir = await (backupFallbackDirProvider?.call() ??
        FileExport.exportDirectory());
    return File('${dir.path}/$backupFileName');
  }

  Future<List<File>> _backupCandidates() async {
    final List<File> out = <File>[];
    final String? chosen = backupFilePath;
    if (chosen != null) out.add(File(chosen));

    try {
      out.add(await _fallbackBackupFile);
    } catch (_) {
    }
    return out;
  }

  Future<String> saveBackup() async {
    final String raw =
        jsonEncode(servers.map((ServerData s) => s.toJson()).toList());
    final String enc = await CryptoBox.encrypt(raw);

    String path = '';

    final String? chosen = backupDir.value;
    if (chosen != null && chosen.isNotEmpty) {
      try {
        final File f = File('$chosen/$backupFileName');
        await f.writeAsString(enc, flush: true);
        path = f.path;
      } catch (e) {
        AppLog.instance.warn(
            '备份写入所选文件夹失败，改用应用私有目录：${Formatter.safeErr(e)}');
      }
    }

    if (path.isEmpty) {
      final File f = await _fallbackBackupFile;
      await f.writeAsString(enc, flush: true);
      path = f.path;
    }

    backupAt.value = DateTime.now();
    isSynced.value = true;
    AppLog.instance.op(
        '导出备份（AES-256-GCM 加密）：${servers.length} 台 → ${_logFileName(path)}');
    return path;
  }

  Future<String?> exportBackupCopy() async {
    if (servers.isEmpty) return null;
    final String raw =
        jsonEncode(servers.map((ServerData s) => s.toJson()).toList());
    final String enc = await CryptoBox.encrypt(raw);
    final String stamp =
        DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '');
    final String name = 'torrentmanager_backup_$stamp.json';
    final String? out = await FilePicker.platform.saveFile(
      dialogTitle: '保存备份副本',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: <String>['json'],

      bytes: utf8.encode(enc),
    );
    if (out == null || out.isEmpty) return null;
    AppLog.instance.op('导出备份副本：${_logFileName(out)}');
    return out;
  }

  static String portableBackupFileName([DateTime? at]) {
    final DateTime d = at ?? DateTime.now();
    final String stamp = '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
    return 'torrentmanager_backup_portable_$stamp.json';
  }

  Future<String> buildPortableBackup(String passphrase) async {
    final String raw =
        jsonEncode(servers.map((ServerData s) => s.toJson()).toList());
    return CryptoBox.encryptWithPassphrase(raw, passphrase);
  }

  Future<String?> exportPortableBackup(String passphrase) async {
    if (servers.isEmpty) return null;
    final String enc = await buildPortableBackup(passphrase);
    final String? out = await FilePicker.platform.saveFile(
      dialogTitle: '保存便携备份',
      fileName: portableBackupFileName(),
      type: FileType.custom,
      allowedExtensions: <String>['json'],

      bytes: utf8.encode(enc),
    );
    if (out == null || out.isEmpty) return null;
    AppLog.instance.op(
        '导出便携备份（口令加密，含密码）：${servers.length} 台 → ${_logFileName(out)}');
    return out;
  }

  Future<int> importPortableBackup(String text, String passphrase) async {
    final String plain = await CryptoBox.decryptWithPassphrase(text, passphrase);
    final List<ServerData> incoming = LocalStore.parseServersJson(plain);
    int added = 0;
    int updated = 0;
    for (final ServerData s in incoming) {
      final int i = servers.indexWhere((ServerData e) => e.id == s.id);
      if (i >= 0) {
        servers[i] = s;
        updated++;
      } else {
        servers.add(s);
        added++;
      }

      _dropBgClients(s.id);
    }
    await persist();

    for (final ServerData s in incoming) {
      _resumeIfWasMissingConfig(s.id);
    }
    AppLog.instance.op(
        '导入便携备份（含密码）：文件 ${incoming.length} 台，新增 $added，覆盖 $updated');
    return added;
  }

  Future<int> restoreBackup() async {
    File? f;
    for (final File c in await _backupCandidates()) {
      if (await c.exists()) {
        f = c;
        break;
      }
    }
    if (f == null) throw StateError('BACKUP_FILE_MISSING');
    final String text = await f.readAsString();

    final String? plain = await CryptoBox.tryDecrypt(text);
    if (plain == null) {
      throw const CryptoBoxException(
          '这不是本机导出的加密备份（内容不是有效的加密信封），已拒绝导入');
    }
    final List<ServerData> local = LocalStore.parseServersJson(plain);
    int added = 0;
    for (final ServerData r in local) {
      final int i = servers.indexWhere((ServerData e) => e.id == r.id);
      if (i >= 0) {
        servers[i] = r;
      } else {
        servers.add(r);
        added++;
      }

      _dropBgClients(r.id);
      _resumeIfWasMissingConfig(r.id);
    }
    await persist();
    AppLog.instance.op('从备份恢复：文件含 ${local.length} 台，新增 $added 台');
    return added;
  }

  Future<void> clearBackup() async {
    final List<String> removed = <String>[];

    for (final File f in await _backupCandidates()) {
      if (await f.exists()) {
        await f.delete();
        removed.add(f.path);
      }
    }
    backupAt.value = null;
    for (final String p in removed) {
      AppLog.instance.op('删除备份文件：${_logFileName(p)}');
    }
  }

  static String _logFileName(String path) {
    final int i = path.lastIndexOf(RegExp(r'[/\\]'));
    return i >= 0 ? path.substring(i + 1) : path;
  }

  final torrentCache = <String, List<Torrent>>{}.obs;

  final state = ServerState().obs;

  void cacheTorrents(String serverId, List<Torrent> list,
      {bool lite = false}) {
    final List<Torrent> capped = list.length > kCacheMaxTorrents
        ? list.sublist(0, kCacheMaxTorrents)
        : list;
    torrentCache[serverId] = capped;
    if (lite) {
      _liteCacheIds.add(serverId);
    } else {
      _liteCacheIds.remove(serverId);
    }
    _touchLru(serverId);
    _evictIfNeeded();
    torrentCache.refresh();
  }

  List<Torrent> torrentsOf(String serverId) {
    final List<Torrent>? v = torrentCache[serverId];
    if (v == null) return const <Torrent>[];
    _touchLru(serverId);
    return v;
  }

  bool hasFullCache(String serverId) =>
      torrentCache.containsKey(serverId) && !_liteCacheIds.contains(serverId);

  bool hasAnyCache(String serverId) => torrentCache.containsKey(serverId);

  void _dropCache(String serverId) {
    torrentCache.remove(serverId);
    _liteCacheIds.remove(serverId);
    _lruOrder.remove(serverId);
    _statsLoadedIds.remove(serverId);
    torrentCache.refresh();
  }

  final List<String> _lruOrder = <String>[];

  final Set<String> _liteCacheIds = <String>{};

  static const int kCacheMaxServers = 5;

  static const int kCacheMaxTorrents = 20000;

  static const int kCacheMaxTotalTorrents = 40000;

  int get _cachedTotal {
    int n = 0;
    for (final List<Torrent> v in torrentCache.values) {
      n += v.length;
    }
    return n;
  }

  void _touchLru(String id) {
    _lruOrder.remove(id);
    _lruOrder.add(id);
  }

  void _evictIfNeeded() {
    final String? keep = current.value?.id;

    int guard = _lruOrder.length + 1;
    while (guard-- > 0) {
      final bool tooManyServers = _lruOrder.length > kCacheMaxServers;
      final bool tooManyTorrents = _cachedTotal > kCacheMaxTotalTorrents;
      if (!tooManyServers && !tooManyTorrents) break;
      final int idx = _lruOrder.indexWhere((String id) => id != keep);
      if (idx < 0) break;
      final String victim = _lruOrder.removeAt(idx);
      torrentCache.remove(victim);
      _liteCacheIds.remove(victim);
    }
  }

  ServerData withSnapshot(ServerData s) =>
      s.copyWith(torrents: torrentsOf(s.id));

  void resetServerState() {
    state.value = ServerState();
    state.refresh();
  }

  void updateServerState(Map<String, dynamic> serverState) {
    state.value.updateQbData(serverState);
    state.refresh();

    final String? id = current.value?.id;
    if (id != null && id.isNotEmpty) {
      ioJobs[id] = state.value.queuedIoJobs;
      ioJobs.refresh();
    }
  }

  int get totalDlSpeed => servers.fold(
        0,
        (int a, ServerData s) =>
            a + torrentsOf(s.id).fold(0, (int b, Torrent t) => b + t.dlSpeed),
      );

  int get totalUpSpeed => servers.fold(
        0,
        (int a, ServerData s) =>
            a + torrentsOf(s.id).fold(0, (int b, Torrent t) => b + t.upSpeed),
      );

  int get totalTorrents =>
      servers.fold(0, (int a, ServerData s) => a + torrentsOf(s.id).length);

  TorrentStatusCounts get totalStatusCounts {
    final List<Torrent> all = <Torrent>[];
    for (final ServerData s in servers) {
      all.addAll(torrentsOf(s.id));
    }
    return TorrentStatusCounts.of(all);
  }

  TransferTotals get transferTotals {
    final List<Torrent> all = <Torrent>[];
    for (final ServerData s in servers) {
      all.addAll(torrentsOf(s.id));
    }
    return TransferTotals.of(all);
  }

  int get onlineServerCount => servers
      .where((ServerData s) => connStatus[s.id] == ConnStatus.ok)
      .length;

  TotalsSnapshot get totalsView {

    final bool anyLive = servers.any((ServerData s) =>
        (connStatus[s.id] ?? ConnStatus.idle) == ConnStatus.ok &&
        torrentCache.containsKey(s.id));
    if (!anyLive) return TotalsSnapshot.empty(serversTotal: servers.length);
    return TotalsSnapshot(
      dlSpeed: totalDlSpeed,
      upSpeed: totalUpSpeed,
      counts: totalStatusCounts,
      totals: transferTotals,
      serversOnline: onlineServerCount,
      serversTotal: servers.length,
    );
  }

  Future<void> toggleHideAddress(String id) async {
    final int i = servers.indexWhere((ServerData e) => e.id == id);
    if (i < 0) return;
    servers[i] = servers[i].copyWith(hideAddress: !servers[i].hideAddress);
    await persist();
    AppLog.instance.op(
        '${servers[i].hideAddress ? '隐藏' : '显示'}服务器地址：${servers[i].name}');
  }

  Future<void> toggleHidePort(String id) async {
    final int i = servers.indexWhere((ServerData e) => e.id == id);
    if (i < 0) return;
    servers[i] = servers[i].copyWith(hidePort: !servers[i].hidePort);
    await persist();
    AppLog.instance.op(
        '${servers[i].hidePort ? '屏蔽' : '显示'}服务器端口：${servers[i].name}');
  }

  static bool nextPrivacyHidden({
    required bool hideAddress,
    required bool hidePort,
  }) =>
      !(hideAddress && hidePort);

  Future<void> toggleHideAddressPort(String id, {required bool hide}) async {
    final int i = servers.indexWhere((ServerData e) => e.id == id);
    if (i < 0) return;
    servers[i] = servers[i].copyWith(hideAddress: hide, hidePort: hide);
    await persist();
    AppLog.instance.op(
        '${hide ? '隐藏' : '显示'}服务器地址与端口：${servers[i].name}');
  }
}
