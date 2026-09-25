import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../data/models/server_data.dart';
import '../data/models/torrent.dart';
import '../data/server_capabilities.dart';

import '../data/transmission/tr_method.dart';
import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../utils/net_error.dart';
import '../utils/strings.dart';
import 'server_controller.dart';

enum TorrentSortKey {
  size,
  ratio,
  seeds,
  dlSpeed,
  upSpeed,
  downloaded,
  uploaded,
  addedOn,
  completionOn,
  seedingTime,
  name,
  progress,
  state,
}

extension TorrentSortKeyExt on TorrentSortKey {
  String get label {
    switch (this) {
      case TorrentSortKey.size:
        return '种子大小';
      case TorrentSortKey.ratio:
        return '分享比率';
      case TorrentSortKey.seeds:
        return '做种人数';
      case TorrentSortKey.dlSpeed:
        return '下载速度';
      case TorrentSortKey.upSpeed:
        return '上传速度';
      case TorrentSortKey.downloaded:
        return '下载总量';
      case TorrentSortKey.uploaded:
        return '上传总量';
      case TorrentSortKey.addedOn:
        return '添加时间';
      case TorrentSortKey.completionOn:
        return '完成时间';
      case TorrentSortKey.seedingTime:
        return '做种时长';
      case TorrentSortKey.name:
        return '种子名称';
      case TorrentSortKey.progress:
        return '种子进度';
      case TorrentSortKey.state:
        return '种子状态';
    }
  }
}

enum TorrentFilter {
  all,
  downloading,
  seeding,
  completed,
  paused,
  queued,
  checking,
  error,
  active,
}

extension TorrentFilterExt on TorrentFilter {
  String get label {
    switch (this) {
      case TorrentFilter.all:
        return S.filterAll;
      case TorrentFilter.downloading:
        return S.filterDownloading;
      case TorrentFilter.seeding:
        return S.filterSeeding;
      case TorrentFilter.completed:
        return S.filterCompleted;
      case TorrentFilter.paused:
        return S.filterPaused;
      case TorrentFilter.queued:
        return S.filterQueued;
      case TorrentFilter.checking:
        return S.filterChecking;
      case TorrentFilter.error:
        return S.filterError;
      case TorrentFilter.active:
        return S.filterActive;
    }
  }

  String? get qbValue {
    switch (this) {
      case TorrentFilter.all:
        return null;
      case TorrentFilter.downloading:
        return 'downloading';
      case TorrentFilter.seeding:
        return 'seeding';
      case TorrentFilter.completed:
        return 'completed';
      case TorrentFilter.paused:
        return 'paused';
      case TorrentFilter.queued:
        return 'queued';
      case TorrentFilter.checking:
        return 'checking';
      case TorrentFilter.error:
        return 'errored';
      case TorrentFilter.active:
        return 'active';
    }
  }

  bool matches(Torrent t) {
    switch (this) {
      case TorrentFilter.all:
        return true;
      case TorrentFilter.downloading:

        return t.statusGroup == TorrentStatusGroup.downloading;
      case TorrentFilter.seeding:

        return t.statusGroup == TorrentStatusGroup.seeding;
      case TorrentFilter.completed:
        return t.progress >= 1.0;
      case TorrentFilter.paused:
        return t.statusGroup == TorrentStatusGroup.paused;
      case TorrentFilter.queued:
        return t.statusGroup == TorrentStatusGroup.queued;
      case TorrentFilter.checking:
        return t.statusGroup == TorrentStatusGroup.checking;
      case TorrentFilter.error:
        return t.statusGroup == TorrentStatusGroup.error;
      case TorrentFilter.active:
        return t.dlSpeed > 0 || t.upSpeed > 0;
    }
  }
}

abstract final class SubStates {

  static const Map<TorrentFilter, List<String>> qb = <TorrentFilter, List<String>>{
    TorrentFilter.downloading: <String>[
      'downloading',
      'stalledDL',
      'metaDL',
      'forcedDL',
      'forcedMetaDL',
    ],
    TorrentFilter.seeding: <String>[
      'uploading',
      'seeding',
      'stalledUP',
      'forcedUP',
    ],

    TorrentFilter.paused: <String>['stoppedDL', 'stoppedUP'],
    TorrentFilter.queued: <String>['queuedDL', 'queuedUP'],
    TorrentFilter.checking: <String>[
      'checkingDL',
      'checkingUP',
      'checkingResumeData',
    ],
    TorrentFilter.error: <String>['error', 'missingFiles'],

    TorrentFilter.completed: <String>[],
    TorrentFilter.active: <String>[],
    TorrentFilter.all: <String>[],
  };

  static const Map<TorrentFilter, List<String>> tr = <TorrentFilter, List<String>>{
    TorrentFilter.paused: <String>['0'],
    TorrentFilter.checking: <String>['1', '2'],
    TorrentFilter.queued: <String>['1', '3', '5'],
    TorrentFilter.downloading: <String>['4'],
    TorrentFilter.seeding: <String>['5', '6'],

    TorrentFilter.error: <String>[],
    TorrentFilter.completed: <String>[],
    TorrentFilter.active: <String>[],
    TorrentFilter.all: <String>[],
  };

  static String normalize(String raw) {
    switch (raw) {
      case 'pausedDL':
        return 'stoppedDL';
      case 'pausedUP':
        return 'stoppedUP';
      default:
        return raw;
    }
  }

  static String labelOf(String raw) {
    switch (raw) {

      case 'downloading':
        return S.stDownloading;
      case 'stalledDL':
        return S.stStalledDl;
      case 'metaDL':
        return S.stMetaDl;
      case 'forcedDL':
        return S.stForcedDl;
      case 'uploading':
        return S.stUploading;
      case 'seeding':
        return S.stSeeding;
      case 'stalledUP':
        return S.stStalledUp;
      case 'forcedUP':
        return S.stForcedUp;
      case 'stoppedDL':
      case 'pausedDL':
        return S.stPausedDl;
      case 'stoppedUP':
      case 'pausedUP':
        return S.stPausedUp;
      case 'queuedDL':
        return S.stQueuedDl;
      case 'queuedUP':
        return S.stQueuedUp;
      case 'checkingDL':
        return S.stCheckingDl;
      case 'checkingUP':
        return S.stCheckingUp;
      case 'checkingResumeData':
        return S.stCheckingResume;
      case 'error':
        return S.stError;
      case 'missingFiles':
        return S.stMissingFiles;
      case 'moving':
        return S.stMoving;
      case 'allocating':
        return S.stAllocating;

      case '0':
        return S.stTrStopped;
      case '1':
        return S.stTrCheckWait;
      case '2':
        return S.stTrChecking;
      case '3':
        return S.stTrQueueDl;
      case '4':
        return S.stTrDownloading;
      case '5':
        return S.stTrQueueUp;
      case '6':
        return S.stTrSeeding;
      case '7':
        return S.stTrIsolated;
      default:
        return raw.isEmpty ? S.stUnknownState : raw;
    }
  }
}

enum FilterDim {
  category,
  tags,
  path,
  site,
}

extension FilterDimExt on FilterDim {
  String get title {
    switch (this) {
      case FilterDim.category:
        return '分类';
      case FilterDim.tags:
        return '标签';
      case FilterDim.path:
        return '路径';
      case FilterDim.site:
        return '站点';
    }
  }
}

class FacetEntry {
  const FacetEntry(this.value, this.count);

  final String value;
  final int count;
}

class DeletePlan {
  const DeletePlan({required this.deleteFiles, required this.subs});

  final bool deleteFiles;

  final List<Torrent> subs;
}

class DeleteBatch {
  const DeleteBatch(this.items, {required this.deleteFiles});

  final List<Torrent> items;

  final bool deleteFiles;
}

class TorrentController extends GetxController {
  final items = <Torrent>[].obs;
  final isLoading = false.obs;
  final error = RxnString();

  final ServerController serverCtrl = Get.find<ServerController>();

  final sortKey = TorrentSortKey.addedOn.obs;

  final sortDesc = true.obs;

  final filter = TorrentFilter.all.obs;
  final keyword = ''.obs;

  final subStates = <String>[].obs;

  final selCategories = <String>[].obs;
  final selTags = <String>[].obs;
  final selPaths = <String>[].obs;
  final selSites = <String>[].obs;

  final selected = <String>{}.obs;

  final current = Rxn<Torrent>();
  final files = <Map<String, dynamic>>[].obs;
  final peers = <Map<String, dynamic>>[].obs;
  final trackers = <Map<String, dynamic>>[].obs;
  final detailLoading = false.obs;

  final dlSamples = <double>[].obs;
  final ulSamples = <double>[].obs;

  static const int kSampleCap = 60;

  final detailSyncedAt = Rxn<DateTime>();

  final lastActionOk = Rxn<bool>();

  int get _rid => serverCtrl.ridOf(serverCtrl.current.value?.id ?? '');

  set _rid(int v) {
    final String? id = serverCtrl.current.value?.id;
    if (id != null) serverCtrl.setRid(id, v);
  }

  String? _ridServerId;

  bool _autoInFlight = false;

  String? _autoServerId;

  bool _listVisible = false;

  void setListVisible(bool v) {
    if (_listVisible == v) return;
    _listVisible = v;
    AppLog.instance.view(
      '种子列表页 ${v ? '进入前台 → 恢复自动取数' : '退到后台 → 停止自动取数'}',
      key: '列表:visible',
    );
    if (v) unawaited(refreshAuto());
  }

  @override
  void onInit() {
    super.onInit();
    _loadSort();
    loadSiteMasked();

    _currentWorker?.dispose();
    _currentWorker = ever<ServerData?>(serverCtrl.current, (ServerData? s) {
      if (s == null) return;

      subStates.clear();
      if (_listVisible) refreshAuto();
    });

    _itemsWorker?.dispose();
    _itemsWorker =
        ever<List<Torrent>>(items, (List<Torrent> _) => _dataVersion++);
  }

  Worker? _currentWorker;

  Worker? _itemsWorker;

  @override
  void onClose() {
    _currentWorker?.dispose();
    _currentWorker = null;
    _itemsWorker?.dispose();
    _itemsWorker = null;
    super.onClose();
  }

  bool get isSelecting => selected.isNotEmpty;

  List<Torrent>? _visibleCache;
  String? _visibleToken;

  int _dataVersion = 0;

  void _setItems(List<Torrent> v) {
    items.value = v;
    _dataVersion++;
  }

  @visibleForTesting
  void debugSetItems(List<Torrent> v) => _setItems(v);

  String _visibleTokenOf() {
    final StringBuffer b = StringBuffer()
      ..write(_dataVersion)
      ..write('|')
      ..write(items.length)
      ..write('|')
      ..write(filter.value.index)
      ..write('|')
      ..write(subStates.join('\u0002'))
      ..write('|')
      ..write(keyword.value)
      ..write('|')
      ..write(sortKey.value.index)
      ..write('|')
      ..write(sortDesc.value)
      ..write('|')
      ..write(selCategories.join('\u0001'))
      ..write('|')
      ..write(selTags.join('\u0001'))
      ..write('|')
      ..write(selPaths.join('\u0001'))
      ..write('|')
      ..write(selSites.join('\u0001'));
    return b.toString();
  }

  List<Torrent> get visibleItems {
    final String t = _visibleTokenOf();
    if (_visibleToken == t && _visibleCache != null) {
      return _visibleCache!;
    }
    _visibleCache = _sorted(_filtered());
    _visibleToken = t;
    return _visibleCache!;
  }

  List<Torrent> _filtered({FilterDim? skip}) =>
      items.where((Torrent t) => _matches(t, skip: skip)).toList();

  List<Torrent> get sortedItems => _sorted(List<Torrent>.of(items));

  RxList<String> selection(FilterDim d) {
    switch (d) {
      case FilterDim.category:
        return selCategories;
      case FilterDim.tags:
        return selTags;
      case FilterDim.path:
        return selPaths;
      case FilterDim.site:
        return selSites;
    }
  }

  List<String> facetValues(Torrent t, FilterDim d) {
    switch (d) {
      case FilterDim.category:
        return <String>[t.categoryName];
      case FilterDim.tags:
        return t.tagList.isEmpty ? const <String>['未标记'] : t.tagList;
      case FilterDim.path:
        return <String>[t.pathName];
      case FilterDim.site:
        return <String>[t.site.isEmpty ? '未知站点' : t.site];
    }
  }

  bool _matches(Torrent t, {FilterDim? skip, String? kwLower}) {
    if (!filter.value.matches(t)) return false;
    if (subStates.isNotEmpty &&
        !subStates.contains(SubStates.normalize(t.rawState))) {
      return false;
    }
    final String kw = kwLower ?? keyword.value.trim().toLowerCase();
    if (kw.isNotEmpty && !t.name.toLowerCase().contains(kw)) return false;
    for (final FilterDim d in FilterDim.values) {
      if (d == skip) continue;
      final List<String> sel = selection(d);
      if (sel.isEmpty) continue;

      if (!facetValues(t, d).any(sel.contains)) return false;
    }
    return true;
  }

  List<FacetEntry> facets(FilterDim d) {
    final String token = _facetTokenOf();
    if (token != _facetToken) {
      _facetToken = token;
      _facetCache.clear();
    }
    final List<FacetEntry>? cached = _facetCache[d];
    if (cached != null) return cached;

    final String kw = keyword.value.trim().toLowerCase();
    final Map<String, int> count = <String, int>{};
    for (final Torrent t in items) {
      if (!_matches(t, skip: d, kwLower: kw)) continue;
      for (final String v in facetValues(t, d)) {
        count[v] = (count[v] ?? 0) + 1;
      }
    }

    for (final String v in selection(d)) {
      count.putIfAbsent(v, () => 0);
    }
    final List<FacetEntry> out = count.entries
        .map((MapEntry<String, int> e) => FacetEntry(e.key, e.value))
        .toList();
    out.sort((FacetEntry a, FacetEntry b) {
      final int byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.value.compareTo(b.value);
    });
    _facetCache[d] = out;
    return out;
  }

  String? _facetToken;
  final Map<FilterDim, List<FacetEntry>> _facetCache =
      <FilterDim, List<FacetEntry>>{};

  String _facetTokenOf() {
    final StringBuffer b = StringBuffer();
    for (final Torrent t in items) {
      b
        ..write(t.hash)
        ..write(',');
    }
    b
      ..write('\u0001')
      ..write(keyword.value)
      ..write('\u0001')
      ..write(filter.value.name)
      ..write('\u0001')
      ..write(subStates.join('\u0002'))
      ..write('\u0001');
    for (final FilterDim d in FilterDim.values) {
      b
        ..write(d.index)
        ..write(':')
        ..write(selection(d).join(','))
        ..write(';');
    }
    return b.toString();
  }

  void toggleFacet(FilterDim d, String value) {
    final RxList<String> sel = selection(d);
    if (!sel.remove(value)) sel.add(value);
  }

  void clearFacets() {
    selCategories.clear();
    selTags.clear();
    selPaths.clear();
    selSites.clear();
  }

  void clearFacet(FilterDim d) {
    selection(d).clear();
  }

  bool get hasFacets =>
      selCategories.isNotEmpty ||
      selTags.isNotEmpty ||
      selPaths.isNotEmpty ||
      selSites.isNotEmpty;

  bool hasFacet(FilterDim d) => selection(d).isNotEmpty;

  List<Torrent> _sorted(List<Torrent> list) {
    final int dir = sortDesc.value ? -1 : 1;
    int cmp(TorrentSortKey k, Torrent a, Torrent b) {
      switch (k) {
        case TorrentSortKey.size:
          return a.size.compareTo(b.size);
        case TorrentSortKey.ratio:
          return a.ratio.compareTo(b.ratio);
        case TorrentSortKey.seeds:

          return a.numComplete.compareTo(b.numComplete);
        case TorrentSortKey.dlSpeed:
          return a.dlSpeed.compareTo(b.dlSpeed);
        case TorrentSortKey.upSpeed:
          return a.upSpeed.compareTo(b.upSpeed);
        case TorrentSortKey.downloaded:
          return a.downloaded.compareTo(b.downloaded);
        case TorrentSortKey.uploaded:
          return a.uploaded.compareTo(b.uploaded);
        case TorrentSortKey.addedOn:
          return a.addedOn.compareTo(b.addedOn);
        case TorrentSortKey.completionOn:
          return a.completionOn.compareTo(b.completionOn);
        case TorrentSortKey.seedingTime:
          return a.seedingTime.compareTo(b.seedingTime);
        case TorrentSortKey.name:
          return a.name.compareTo(b.name);
        case TorrentSortKey.progress:
          return a.progress.compareTo(b.progress);
        case TorrentSortKey.state:
          return a.state.compareTo(b.state);
      }
    }

    list.sort((Torrent a, Torrent b) {
      final int r = cmp(sortKey.value, a, b) * dir;
      if (r != 0) return r;

      final int byTime = b.addedOn.compareTo(a.addedOn);
      return byTime != 0 ? byTime : a.hash.compareTo(b.hash);
    });
    return list;
  }

  @override
  Future<void> refresh() async {
    final s = serverCtrl.current.value;
    if (s == null) {
      isLoading.value = false;
      return;
    }

    if (_refreshInFlight && _inFlightServerId == s.id) return;

    serverCtrl.resumeServer(s.id);
    final ConnErrorKind? cfgBad = ServerController.configProblemOf(s);
    if (cfgBad != null) {
      isLoading.value = false;
      error.value = S.srvConfigIncomplete;
      serverCtrl.reportFailureKind(s.id, cfgBad, S.srvConfigIncomplete);
      return;
    }

    final String targetId = s.id;
    final int seq = ++_reqSeq;
    _refreshInFlight = true;
    _inFlightServerId = targetId;
    _inFlightSeq = seq;

    final Stopwatch sw = Stopwatch()..start();

    if (items.isEmpty && serverCtrl.hasFullCache(targetId)) {
      final List<Torrent> cached = serverCtrl.torrentsOf(targetId);
      if (cached.isNotEmpty) {
        _setItems(cached.toList());
        AppLog.instance.view(
          '种子列表[${s.name}] 先用缓存渲染 ${cached.length} 条（真实数据随后覆盖）',
          key: '列表:${s.id}:cache',
          scope: s.logScope,
        );
      }
    }

    final Future<void>? lanProbe = serverCtrl.lanProbeOf(targetId);
    if (lanProbe != null) await lanProbe;
    try {
      if (serverCtrl.connStatus[s.id] != ConnStatus.ok) {
        serverCtrl.reportConnecting(s.id);
      }
      isLoading.value = true;
      error.value = null;
      AppLog.instance.view(
        '种子列表[${s.name}] 开始加载（全量）',
        key: '列表:${s.id}:start',
        scope: s.logScope,
      );
      if (s.isQbittorrent) {
        final bool logged = await serverCtrl.guardSession<bool>(
            s.id, () => serverCtrl.qb.checkQbServerCookie());
        if (_isStale(targetId, seq)) return;

        if (!logged &&
            (serverCtrl.qb.lastLoginMissingCreds ||
                serverCtrl.qb.lastLoginBanned)) {
          final String why = serverCtrl.qb.lastLoginBanned
              ? S.srvIpBanned
              : S.srvCredsMissing;
          error.value = why;
          serverCtrl.reportFailureKind(
              s.id, ServerController.qbKindOf(serverCtrl.qb), why);
          return;
        }

        serverCtrl.reportStage(s.id, ConnStage.loading);
        List<Torrent> list;

        try {
          list = await serverCtrl.qb.getTorrentList();
        } catch (e) {
          if (_isStale(targetId, seq)) rethrow;

          final bool relogged = await serverCtrl.guardSession<bool>(
              s.id, () => serverCtrl.qb.checkQbServerCookie(s));
          if (_isStale(targetId, seq)) rethrow;
          if (!relogged) {
            if (serverCtrl.qb.lastLoginBanned) {
              error.value = S.srvIpBanned;
              serverCtrl.reportFailureKind(
                  s.id, ConnErrorKind.ipBanned, S.srvIpBanned);
              return;
            }
            rethrow;
          }
          AppLog.instance.net('列表请求 403，已重新登录并重试',
              scope: s.logScope);
          list = await serverCtrl.qb.getTorrentList();
        }
        if (_isStale(targetId, seq)) return;
        _setItems(list);
        _syncCurrentFromItems();

        try {
          final Map<String, dynamic> md =
              await serverCtrl.qb.updateQbMaindata();
          if (_isStale(targetId, seq)) return;
          final Map<String, dynamic>? ss = _asStringKeyMap(md['server_state']);
          if (ss != null) serverCtrl.updateServerState(ss);
          _rid = Formatter.getInt(md, 'rid', def: 0);
        } catch (_) {
          _rid = 0;
        }
      } else {
        final TrLoginResult r = await serverCtrl.guardSession<TrLoginResult>(
            s.id, () => serverCtrl.tr.checkTrServerCookie());
        if (_isStale(targetId, seq)) return;
        if (!r.ok) {
          final String why = r.reason ?? '登录失败';
          error.value = why;

          if (r.missingCreds) {
            serverCtrl.reportFailureKind(
                s.id, ConnErrorKind.missingConfig, S.srvCredsMissing);
          } else {
            serverCtrl.reportAuthFailure(s.id, why);
          }
          return;
        }
        final List<Map<String, dynamic>> raw = await serverCtrl.tr.torrentGet();
        if (_isStale(targetId, seq)) return;
        _setItems(fromTr(raw));
        _syncCurrentFromItems();
      }

      serverCtrl.cacheTorrents(s.id, items.toList());

      _ridServerId = s.id;

      AppLog.instance.view(
        '种子列表[${s.name}] 全量 ${items.length} 条已就绪'
        ' ｜ 用时 ${ServerController.secs(sw.elapsed)}',
        key: '列表:${s.id}:full',
        scope: s.logScope,
      );
      serverCtrl.reportConnected(s.id);

      unawaited(serverCtrl.ensureVersion(s));
    } catch (e) {
      if (_isStale(targetId, seq)) return;
      error.value = e.toString();
      serverCtrl.reportFailure(s.id, e);
    } finally {
      if (seq == _reqSeq) isLoading.value = false;

      if (_inFlightSeq == seq) _refreshInFlight = false;
    }
  }

  int _reqSeq = 0;

  bool _refreshInFlight = false;
  String? _inFlightServerId;
  int _inFlightSeq = 0;

  bool _isStale(String targetServerId, int seq) {
    if (seq != _reqSeq) return true;
    return serverCtrl.current.value?.id != targetServerId;
  }

  void resetForServerSwitch({bool loading = true}) {
    _reqSeq++;

    _ridServerId = null;
    _rid = 0;

    serverCtrl.resetServerState();

    _setItems(<Torrent>[]);
    selected.clear();
    clearFacets();
    keyword.value = '';
    current.value = null;
    files.clear();
    peers.clear();
    trackers.clear();
    error.value = null;
    isLoading.value = loading;
  }

  bool _scrollPaused = false;

  bool get scrollPaused => _scrollPaused;

  void setScrollPaused(bool v) {
    _scrollPaused = v;
  }

  Future<void> refreshAuto() async {
    if (_scrollPaused) return;
    final s = serverCtrl.current.value;
    if (s == null) return;

    if (serverCtrl.shouldSkipRefresh(s.id)) return;

    if (_autoInFlight && _autoServerId == s.id) return;
    _autoInFlight = true;
    _autoServerId = s.id;
    try {
      if (_ridServerId != s.id || items.isEmpty) {
        await refresh();
      } else {
        await refreshIncremental();
      }
    } finally {
      _autoInFlight = false;
    }
  }

  static Map<String, dynamic>? _asStringKeyMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  Future<void> refreshIncremental() async {
    if (isLoading.value || detailLoading.value) return;
    final s = serverCtrl.current.value;
    if (s == null || !s.isQbittorrent) {
      await refresh();
      return;
    }

    final String targetId = s.id;

    final int seq = _reqSeq;

    final Stopwatch sw = Stopwatch()..start();
    try {
      final Map<String, dynamic> md =
          await serverCtrl.qb.updateQbMaindata(rid: _rid);
      if (_reqSeq != seq || serverCtrl.current.value?.id != targetId) return;

      _rid = Formatter.getInt(md, 'rid', def: _rid);

      final Map<String, dynamic>? ss = _asStringKeyMap(md['server_state']);
      if (ss != null) serverCtrl.updateServerState(ss);
      final Map<String, dynamic>? delta = _asStringKeyMap(md['torrents']);
      if (delta != null) {
        final Map<String, Torrent> byHash = <String, Torrent>{
          for (final Torrent t in items) t.hash: t,
        };

        final List<String> incomplete = <String>[];
        delta.forEach((String hash, dynamic v) {
          try {
            final Map<String, dynamic> m =
                _asStringKeyMap(v) ?? <String, dynamic>{};
            final Torrent? prev = byHash[hash];
            if (prev != null) {
              byHash[hash] = prev.updateQbData(m);
              return;
            }

            final String? n = m['name']?.toString();
            if (n == null || n.isEmpty) {
              incomplete.add(hash);
              return;
            }
            byHash[hash] =
                Torrent.fromJson(<String, dynamic>{'hash': hash, ...m});
          } catch (e) {
            incomplete.add(hash);
            AppLog.instance
                .error('增量合并失败（$hash）：${NetError.describe(e)}');
          }
        });
        if (incomplete.isNotEmpty) {
          await refresh();
          return;
        }

        final dynamic rawRemoved = md['torrents_removed'];
        for (final dynamic h
            in rawRemoved is List ? rawRemoved : const <dynamic>[]) {
          byHash.remove(h.toString());
        }

        if (_reqSeq != seq) return;
        _setItems(byHash.values.toList());
        _syncCurrentFromItems();
        serverCtrl.cacheTorrents(s.id, items.toList());

        AppLog.instance.view(
          '种子列表[${s.name}] 增量已应用：${items.length} 条'
          ' ｜ 用时 ${ServerController.secs(sw.elapsed)}',
          key: '列表:${s.id}:delta',
          scope: s.logScope,
        );

        error.value = null;
      }

      serverCtrl.reportConnected(s.id);

      unawaited(serverCtrl.ensureVersion(s));
    } catch (e) {
      if (_reqSeq != seq || serverCtrl.current.value?.id != targetId) return;
      error.value = e.toString();
      serverCtrl.reportFailure(s.id, e);
    }
  }

  static List<Torrent> mergeQbMaindata(
    List<Torrent> base,
    Map<String, dynamic> md, {
    required bool full,
  }) {
    final Map<String, Torrent> byHash = <String, Torrent>{
      if (!full) for (final Torrent t in base) t.hash: t,
    };
    final Map<String, dynamic>? delta = _asStringKeyMap(md['torrents']);
    if (delta != null) {
      delta.forEach((String hash, dynamic v) {
        try {
          final Map<String, dynamic> m =
              _asStringKeyMap(v) ?? <String, dynamic>{};
          final Torrent? prev = byHash[hash];
          if (prev != null) {
            byHash[hash] = prev.updateQbData(m);
            return;
          }

          final String name = m['name']?.toString() ?? '';
          if (name.isEmpty) return;
          byHash[hash] =
              Torrent.fromJson(<String, dynamic>{'hash': hash, ...m});
        } catch (_) {
        }
      });
    }
    final dynamic rawRemoved = md['torrents_removed'];
    for (final dynamic h in rawRemoved is List ? rawRemoved : const <dynamic>[]) {
      byHash.remove(h.toString());
    }
    return byHash.values.toList();
  }

  static List<Torrent> fromTr(List<Map<String, dynamic>> list,
      {LogScope? scope}) {
    final List<Torrent> out = <Torrent>[];
    for (final Map<String, dynamic> m in list) {
      try {
        final int sending = Formatter.getInt(m, 'peersSendingToUs');
        final int getting = Formatter.getInt(m, 'peersGettingFromUs');
        out.add(Torrent(
          hash: m['hashString']?.toString() ?? '',
          name: m['name']?.toString() ?? '',
          size: Formatter.getInt(m, 'sizeWhenDone'),
          progress: Formatter.getDouble(m, 'percentDone'),
          state: _trState(m['status']),
          dlSpeed: Formatter.getInt(m, 'rateDownload'),
          upSpeed: Formatter.getInt(m, 'rateUpload'),
          numSeeds: sending,
          numLeechs: getting,
          numComplete:
              Formatter.sumSeederCount(m['trackerStats'], true) ?? 0,
          numIncomplete:
              Formatter.sumSeederCount(m['trackerStats'], false) ?? 0,
          activePeers: sending + getting,
          ratio: Formatter.getDouble(m, 'uploadRatio'),
          savePath: m['downloadDir']?.toString(),

          contentPath: _trContentPath(m),

          comment: m['comment']?.toString(),
          magnetUri: m['magnetLink']?.toString(),

          tags: _trLabels(m),
          uploaded: Formatter.getInt(m, 'uploadedEver'),
          downloaded: Formatter.getInt(m, 'downloadedEver'),
          addedOn: Formatter.getInt(m, 'addedDate'),
          lastActivity: Formatter.getInt(m, 'activityDate'),
          completionOn: Formatter.getInt(m, 'doneDate'),
          seedingTime: Formatter.getInt(m, 'secondsSeeding'),

          timeActive: Formatter.getInt(m, 'secondsDownloading') +
              Formatter.getInt(m, 'secondsSeeding'),
          eta: Formatter.getInt(m, 'eta', def: 8640000),
          trackerCount: (m['trackerStats'] as List<dynamic>?)?.length ?? 0,

          amountLeft: Formatter.getInt(m, 'leftUntilDone'),
          wasted: Formatter.getInt(m, 'corruptEver'),
          errorMessage: _trErrorString(m),
          metadataPercent:
              Formatter.getDouble(m, 'metadataPercentComplete', def: -1),
          freeSpace: Formatter.getInt(m, 'downloadDirFreeSpace', def: -1),
          isPrivate: m['isPrivate'] is bool ? m['isPrivate'] as bool : null,
          ratioLimit: _trRatioLimit(m),
          seedingTimeLimit: _trIdleLimit(m),

          rawState: m['status']?.toString() ?? '',

          priority: Formatter.getInt(m, 'queuePosition', def: 0),
          bandwidthPriority: Formatter.getInt(m, 'bandwidthPriority'),

          dlLimit: Formatter.getInt(m, 'downloadLimit') * 1024,
          upLimit: Formatter.getInt(m, 'uploadLimit') * 1024,
          dlLimited:
              m['downloadLimited'] is bool ? m['downloadLimited'] as bool : null,
          upLimited:
              m['uploadLimited'] is bool ? m['uploadLimited'] as bool : null,

          trId: m['id'] is num ? (m['id'] as num).toInt() : null,
        ));
      } catch (e) {
        AppLog.instance.error(
            'TR 种子解析失败（${m['hashString']}）：${NetError.describe(e)}',
            scope: scope);
      }
    }
    return out;
  }

  static String? _trContentPath(Map<String, dynamic> m) {
    final String dir = m['downloadDir']?.toString().trim() ?? '';
    final String name = m['name']?.toString().trim() ?? '';
    if (dir.isEmpty || name.isEmpty) return null;
    final String sep = (dir.endsWith('/') || dir.endsWith('\\')) ? '' : '/';
    return '$dir$sep$name';
  }

  static String? _trErrorString(Map<String, dynamic> m) {
    final String s = m['errorString']?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  static double _trRatioLimit(Map<String, dynamic> m) {
    final int mode = Formatter.getInt(m, 'seedRatioMode', def: 0);
    if (mode == 2) return -1;
    if (mode != 1) return -2;
    return Formatter.getDouble(m, 'seedRatioLimit', def: -2);
  }

  static int _trIdleLimit(Map<String, dynamic> m) {
    final int mode = Formatter.getInt(m, 'seedIdleMode', def: 0);
    if (mode == 2) return -1;
    if (mode != 1) return -2;
    return Formatter.getInt(m, 'seedIdleLimit', def: -2);
  }

  static String? _trLabels(Map<String, dynamic> m) {
    final dynamic labels = m['labels'];
    if (labels is List) {
      final String s = labels
          .map((dynamic e) => e?.toString().trim() ?? '')
          .where((String e) => e.isNotEmpty)
          .join(',');
      if (s.isNotEmpty) return s;
    } else if (labels is String && labels.trim().isNotEmpty) {
      return labels.trim();
    }
    final dynamic single = m['label'];
    if (single is String && single.trim().isNotEmpty) return single.trim();
    return null;
  }

  static String _trState(dynamic st) {
    switch (st) {
      case 0:
        return 'stopped';
      case 1:
      case 3:
        return 'queued';
      case 2:
        return 'checking';
      case 4:
        return 'downloading';
      case 5:
      case 6:
        return 'seeding';
      default:
        return 'unknown';
    }
  }

  int get totalDlSpeed {
    final ServerData? s = serverCtrl.current.value;
    if (s != null && s.isQbittorrent) {
      return serverCtrl.state.value.dlInfoSpeed;
    }
    return items.fold<int>(0, (int a, Torrent t) => a + t.dlSpeed);
  }

  int get totalUpSpeed {
    final ServerData? s = serverCtrl.current.value;
    if (s != null && s.isQbittorrent) {
      return serverCtrl.state.value.upInfoSpeed;
    }
    return items.fold<int>(0, (int a, Torrent t) => a + t.upSpeed);
  }

  void setFilter(TorrentFilter f) {
    if (filter.value == f) return;
    filter.value = f;

    subStates.clear();
    AppLog.instance.act('种子列表', '筛选[${f.label}]');
  }

  void toggleSubState(String v) {
    if (!subStates.remove(v)) subStates.add(v);
    AppLog.instance.act('种子列表', '细分筛选[${subStateLabel(v)}]');
  }

  void clearSubStates() => subStates.clear();

  List<String> subStateOptions() {
    final ServerData? s = serverCtrl.current.value;
    final bool isTr = s != null && !s.isQbittorrent;
    return (isTr ? SubStates.tr : SubStates.qb)[filter.value] ??
        const <String>[];
  }

  static String subStateLabel(String raw) => SubStates.labelOf(raw);

  bool get hasStatusFilter =>
      filter.value != TorrentFilter.all || subStates.isNotEmpty;

  String get statusSummaryText {
    if (filter.value == TorrentFilter.all) return '';
    final String base = filter.value.label;
    if (subStates.isEmpty) return base;
    final String first = subStateLabel(subStates.first);
    return subStates.length == 1 ? '$base · $first' : '$base · $first +${subStates.length - 1}';
  }

  void clearStatus() {
    filter.value = TorrentFilter.all;
    subStates.clear();
  }

  void setKeyword(String kw) => keyword.value = kw;

  void setSortKey(TorrentSortKey key) {
    sortKey.value = key;
    _saveSort();
    AppLog.instance.op('排序：${key.name} · ${sortDesc.value ? '降序' : '升序'}');
  }

  void setSortDesc(bool desc) {
    sortDesc.value = desc;
    _saveSort();
    AppLog.instance.op('排序方向：${desc ? '降序' : '升序'}');
  }

  static const String _kSortKey = 'sort.key';
  static const String _kSortDesc = 'sort.desc';

  void _saveSort() {
    Formatter.saveGlobalData(_kSortKey, sortKey.value.name);
    Formatter.saveGlobalData(_kSortDesc, sortDesc.value);
  }

  Future<void> _loadSort() async {
    final Object? k = await Formatter.getGlobalData(_kSortKey);
    if (k is String) {
      for (final TorrentSortKey item in TorrentSortKey.values) {
        if (item.name == k) sortKey.value = item;
      }
    }
    sortDesc.value = await Formatter.getGlobalBool(_kSortDesc, def: true);
  }

  final siteMasked = true.obs;

  static const String _kSiteMasked = 'set.siteMasked';

  void setSiteMasked(bool v) {
    siteMasked.value = v;
    Formatter.saveGlobalData(_kSiteMasked, v);
    AppLog.instance.op('站点打码：${v ? '开启' : '关闭'}');
  }

  Future<void> loadSiteMasked() async {
    siteMasked.value = await Formatter.getGlobalBool(_kSiteMasked, def: true);
  }

  void toggleSelect(String hash) {
    if (selected.contains(hash)) {
      selected.remove(hash);
    } else {
      selected.add(hash);
    }
  }

  void selectAll() {
    selected.assignAll(visibleItems.map((Torrent t) => t.hash));
  }

  void clearSelection() => selected.clear();

  List<int> get _selectedTrIds => items
      .where((Torrent t) => selected.contains(t.hash) && t.trId != null)
      .map((Torrent t) => t.trId!)
      .toList();

  String get _selectedHashes => selected.join('|');

  List<int> _trIdsOrThrow() {
    final List<int> ids = _selectedTrIds;
    if (ids.isEmpty) {
      throw StateError('选中的种子里没有可用的 Transmission 任务 ID'
          '（共选中 ${selected.length} 个，都没有 trId）');
    }
    return ids;
  }

  Future<void> _runOnSelected(
    Future<void> Function() action, {
    List<Torrent>? rollback,
  }) async {
    if (selected.isEmpty) return;
    lastActionOk.value = null;

    final String? serverIdAtStart = serverCtrl.current.value?.id;

    final LogScope? scopeAtStart = serverCtrl.current.value?.logScope;
    try {
      isLoading.value = true;
      await action();
      clearSelection();
      lastActionOk.value = true;
      if (rollback != null) {
        unawaited(_recheckAfterWrite());
      } else {
        await refresh();
      }
    } catch (e) {
      error.value = NetError.describe(e);
      lastActionOk.value = false;

      if (rollback != null) _rollbackOptimistic(rollback, serverIdAtStart);

      AppLog.instance.op(
        '操作失败：${_selectedNames()}'
        ' ｜ 服务器 ${serverCtrl.current.value?.name ?? '-'}'
        ' ｜ ${error.value}',
        level: 'ERROR',
        scope: scopeAtStart,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _rollbackOptimistic(List<Torrent> snapshot, String? serverIdAtStart) {
    if (serverCtrl.current.value?.id != serverIdAtStart) return;
    final Map<String, Torrent> before = <String, Torrent>{
      for (final Torrent t in snapshot) t.hash: t,
    };
    bool changed = false;
    final List<Torrent> next = <Torrent>[];
    for (final Torrent t in items) {
      final Torrent? old = before[t.hash];
      if (old != null && !identical(old, t)) {
        next.add(old);
        changed = true;
      } else {
        next.add(t);
      }
    }
    if (changed) _setItems(next);

    final Torrent? cur = current.value;
    if (cur != null) {
      final Torrent? oldCur = before[cur.hash];
      if (oldCur != null && !identical(oldCur, cur)) current.value = oldCur;
    }
  }

  Future<void> _recheckAfterWrite() async {
    final String? serverId = serverCtrl.current.value?.id;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (serverCtrl.current.value?.id != serverId) return;

    for (int i = 0; i < 6 && detailLoading.value; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (serverCtrl.current.value?.id != serverId) return;
    }
    try {
      await refreshIncremental();
    } catch (_) {
    }
  }

  void _applyOptimistic(Set<String> hashes, {required bool paused}) {
    if (hashes.isEmpty) return;
    final bool isQb = serverCtrl.current.value?.isQbittorrent ?? true;
    final List<Torrent> next = <Torrent>[];
    bool changed = false;
    for (final Torrent t in items) {
      if (!hashes.contains(t.hash) || t.isPause == paused) {
        next.add(t);
        continue;
      }
      changed = true;
      next.add(t.updateQbData(<String, dynamic>{
        'state': _optimisticState(t, paused: paused, isQb: isQb),

        if (paused) 'dlspeed': 0,
        'upspeed': 0,
      }));
    }
    if (!changed) return;
    _setItems(next);
    final Torrent? cur = current.value;
    if (cur == null || !hashes.contains(cur.hash)) return;
    for (final Torrent t in next) {
      if (t.hash == cur.hash) {
        current.value = t;
        break;
      }
    }
  }

  static String _optimisticState(
    Torrent t, {
    required bool paused,
    required bool isQb,
  }) {
    if (paused) {
      if (!isQb) return 'stopped';
      return t.isCompleted ? 'stoppedUP' : 'stoppedDL';
    }
    if (!isQb) return t.isCompleted ? 'seeding' : 'downloading';
    return t.isCompleted ? 'uploading' : 'downloading';
  }

  String _selectedNames([int limit = 3, int nameLen = 20]) {
    final List<String> names = items
        .where((Torrent t) => selected.contains(t.hash))
        .map((Torrent t) => t.name)
        .map((String n) =>
            n.length > nameLen ? '${n.substring(0, nameLen)}…' : n)
        .toList();
    if (names.isEmpty) return '';
    if (names.length <= limit) return names.join('、');
    return '${names.take(limit).join('、')} 等 ${names.length} 个';
  }

  Future<void> pauseSelected() {
    final List<Torrent> before = List<Torrent>.of(items);
    _applyOptimistic(Set<String>.of(selected), paused: true);
    return _runOnSelected(() async {
      final s = serverCtrl.current.value;
      if (s == null) return;

      final int n = selected.length;
      if (s.isQbittorrent) {
        await serverCtrl.qb.pauseTorrent(_selectedHashes);
      } else {
        await serverCtrl.tr.torrentStop(_trIdsOrThrow());
      }

      AppLog.instance.op('暂停 $n 个种子：${_selectedNames()}'
          '（服务器：${s.name} · ${s.isQbittorrent ? 'qB' : 'TR'}）',
          scope: s.logScope);
    }, rollback: before);
  }

  Future<void> resumeSelected() {
    final List<Torrent> before = List<Torrent>.of(items);
    _applyOptimistic(Set<String>.of(selected), paused: false);
    return _runOnSelected(() async {
      final s = serverCtrl.current.value;
      if (s == null) return;
      final int n = selected.length;
      if (s.isQbittorrent) {
        await serverCtrl.qb.resumeTorrent(_selectedHashes);
      } else {
        await serverCtrl.tr.torrentStart(_trIdsOrThrow());
      }
      AppLog.instance.op('恢复 $n 个种子：${_selectedNames()}'
          '（服务器：${s.name} · ${s.isQbittorrent ? 'qB' : 'TR'}）',
          scope: s.logScope);
    }, rollback: before);
  }

  Future<void> deleteSelected({
    bool deleteFiles = false,
    bool deleteSub = false,
    bool noSubDeleteFiles = false,
  }) =>
      _runOnSelected(() async {
        final s = serverCtrl.current.value;
        if (s == null) return;
        final List<Torrent> chosen =
            items.where((Torrent t) => selected.contains(t.hash)).toList();
        if (chosen.isEmpty) return;

        final DeletePlan plan = planDelete(
          all: items,
          chosen: chosen,
          deleteFiles: deleteFiles,
          deleteSub: deleteSub,
          noSubDeleteFiles: noSubDeleteFiles,
        );

        final List<DeleteBatch> batches =
            planBatches(chosen: chosen, plan: plan);

        if (s.isQbittorrent) {
          for (final DeleteBatch b in batches) {
            final String hashes = b.items.map((Torrent t) => t.hash).join('|');
            if (hashes.isEmpty) continue;
            await serverCtrl.qb
                .deleteTorrents(hashes, deleteFiles: b.deleteFiles);
          }
        } else {
          int skipped = 0;
          int deleted = 0;
          for (int i = 0; i < batches.length; i++) {
            final DeleteBatch b = batches[i];
            final Set<int> ids = <int>{};
            for (final Torrent t in b.items) {
              if (t.trId != null) {
                ids.add(t.trId!);
              } else {
                skipped++;
              }
            }

            if (ids.isEmpty) {
              if (i == 0) {
                throw StateError('没有可删除的 Transmission 任务 ID'
                    '（${b.items.length} 个种子都缺少 trId）');
              }
              continue;
            }
            await serverCtrl.tr
                .torrentRemove(ids.toList(), deleteLocal: b.deleteFiles);
            deleted += ids.length;
          }
          if (skipped > 0) {
            AppLog.instance.op('删除种子：有 $skipped 个缺少 Transmission '
                '任务 ID，已跳过（实际删除 $deleted 个）',
                scope: s.logScope);
          }
        }
        AppLog.instance.op('删除种子 ${chosen.length} 个'
            '${plan.subs.isEmpty ? '' : ' + 辅种 ${plan.subs.length} 个'}'
            '${plan.deleteFiles ? '（同时删除本地文件）' : '（仅移除任务）'}',
            scope: s.logScope);
      });

  static DeletePlan planDelete({
    required List<Torrent> all,
    required List<Torrent> chosen,
    bool deleteFiles = false,
    bool deleteSub = false,
    bool noSubDeleteFiles = false,
  }) {
    final Set<String> chosenHashes =
        chosen.map((Torrent t) => t.hash).toSet();

    final bool needSubs = deleteSub || noSubDeleteFiles;
    final List<Torrent> subsFound = <Torrent>[];
    if (needSubs) {
      final Set<String> keys = <String>{
        for (final Torrent m in chosen)
          if (m.size > 0 && _dirKey(m.savePath ?? '').isNotEmpty)
            '${m.size}\u0000${_dirKey(m.savePath ?? '')}',
      };
      for (final Torrent t in all) {
        if (chosenHashes.contains(t.hash)) continue;
        if (t.size <= 0) continue;
        final String dir = _dirKey(t.savePath ?? '');
        if (dir.isEmpty) continue;
        if (keys.contains('${t.size}\u0000$dir')) subsFound.add(t);
      }
    }
    return DeletePlan(

      deleteFiles: deleteFiles || (noSubDeleteFiles && subsFound.isEmpty),

      subs: deleteSub ? subsFound : const <Torrent>[],
    );
  }

  static List<DeleteBatch> planBatches({
    required List<Torrent> chosen,
    required DeletePlan plan,
  }) =>
      <DeleteBatch>[
        DeleteBatch(chosen, deleteFiles: plan.deleteFiles),
        if (plan.subs.isNotEmpty) DeleteBatch(plan.subs, deleteFiles: false),
      ];

  static bool isCrossSeed(Torrent a, Torrent b) {
    if (a.hash == b.hash) return false;

    if (a.size <= 0 || a.size != b.size) return false;
    return _sameSaveDir(a.savePath ?? '', b.savePath ?? '');
  }

  static final RegExp _trailingSlashes = RegExp(r'/+$');

  static String _dirKey(String s) =>
      s.trim().replaceAll('\\', '/').replaceAll(_trailingSlashes, '');

  static bool _sameSaveDir(String a, String b) {
    final String na = _dirKey(a);
    return na.isNotEmpty && na == _dirKey(b);
  }

  Future<void> recheckSelected() => _runOnSelected(() async {
        final s = serverCtrl.current.value;
        if (s == null) return;
        final int n = selected.length;
        if (s.isQbittorrent) {
          await serverCtrl.qb.recheckTorrents(_selectedHashes);
        } else {
          await serverCtrl.tr.torrentVerify(_trIdsOrThrow());
        }
        AppLog.instance.op('强制校验 $n 个种子', scope: s.logScope);
      });

  Future<void> queueMoveSelected(String where) => _runOnSelected(() async {
        final s = serverCtrl.current.value;
        if (s == null || !s.isTransmission) return;

        final List<int> ids = _trIdsOrThrow();
        switch (where) {
          case 'top':
            await serverCtrl.tr.queueMoveTop(ids);
            break;
          case 'up':
            await serverCtrl.tr.queueMoveUp(ids);
            break;
          case 'down':
            await serverCtrl.tr.queueMoveDown(ids);
            break;
          case 'bottom':
            await serverCtrl.tr.queueMoveBottom(ids);
            break;
        }
        AppLog.instance.op('队列移动 ${ids.length} 个种子 → $where',
            scope: s.logScope);
      });

  final Map<String, DateTime> _deepFetchedAt = <String, DateTime>{};

  static const Duration kDeepCacheTtl = Duration(seconds: 60);

  bool _needDeepProperties(String hash) {
    final DateTime? at = _deepFetchedAt[hash];
    if (at != null && DateTime.now().difference(at) < kDeepCacheTtl) {
      return false;
    }
    _deepFetchedAt[hash] = DateTime.now();
    return true;
  }

  final Map<String, _TrFsEntry> _trFreeSpaceCache = <String, _TrFsEntry>{};

  static const Duration kTrFreeSpaceTtl = Duration(seconds: 30);

  Future<int?> trFreeSpaceOf(String path) async {
    final String key = path.trim();
    if (key.isEmpty) return null;
    final _TrFsEntry? hit = _trFreeSpaceCache[key];
    if (hit != null && DateTime.now().difference(hit.at) < kTrFreeSpaceTtl) {
      return hit.bytes;
    }
    final int? bytes = await serverCtrl.tr.freeSpace(key);
    if (bytes == null) return hit?.bytes;
    _trFreeSpaceCache[key] = _TrFsEntry(bytes, DateTime.now());
    return bytes;
  }

  CapabilitySet get capabilities {
    final ServerData? s = serverCtrl.current.value;
    if (s == null) return const CapabilitySet();
    return ServerCapabilities.of(
      s,
      appVersion: serverCtrl.serverVersion[s.id],
      apiVersion: serverCtrl.serverApiVersion[s.id],
    );
  }

  final Map<String, Map<String, dynamic>> _drafts =
      <String, Map<String, dynamic>>{};

  dynamic draftOf(String hash, String field) => _drafts[hash]?[field];

  void setDraft(String hash, String field, dynamic value) {
    _drafts.putIfAbsent(hash, () => <String, dynamic>{})[field] = value;
  }

  void clearDraft(String hash) => _drafts.remove(hash);

  void clearDraftKey(String hash, String field) {
    final Map<String, dynamic>? m = _drafts[hash];
    if (m == null) return;
    m.remove(field);
    if (m.isEmpty) _drafts.remove(hash);
  }

  void clearAllDrafts() => _drafts.clear();

  bool hasDraft(String hash) => (_drafts[hash]?.isNotEmpty) ?? false;

  List<int> _trIdsOf(List<String> hashes) {
    final List<int> ids = <int>[];
    for (final Torrent t in items) {
      if (hashes.contains(t.hash) && t.trId != null) ids.add(t.trId!);
    }
    if (ids.isEmpty) {
      throw StateError(
          '所选 ${hashes.length} 个种子都没有可用的 Transmission 任务 ID');
    }
    return ids;
  }

  Future<void> _runEdit(
    List<String> hashes,
    Future<void> Function() action, {
    List<Torrent>? rollback,
  }) async {
    if (hashes.isEmpty) return;
    lastActionOk.value = null;
    final String? serverIdAtStart = serverCtrl.current.value?.id;
    final LogScope? scopeAtStart = serverCtrl.current.value?.logScope;
    try {
      isLoading.value = true;
      await action();
      lastActionOk.value = true;
      if (rollback != null) {
        unawaited(_recheckAfterWrite());
      } else {
        await refresh();
      }
    } catch (e) {
      error.value = NetError.describe(e);
      lastActionOk.value = false;
      if (rollback != null) _rollbackOptimistic(rollback, serverIdAtStart);
      AppLog.instance.op(
        '编辑失败（${hashes.length} 个种子）：${NetError.describe(e)}',
        level: 'ERROR',
        scope: scopeAtStart,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> setCategoryOf(List<String> hashes, String category) =>
      _runEdit(hashes, () async {
        final s = serverCtrl.current.value;
        if (s == null || !s.isQbittorrent) return;
        await serverCtrl.qb.setCategory(hashes.join('|'), category);
        AppLog.instance.op(
            '设置分类 → ${category.isEmpty ? '（空=未分类）' : category}'
            '（${hashes.length} 个种子）',
            scope: s.logScope);
      });

  Future<void> setTagsOf(
    List<String> hashes,
    List<String> tags, {
    bool append = false,
  }) =>
      _runEdit(hashes, () async {
        final s = serverCtrl.current.value;
        if (s == null) return;
        if (s.isQbittorrent) {
          final String api = serverCtrl.serverApiVersion[s.id] ?? '';
          if (append) {
            if (tags.isNotEmpty) {
              await serverCtrl.qb.addTags(hashes.join('|'), tags.join(','));
            }
          } else if (ServerCapabilities.qbCanSetTags(api)) {
            await serverCtrl.qb.setTags(hashes.join('|'), tags.join(','));
          } else {
            await _setTagsByDiff(hashes, tags);
          }
        } else {
          await serverCtrl.tr.setTags(_trIdsOf(hashes), tags);
        }
        AppLog.instance.op(
            '${append ? '追加' : '设置'}标签 → ${tags.isEmpty ? '（清空）' : tags.join(',')}'
            '（${hashes.length} 个种子）',
            scope: s.logScope);
      });

  Future<void> _setTagsByDiff(List<String> hashes, List<String> tags) async {
    final Set<String> want = tags.map((String e) => e.trim()).toSet()
      ..removeWhere((String e) => e.isEmpty);
    for (final String h in hashes) {
      final Set<String> cur = (_findInItems(h)?.tagList ?? const <String>[])
          .map((String e) => e.trim())
          .toSet();
      final Set<String> add = want.difference(cur);
      final Set<String> del = cur.difference(want);
      if (add.isNotEmpty) {
        await serverCtrl.qb.addTags(h, add.join(','));
      }
      if (del.isNotEmpty) {
        await serverCtrl.qb.removeTags(h, del.join(','));
      }
    }
  }

  Future<void> setLimitsOf(
    List<String> hashes, {
    int? dlKb,
    int? upKb,
  }) =>
      _runEdit(hashes, () async {
        final s = serverCtrl.current.value;
        if (s == null) return;
        if (s.isQbittorrent) {
          await serverCtrl.qb.setTorrentLimit(
            hashes.join('|'),
            downloadLimit: dlKb == null ? null : dlKb * 1024,
            uploadLimit: upKb == null ? null : upKb * 1024,
          );
        } else {
          await serverCtrl.tr.setTorrentLimit(
            _trIdsOf(hashes),
            downloadLimit: dlKb,
            uploadLimit: upKb,
          );
        }
        AppLog.instance.op(
            '设置限速 → 下载 ${dlKb ?? '-'} KB/s · 上传 ${upKb ?? '-'} KB/s'
            '（${hashes.length} 个种子）',
            scope: s.logScope);
      });

  Future<void> setLocationOf(
    List<String> hashes,
    String path, {
    bool move = true,
  }) =>
      _runEdit(hashes, () async {
        final s = serverCtrl.current.value;
        if (s == null) return;
        if (s.isQbittorrent) {
          await serverCtrl.qb.setLocation(hashes.join('|'), path);
        } else {
          await serverCtrl.tr.setLocation(_trIdsOf(hashes), path, move: move);
        }
        AppLog.instance.op(
            '修改保存路径 → $path（${move ? '同时移动文件' : '仅改指向'}'
            ' · ${hashes.length} 个种子）',
            scope: s.logScope);
      });

  Future<void> setForceStartOf(List<String> hashes, bool value) =>
      _runEdit(hashes, () async {
        final s = serverCtrl.current.value;
        if (s == null || !s.isQbittorrent) return;
        await serverCtrl.qb.setForceStart(hashes.join('|'), value);
        AppLog.instance.op(
            '${value ? '开启' : '关闭'}强制做种（${hashes.length} 个种子）',
            scope: s.logScope);
      });

  Future<void> toggleSequentialOf(
    List<String> hashes, {
    required bool target,
  }) =>
      _runEdit(hashes, () async {
        final s = serverCtrl.current.value;
        if (s == null || !s.isQbittorrent) return;
        if (!_toggleNeeded(
            hashes, (Torrent t) => t.sequentialDownload, target)) {
          return;
        }
        await serverCtrl.qb.toggleSequentialDownload(hashes.join('|'));
        AppLog.instance.op(
            '${target ? '开启' : '关闭'}顺序下载（${hashes.length} 个种子）',
            scope: s.logScope);
      });

  Future<void> toggleFirstLastPrioOf(
    List<String> hashes, {
    required bool target,
  }) =>
      _runEdit(hashes, () async {
        final s = serverCtrl.current.value;
        if (s == null || !s.isQbittorrent) return;
        if (!_toggleNeeded(
            hashes, (Torrent t) => t.firstLastPiecePrio, target)) {
          return;
        }
        await serverCtrl.qb.toggleFirstLastPiecePrio(hashes.join('|'));
        AppLog.instance.op(
            '${target ? '开启' : '关闭'}首尾块优先（${hashes.length} 个种子）',
            scope: s.logScope);
      });

  bool _toggleNeeded(
    List<String> hashes,
    bool? Function(Torrent t) read,
    bool target,
  ) {
    for (final Torrent t in items) {
      if (!hashes.contains(t.hash)) continue;
      final bool? v = read(t);
      if (v == null) continue;
      if (v != target) return true;
    }
    return false;
  }

  Future<void> setSuperSeedingOf(List<String> hashes, bool value) =>
      _runEdit(hashes, () async {
        final s = serverCtrl.current.value;
        if (s == null || !s.isQbittorrent) return;
        await serverCtrl.qb.setSuperSeeding(hashes.join('|'), value);
        AppLog.instance.op(
            '${value ? '开启' : '关闭'}超级做种（${hashes.length} 个种子）',
            scope: s.logScope);
      });

  Future<void> setShareLimitsOf(
    List<String> hashes, {
    double? ratioLimit,
    int? seedingTimeMin,
  }) =>
      _runEdit(hashes, () async {
        final s = serverCtrl.current.value;
        if (s == null) return;
        if (s.isQbittorrent) {
          await serverCtrl.qb.setShareLimits(
            hashes.join('|'),
            ratioLimit: ratioLimit,
            seedingTimeLimit: seedingTimeMin,
          );
        } else {
          final List<int> ids = _trIdsOf(hashes);
          if (ratioLimit != null) {
            await serverCtrl.tr.setShareLimits(
              ids,
              seedRatioLimit: ratioLimit < 0 ? 0 : ratioLimit,

              seedRatioMode: ratioLimit < -1.5 ? 0 : (ratioLimit < 0 ? 2 : 1),
            );
          }
          if (seedingTimeMin != null) {
            await serverCtrl.tr.setIdleLimit(
              ids,
              seedIdleLimit: seedingTimeMin < 0 ? 0 : seedingTimeMin,
              seedIdleMode: seedingTimeMin < -1 ? 0 : (seedingTimeMin < 0 ? 2 : 1),
            );
          }
        }
        AppLog.instance.op(
            '设置分享限制 → 分享率 ${ratioLimit ?? '-'} · 做种时限 '
            '${seedingTimeMin ?? '-'} 分钟（${hashes.length} 个种子）',
            scope: s.logScope);
      });

  Future<void> setQueuePositionOf(List<String> hashes, int position) =>
      _runEdit(hashes, () async {
        final s = serverCtrl.current.value;
        if (s == null || !s.isTransmission) return;
        await serverCtrl.tr.setQueuePosition(_trIdsOf(hashes), position);
        AppLog.instance.op(
            '设置队列位置 → $position（${hashes.length} 个种子）',
            scope: s.logScope);
      });

  Future<void> setBandwidthPriorityOf(List<String> hashes, int priority) =>
      _runEdit(hashes, () async {
        final s = serverCtrl.current.value;
        if (s == null || !s.isTransmission) return;
        await serverCtrl.tr.setBandwidthPriority(_trIdsOf(hashes), priority);
        AppLog.instance.op(
            '设置带宽优先级 → $priority（${hashes.length} 个种子）',
            scope: s.logScope);
      });

  Future<void> renameTorrent(Torrent t, String name) =>
      _runEdit(<String>[t.hash], () async {
        final s = serverCtrl.current.value;
        if (s == null) return;
        if (s.isQbittorrent) {
          await serverCtrl.qb.setName(t.hash, name);
        } else {
          if (t.trId == null) {
            throw StateError('该种子缺少 Transmission 任务 ID，无法重命名');
          }
          await serverCtrl.tr.setName(t.trId!, name);
        }
        AppLog.instance.op('重命名种子 → $name', scope: s.logScope);
      });

  void openDetail(Torrent t) {
    current.value = t;
    files.clear();
    peers.clear();
    trackers.clear();

    dlSamples.clear();
    ulSamples.clear();
    detailSyncedAt.value = null;
    error.value = null;
    detailLoading.value = true;

    unawaited(loadDetailData());
  }

  int _detailSeq = 0;

  bool _detailStale(String serverId, String hash, int seq) {
    if (seq != _detailSeq) return true;
    if (serverCtrl.current.value?.id != serverId) return true;
    return current.value?.hash != hash;
  }

  Torrent? _findInItems(String hash) {
    for (final Torrent t in items) {
      if (t.hash == hash) return t;
    }
    return null;
  }

  void _syncCurrentFromItems() {
    final Torrent? cur = current.value;
    if (cur == null) return;
    final Torrent? fresh = _findInItems(cur.hash);
    if (fresh != null && !identical(fresh, cur)) current.value = fresh;
  }

  void _pushSample(Torrent t) {
    dlSamples.add(t.dlSpeed.toDouble());
    ulSamples.add(t.upSpeed.toDouble());
    if (dlSamples.length > kSampleCap) {
      dlSamples.removeRange(0, dlSamples.length - kSampleCap);
    }
    if (ulSamples.length > kSampleCap) {
      ulSamples.removeRange(0, ulSamples.length - kSampleCap);
    }
    detailSyncedAt.value = DateTime.now();
  }

  Future<void> ensureEditFields(Torrent t) async {
    if (!_needDeepProperties('edit:${t.hash}')) return;
    try {
      final Torrent? fresh = await fetchOne(t);
      if (fresh == null) return;
      final int i = items.indexWhere((Torrent e) => e.hash == t.hash);
      if (i < 0) return;
      items[i] = fresh;
      items.refresh();
    } catch (_) {

    }
  }

  Future<Torrent?> fetchOne(Torrent t, {bool deep = false}) async {
    final ServerData? s = serverCtrl.current.value;
    if (s == null) return null;
    if (s.isQbittorrent) {
      final List<Torrent> got =
          await serverCtrl.qb.updateSelect(<String>[t.hash]);
      if (got.isEmpty) return null;

      final Torrent fresh = got.first.copyWithTrId(t.trId);
      return deep ? await _mergeQbProperties(fresh) : fresh;
    }
    if (t.trId == null) return null;
    final List<Map<String, dynamic>> raw =
        await serverCtrl.tr.torrentGet(ids: <int>[t.trId!]);
    final List<Torrent> got =
        fromTr(raw, scope: serverCtrl.current.value?.logScope);
    return got.isEmpty ? null : got.first;
  }

  Future<Torrent> _mergeQbProperties(Torrent t) async {
    try {
      final Map<String, dynamic> p =
          await serverCtrl.qb.getProperties(t.hash);
      if (p.isEmpty) return t;
      final int wasted = Formatter.getInt(p, 'total_wasted', def: t.wasted);
      if (wasted == t.wasted) return t;
      return t.updateQbData(<String, dynamic>{'total_wasted': wasted});
    } catch (_) {
      return t;
    }
  }

  Future<void> loadDetailData() async {
    final s = serverCtrl.current.value;
    final Torrent? t = current.value;
    if (s == null || t == null) {
      detailLoading.value = false;
      return;
    }
    final String targetId = s.id;
    final String targetHash = t.hash;
    final int seq = ++_detailSeq;

    final Stopwatch sw = Stopwatch()..start();
    try {
      detailLoading.value = true;

      List<Map<String, dynamic>> f = const <Map<String, dynamic>>[];
      List<Map<String, dynamic>> p = const <Map<String, dynamic>>[];
      List<Map<String, dynamic>> tk = const <Map<String, dynamic>>[];
      if (s.isQbittorrent) {
        f = await serverCtrl.qb.getTorrentFiles(targetHash);
        p = await serverCtrl.qb.getTorrentPeers(targetHash);
        tk = await serverCtrl.qb.getTrackers(targetHash);
      } else {
        final List<int> ids = <int>[if (t.trId != null) t.trId!];
        f = await serverCtrl.tr.torrentFiles(ids);
        p = await serverCtrl.tr.torrentPeers(ids);
        tk = await serverCtrl.tr.torrentTrackers(ids);
      }
      if (_detailStale(targetId, targetHash, seq)) return;
      files.value = f;
      peers.value = p;
      trackers.value = tk;

      Torrent? fresh;
      try {

        fresh = await fetchOne(t, deep: _needDeepProperties(targetHash));
      } catch (e) {
        AppLog.instance.error('详情定点刷新失败：${NetError.describe(e)}',
            scope: serverCtrl.current.value?.logScope);
      }
      if (_detailStale(targetId, targetHash, seq)) return;
      fresh ??= _findInItems(targetHash);

      if (fresh != null &&
          !s.isQbittorrent &&
          capabilities.freeSpaceMethod &&
          (fresh.savePath ?? '').isNotEmpty) {
        final int? fs = await trFreeSpaceOf(fresh.savePath!);
        if (fs != null && fs > 0) {

          fresh = fresh.updateQbData(<String, dynamic>{'free_space': fs});
        }
      }
      if (_detailStale(targetId, targetHash, seq)) return;
      if (fresh != null) {
        current.value = fresh;
        _pushSample(fresh);
      }
      AppLog.instance.view(
        '种子详情[${t.name}] 已刷新：文件 ${f.length} · 用户 ${p.length} · Tracker ${tk.length}'
        '${fresh == null ? '（未取到新状态，沿用列表快照）' : ''}'
        ' ｜ 用时 ${ServerController.secs(sw.elapsed)}',
        key: '详情:$targetHash:refresh',
        scope: serverCtrl.current.value?.logScope,
      );
    } catch (e) {
      if (_detailStale(targetId, targetHash, seq)) return;
      error.value = e.toString();
    } finally {
      if (seq == _detailSeq) detailLoading.value = false;
    }
  }

  List<FileNode> get fileTree => buildFileTree(files);
}

class FileNode {
  FileNode(this.name, this.path);

  final String name;
  final String path;
  final List<FileNode> children = <FileNode>[];
  int size = 0;
  double progress = 0;

  bool get isFile => children.isEmpty;
}

List<FileNode> buildFileTree(List<Map<String, dynamic>> rawFiles) {
  final FileNode root = FileNode('', '');
  for (final Map<String, dynamic> f in rawFiles) {
    final String full = (f['name'] ?? '').toString();
    if (full.isEmpty) continue;
    final List<String> parts = full.split('/');
    FileNode cur = root;
    for (int i = 0; i < parts.length; i++) {
      final String seg = parts[i];
      final String p = parts.take(i + 1).join('/');
      FileNode? next;
      for (final FileNode c in cur.children) {
        if (c.name == seg) {
          next = c;
          break;
        }
      }
      if (next == null) {
        next = FileNode(seg, p);
        cur.children.add(next);
      }
      cur = next;
    }

    cur.size = Formatter.getInt(f, 'size', def: cur.size);
    cur.progress = Formatter.getDouble(f, 'progress', def: cur.progress);
  }
  return root.children;
}

class _TrFsEntry {
  const _TrFsEntry(this.bytes, this.at);

  final int bytes;
  final DateTime at;
}
