import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

import '../dio/log_interceptor.dart';
import '../dio/redirect_interceptor.dart';
import '../models/server_data.dart';
import '../../utils/app_log.dart';
import '../../utils/formatter.dart';
import '../../utils/net_error.dart';

class TrLoginResult {
  const TrLoginResult.ok()
      : ok = true,
        reason = null,
        missingCreds = false,
        routeChanged = false;

  const TrLoginResult.fail(this.reason)
      : ok = false,
        missingCreds = false,
        routeChanged = false;

  const TrLoginResult.noCreds(this.reason)
      : ok = false,
        missingCreds = true,
        routeChanged = false;

  const TrLoginResult.routeSwitch(this.reason)
      : ok = false,
        missingCreds = false,
        routeChanged = true;

  final bool ok;

  final String? reason;

  final bool missingCreds;

  final bool routeChanged;

  @override
  String toString() => ok
      ? 'TrLoginResult(ok)'
      : 'TrLoginResult(fail: $reason'
          '${missingCreds ? ' [no creds]' : ''}'
          '${routeChanged ? ' [route changed]' : ''})';
}

class TrMethod {
  final Dio _dio;
  String? _sessionId;

  String? _authHeader;

  static String? _authOf(ServerData s) {
    final String u = s.username?.trim() ?? '';
    if (u.isEmpty) return null;
    return Formatter.getAuthentication(u, s.password ?? '');
  }

  ServerData? _server;

  int _routeGen = 0;

  int get routeGen => _routeGen;

  TrMethod({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(

          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),

          followRedirects: false,
          validateStatus: (int? s) => s != null && s < 500,
        )) {
    _dio.interceptors.add(CookieManager(CookieJar()));
    _dio.interceptors.add(RedirectInterceptor());

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) {
        final ServerData? cur = _server;
        if (cur != null) {
          o.extra[kLogServerIdKey] = cur.id;
          o.extra[kLogServerNameKey] = cur.name;
        }
        h.next(o);
      },
    ));

    _dio.interceptors.add(AppLogInterceptor());
  }

  void setServer(ServerData s) {
    if (_server?.id != s.id) _sessionId = null;

    final bool routeChanged = _dio.options.baseUrl != s.baseUrl;
    _server = s;
    _authHeader = _authOf(s);
    _dio.options.baseUrl = s.baseUrl;
    if (routeChanged) _routeGen++;
  }

  Future<TrLoginResult> updateTrServerCookie(ServerData s, {int? routeGen}) async {
    if (routeGen == null || routeGen == _routeGen) setServer(s);
    try {
      await _rpc('session-get', <String, dynamic>{},
          baseUrl: s.baseUrl, authHeader: _authOf(s));
      AppLog.instance.net(
          'TR 登录成功（已带 Basic 鉴权=${_authOf(s) != null}）',
          scope: s.logScope);
      return const TrLoginResult.ok();
    } catch (e) {
      _sessionId = null;

      String why = NetError.describe(e);

      bool noCreds = false;
      if (e is DioException && _authOf(s) == null) {
        final int? code = e.response?.statusCode;
        if (code == 401 || code == 403) {
          why = '服务端要求账号密码，但本机未填写账号（HTTP $code）';

          noCreds = true;
        }
      }
      AppLog.instance.net('TR 登录失败：$why', scope: s.logScope);
      return noCreds ? TrLoginResult.noCreds(why) : TrLoginResult.fail(why);
    }
  }

  void invalidateSession() => _sessionId = null;

  Future<TrLoginResult> checkTrServerCookie(
      [ServerData? s, bool retriedRoute = false]) async {
    final ServerData? target = s ?? _server;
    if (target == null) {
      return const TrLoginResult.fail('未选择服务器');
    }
    setServer(target);

    final int gen = _routeGen;
    try {
      await _rpc('session-get', <String, dynamic>{});
      return const TrLoginResult.ok();
    } catch (_) {
      if (gen != _routeGen) {
        if (retriedRoute) {
          return const TrLoginResult.routeSwitch('服务器地址已切换，已放弃本次重登');
        }
        final ServerData? now = _server;
        if (now == null) {
          return const TrLoginResult.fail('未选择服务器');
        }
        AppLog.instance.net('探测期间路由已切换'
            '（${target.baseUrl} → ${now.baseUrl}），改用新路由重新建立会话',
            scope: target.logScope);
        return checkTrServerCookie(now, true);
      }
      _sessionId = null;
      return updateTrServerCookie(target, routeGen: gen);
    }
  }

  Future<Map<String, dynamic>> updateTrInfo() => _rpc('session-stats', <String, dynamic>{});

  Future<String> getVersion() async {
    final Map<String, dynamic> res =
        await _rpc('session-get', <String, dynamic>{});
    return Formatter.getString(res, 'version');
  }

  Future<Map<String, dynamic>> _rpc(
    String method,
    Map<String, dynamic> arguments, {
    String? baseUrl,
    int depth = 0,
    String? authHeader,
  }) async {
    final String? auth = authHeader ?? _authHeader;
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
      if (_sessionId != null) 'X-Transmission-Session-Id': _sessionId!,
      if (auth != null) 'Authorization': auth,
    };
    final String targetBase = baseUrl ?? _dio.options.baseUrl;
    final Response<dynamic> resp = await _dio.post(
      baseUrl == null ? '/transmission/rpc' : '$baseUrl/transmission/rpc',
      options: Options(headers: headers),
      data: jsonEncode(<String, dynamic>{
        'method': method,
        'arguments': arguments,
      }),
    );

    final int? code = resp.statusCode;
    if (code != null && code >= 300 && code < 400) {
      final String? loc = resp.headers.value('location');
      final Uri? from = Uri.tryParse(targetBase);
      final Uri? to = (loc == null || from == null) ? null : from.resolve(loc);
      if (to == null) {
        throw Exception('Transmission: 重定向缺少 Location（HTTP $code）');
      }
      if (to.host != from!.host) {
        throw Exception('Transmission: 拒绝跨主机重定向 '
            '${from.host} → ${to.host}（避免泄露会话 id）');
      }
      if (depth >= 3) {
        throw Exception('Transmission: 重定向次数过多');
      }

      final String nextBase =
          '${to.scheme}://${to.host}${to.hasPort ? ':${to.port}' : ''}';
      return _rpc(method, arguments,
          baseUrl: nextBase, depth: depth + 1, authHeader: authHeader);
    }
    if (resp.statusCode == 409) {
      final String? sid = resp.headers.value('X-Transmission-Session-Id');
      if (sid != null) {
        if (depth >= 2) {
          throw Exception(
              'Transmission: 会话握手失败（连续 ${depth + 1} 次 409）');
        }

        AppLog.instance.net('TR 握手：收到 409，更新 session id（depth=$depth）',
            scope: _server?.logScope);
        _sessionId = sid;
        return _rpc(method, arguments,
            baseUrl: baseUrl, depth: depth + 1, authHeader: authHeader);
      }
      throw Exception('Transmission: missing session id');
    }

    final int sc = resp.statusCode ?? 0;
    if (sc == 401 || sc == 403) {
      final bool hadAuth = auth != null;
      final String why = hadAuth
          ? 'Transmission 登录失败：账号或密码错误（HTTP $sc）'
          : 'Transmission 登录失败：服务端要求账号密码，但本机未填写账号（HTTP $sc）';

      AppLog.instance.net('TR 收到 $sc：已带 Basic 鉴权=$hadAuth',
          scope: _server?.logScope);
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        type: DioExceptionType.badResponse,
        error: why,
      );
    }

    final dynamic raw = resp.data;
    if (raw is! Map) {
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        type: DioExceptionType.badResponse,
        error: 'Transmission RPC $method 返回非 JSON（HTTP ${resp.statusCode}）',
      );
    }
    final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
    if (data['result'] != 'success') {
      throw Exception('Transmission RPC error: ${data['result']}');
    }
    return Map<String, dynamic>.from(
      data['arguments'] as Map? ?? <String, dynamic>{},
    );
  }

  Future<void> _torrentSet(List<int> ids, Map<String, dynamic> fields) =>
      _rpc('torrent-set', <String, dynamic>{'ids': ids, ...fields});

  Future<void> _sessionSet(Map<String, dynamic> fields) =>
      _rpc('session-set', fields);

  Future<Map<String, dynamic>> sessionGet({String? baseUrl}) =>
      _rpc('session-get', <String, dynamic>{}, baseUrl: baseUrl);

  Future<void> sessionSet(Map<String, dynamic> fields) => _sessionSet(fields);

  Future<void> blocklistUpdate() =>
      _rpc('blocklist-update', <String, dynamic>{});

  Future<int?> freeSpace(String path) async {
    if (path.trim().isEmpty) return null;
    try {
      final Map<String, dynamic> res = await _rpc(
        'free-space',
        <String, dynamic>{'path': path},
      );
      final num? n = res['size-bytes'] as num?;
      return n?.toInt();
    } catch (_) {
      return null;
    }
  }

  static const List<String> _trFields = <String>[
    'id',
    'hashString',
    'name',
    'sizeWhenDone',
    'percentDone',
    'status',
    'rateDownload',
    'rateUpload',
    'peersSendingToUs',
    'peersGettingFromUs',
    'uploadRatio',
    'downloadDir',
    'queuePosition',
    'labels',
    'uploadedEver',
    'downloadedEver',
    'addedDate',
    'activityDate',
    'doneDate',
    'secondsSeeding',
    'secondsDownloading',
    'eta',
    'comment',
    'magnetLink',

    'downloadLimit',
    'downloadLimited',
    'uploadLimit',
    'uploadLimited',

    'honorsSessionLimits',
    'bandwidthPriority',
    'isPrivate',
    'leftUntilDone',
    'corruptEver',
    'errorString',
    'metadataPercentComplete',
    'downloadDirFreeSpace',
    'seedRatioMode',
    'seedRatioLimit',
    'seedIdleMode',
    'seedIdleLimit',
  ];

  static const List<String> _trFieldsFull = <String>[
    ..._trFields,
    'trackerStats',
  ];

  Future<List<Map<String, dynamic>>> torrentGet({
    List<int>? ids,
    bool lite = false,
  }) async {
    final Map<String, dynamic> args = <String, dynamic>{
      'fields': lite ? _trFields : _trFieldsFull,
      if (ids != null && ids.isNotEmpty) 'ids': ids,
    };
    final Map<String, dynamic> res = await _rpc('torrent-get', args);
    final List<dynamic> list = (res['torrents'] as List?) ?? <dynamic>[];
    return list.map((dynamic e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> updateSelect(List<int> ids) =>
      torrentGet(ids: ids);

  Future<List<Map<String, dynamic>>> updateTrMaindata() => torrentGet();

  Future<void> addTorrents({
    String? filename,
    String? metainfo,
    String? downloadDir,
    bool paused = false,
    List<String>? labels,
  }) async {
    final Map<String, dynamic> args = <String, dynamic>{
      if (filename != null) 'filename': filename,
      if (metainfo != null) 'metainfo': metainfo,
      if (downloadDir != null) 'download-dir': downloadDir,
      if (paused) 'paused': true,

      if (labels != null && labels.isNotEmpty) 'labels': labels,
    };
    await _rpc('torrent-add', args);
  }

  Future<void> torrentStop(List<int> ids) async {
    await _rpc('torrent-stop', <String, dynamic>{'ids': ids});
  }

  Future<void> pauseTorrent(List<int> ids) => torrentStop(ids);

  Future<void> torrentStart(List<int> ids) async {
    await _rpc('torrent-start', <String, dynamic>{'ids': ids});
  }

  Future<void> resumeTorrent(List<int> ids) => torrentStart(ids);

  Future<void> torrentRemove(List<int> ids, {bool deleteLocal = false}) async {
    await _rpc('torrent-remove', <String, dynamic>{
      'ids': ids,
      'delete-local-data': deleteLocal,
    });
  }

  Future<void> deleteTorrent(List<int> ids, {bool deleteLocal = false}) =>
      torrentRemove(ids, deleteLocal: deleteLocal);

  Future<void> torrentVerify(List<int> ids) async {
    await _rpc('torrent-verify', <String, dynamic>{'ids': ids});
  }

  Future<void> recheckTorrent(List<int> ids) => torrentVerify(ids);

  Future<void> reannounceTorrent(List<int> ids) async {
    await _rpc('torrent-reannounce', <String, dynamic>{'ids': ids});
  }

  Future<void> setName(int id, String name) async {
    await _rpc('torrent-rename-path', <String, dynamic>{
      'ids': <int>[id],
      'path': name,
      'name': name,
    });
  }

  Future<void> queueMoveTop(List<int> ids) async {
    await _rpc('queue-move-top', <String, dynamic>{'ids': ids});
  }

  Future<void> queueMoveUp(List<int> ids) async {
    await _rpc('queue-move-up', <String, dynamic>{'ids': ids});
  }

  Future<void> queueMoveDown(List<int> ids) async {
    await _rpc('queue-move-down', <String, dynamic>{'ids': ids});
  }

  Future<void> queueMoveBottom(List<int> ids) async {
    await _rpc('queue-move-bottom', <String, dynamic>{'ids': ids});
  }

  List<Map<String, dynamic>> _flatten(List<dynamic> torrents, String key) =>
      torrents
          .map((dynamic t) => Map<String, dynamic>.from(t))
          .expand((Map<String, dynamic> t) =>
              ((t[key] as List?) ?? <dynamic>[])
                  .map((dynamic e) => Map<String, dynamic>.from(e)))
          .toList();

  Future<List<Map<String, dynamic>>> torrentFiles(List<int> ids) async {
    final Map<String, dynamic> res = await _rpc('torrent-get', <String, dynamic>{
      'ids': ids,
      'fields': <String>['id', 'name', 'files', 'fileStats'],
    });
    final List<dynamic> list = (res['torrents'] as List?) ?? <dynamic>[];
    if (list.isEmpty) return <Map<String, dynamic>>[];
    return _flatten(list, 'files');
  }

  Future<List<Map<String, dynamic>>> torrentPeers(List<int> ids) async {
    final Map<String, dynamic> res = await _rpc('torrent-get', <String, dynamic>{
      'ids': ids,
      'fields': <String>['id', 'peers'],
    });
    final List<dynamic> list = (res['torrents'] as List?) ?? <dynamic>[];
    if (list.isEmpty) return <Map<String, dynamic>>[];
    return _flatten(list, 'peers');
  }

  Future<List<Map<String, dynamic>>> torrentTrackers(List<int> ids) async {
    final Map<String, dynamic> res = await _rpc('torrent-get', <String, dynamic>{
      'ids': ids,
      'fields': <String>['id', 'trackerStats'],
    });
    final List<dynamic> list = (res['torrents'] as List?) ?? <dynamic>[];
    if (list.isEmpty) return <Map<String, dynamic>>[];
    return _flatten(list, 'trackerStats');
  }

  Future<Map<String, List<Map<String, dynamic>>>> getPeersAndFiles(
    List<int> ids,
  ) async {
    final Map<String, dynamic> res = await _rpc('torrent-get', <String, dynamic>{
      'ids': ids,
      'fields': <String>['id', 'name', 'files', 'fileStats', 'peers', 'trackerStats'],
    });
    final List<dynamic> list = (res['torrents'] as List?) ?? <dynamic>[];
    if (list.isEmpty) {
      return <String, List<Map<String, dynamic>>>{
        'files': <Map<String, dynamic>>[],
        'peers': <Map<String, dynamic>>[],
        'trackers': <Map<String, dynamic>>[],
      };
    }
    return <String, List<Map<String, dynamic>>>{
      'files': _flatten(list, 'files'),
      'peers': _flatten(list, 'peers'),
      'trackers': _flatten(list, 'trackerStats'),
    };
  }

  Future<void> addTracker(List<int> ids, String tracker) =>
      addTrackers(ids, <String>[tracker]);

  Future<void> addTrackers(List<int> ids, List<String> trackers) =>
      _torrentSet(ids, <String, dynamic>{'trackerAdd': trackers});

  Future<void> removeTracker(List<int> ids, List<int> trackerIds) =>
      _torrentSet(ids, <String, dynamic>{'trackerRemove': trackerIds});

  Future<void> editTracker(List<int> ids, int trackerId, String newTracker) =>
      _torrentSet(ids, <String, dynamic>{
        'trackerReplace': <dynamic>[trackerId, newTracker],
      });

  Future<List<String>> trackerList(int id) async {
    final Map<String, dynamic> res = await _rpc('torrent-get', <String, dynamic>{
      'ids': <int>[id],
      'fields': <String>['trackerList'],
    });
    final List<dynamic> list = (res['torrents'] as List?) ?? <dynamic>[];
    if (list.isEmpty) return <String>[];
    final dynamic tl = (list.first as Map<String, dynamic>)['trackerList'];
    return (tl as List<dynamic>?)?.map((dynamic e) => e.toString()).toList() ??
        <String>[];
  }

  Future<void> setTrackerList(int id, List<String> urls) => _torrentSet(
        <int>[id],
        <String, dynamic>{'trackerList': urls},
      );

  Future<void> addTrackersByList(int id, List<String> trackers) async {
    final List<String> cur = await trackerList(id);
    cur.addAll(trackers);
    await setTrackerList(id, cur);
  }

  Future<void> removeTrackerByIndex(int id, int index) async {
    final List<String> cur = await trackerList(id);
    if (index < 0 || index >= cur.length) return;
    cur.removeAt(index);
    await setTrackerList(id, cur);
  }

  Future<void> editTrackerByIndex(int id, int index, String newUrl) async {
    final List<String> cur = await trackerList(id);
    if (index < 0 || index >= cur.length) return;
    cur[index] = newUrl;
    await setTrackerList(id, cur);
  }

  Future<void> setTags(List<int> ids, List<String> labels) =>
      _torrentSet(ids, <String, dynamic>{'labels': labels});

  Future<void> setShareLimits(
    List<int> ids, {
    double? seedRatioLimit,
    int? seedRatioMode,
  }) =>
      _torrentSet(ids, <String, dynamic>{
        if (seedRatioLimit != null) 'seedRatioLimit': seedRatioLimit,
        if (seedRatioMode != null) 'seedRatioMode': seedRatioMode,
      });

  Future<void> setServerRatio(List<int> ids, double ratio) =>
      setShareLimits(ids, seedRatioLimit: ratio, seedRatioMode: 1);

  Future<void> setIdleLimit(
    List<int> ids, {
    int? seedIdleLimit,
    int? seedIdleMode,
  }) =>
      _torrentSet(ids, <String, dynamic>{
        if (seedIdleLimit != null) 'seedIdleLimit': seedIdleLimit,
        if (seedIdleMode != null) 'seedIdleMode': seedIdleMode,
      });

  Future<void> setTorrentLimit(
    List<int> ids, {
    int? downloadLimit,
    int? uploadLimit,
  }) =>
      _torrentSet(ids, <String, dynamic>{
        if (downloadLimit != null) 'downloadLimit': downloadLimit,
        if (downloadLimit != null)
          'downloadLimited': downloadLimit > 0,
        if (uploadLimit != null) 'uploadLimit': uploadLimit,
        if (uploadLimit != null) 'uploadLimited': uploadLimit > 0,
      });

  Future<void> setServerLimit({int? downloadLimit, int? uploadLimit}) =>
      _sessionSet(<String, dynamic>{
        if (downloadLimit != null) 'speed-limit-down': downloadLimit,
        if (downloadLimit != null) 'speed-limit-down-enabled': downloadLimit > 0,
        if (uploadLimit != null) 'speed-limit-up': uploadLimit,
        if (uploadLimit != null) 'speed-limit-up-enabled': uploadLimit > 0,
      });

  Future<void> setServerAltLimit({int? downloadLimit, int? uploadLimit}) =>
      _sessionSet(<String, dynamic>{
        if (downloadLimit != null) 'alt-speed-down': downloadLimit,
        if (uploadLimit != null) 'alt-speed-up': uploadLimit,
      });

  Future<void> toggleSpeedLimitsMode({bool? enabled}) =>
      _sessionSet(<String, dynamic>{
        'alt-speed-enabled': enabled ?? true,
      });

  Future<void> setLocation(List<int> ids, String location, {bool move = true}) async {
    await _rpc('torrent-set-location', <String, dynamic>{
      'ids': ids,
      'location': location,
      'move': move,
    });
  }

  Future<void> setSavePath(String path) =>
      _sessionSet(<String, dynamic>{'download-dir': path});

  Future<void> setTempPath(String path) =>
      _sessionSet(<String, dynamic>{'incomplete-dir': path});

  Future<void> setTempPathEnabled(bool enabled) =>
      _sessionSet(<String, dynamic>{'incomplete-dir-enabled': enabled});

  Future<void> setHonorsSessionLimits(List<int> ids, bool value) =>
      _torrentSet(ids, <String, dynamic>{'honorsSessionLimits': value});

  Future<void> setQueuePosition(List<int> ids, int position) =>
      _torrentSet(ids, <String, dynamic>{'queuePosition': position});

  Future<void> setBandwidthPriority(List<int> ids, int priority) =>
      _torrentSet(ids, <String, dynamic>{'bandwidthPriority': priority});

  Future<void> setIncompleteFilesExt(bool enabled) =>
      _sessionSet(<String, dynamic>{'rename-partial-files': enabled});

  Future<void> setMaxConnec({int? maxConnec, int? maxConnecPerTorrent}) =>
      _sessionSet(<String, dynamic>{
        if (maxConnec != null) 'peer-limit-global': maxConnec,
        if (maxConnecPerTorrent != null)
          'peer-limit-per-torrent': maxConnecPerTorrent,
      });

  Future<void> setServerQueueing({
    int? downloadQueueSize,
    int? seedQueueSize,
    bool? downloadQueueEnabled,
    bool? seedQueueEnabled,
  }) =>
      _sessionSet(<String, dynamic>{
        if (downloadQueueSize != null) 'download-queue-size': downloadQueueSize,
        if (seedQueueSize != null) 'seed-queue-size': seedQueueSize,
        if (downloadQueueEnabled != null)
          'download-queue-enabled': downloadQueueEnabled,
        if (seedQueueEnabled != null) 'seed-queue-enabled': seedQueueEnabled,
      });

  Future<void> filePrio(List<int> ids, List<int> fileIndexes, int priority) {
    final String key = switch (priority) {
      1 => 'priority-high',
      -1 => 'priority-low',
      _ => 'priority-normal',
    };
    return _torrentSet(ids, <String, dynamic>{key: fileIndexes});
  }

  Future<void> setFilesWanted(
    List<int> ids,
    List<int> fileIndexes, {
    required bool wanted,
  }) =>
      _torrentSet(ids, <String, dynamic>{
        if (wanted) 'files-wanted': fileIndexes,
        if (!wanted) 'files-unwanted': fileIndexes,
      });
}
