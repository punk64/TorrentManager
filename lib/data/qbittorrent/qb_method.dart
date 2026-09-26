import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

import '../dio/log_interceptor.dart';
import '../dio/redirect_interceptor.dart';
import '../../utils/app_log.dart';
import '../../utils/net_error.dart';
import '../models/qb_ip_filter.dart';
import '../models/qb_log.dart';
import '../models/server_data.dart';
import '../models/torrent.dart';

class QbMethod {
  final Dio _dio;

  ServerData? _server;

  final Map<String, String> probedVersion = <String, String>{};

  final Map<String, String> probedApiVersion = <String, String>{};

  int _routeGen = 0;

  int get routeGen => _routeGen;

  final CookieJar _jar = CookieJar();

  QbMethod({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(

          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),

          followRedirects: false,
          validateStatus: (int? s) => s != null && s < 500,
        )) {
    _dio.interceptors.add(CookieManager(_jar));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) {
        final String base = o.baseUrl;
        if (base.isNotEmpty && o.method.toUpperCase() != 'GET') {
          o.headers['Referer'] = base;
          o.headers['Origin'] =
              base.endsWith('/') ? base.substring(0, base.length - 1) : base;
        }

        final ServerData? cur = _server;
        if (cur != null) {
          o.extra[kLogServerIdKey] = cur.id;
          o.extra[kLogServerNameKey] = cur.name;
        }
        h.next(o);
      },
    ));

    _dio.interceptors.add(RedirectInterceptor(dio: _dio));

    _dio.interceptors.add(AppLogInterceptor());
  }

  bool _apiV5 = false;

  String? _apiProbeServerId;

  Future<void>? _apiProbeInFlight;

  static int qbMajorOf(String version) {
    final String v = version.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final int dot = v.indexOf('.');
    return int.tryParse(dot < 0 ? v : v.substring(0, dot)) ?? 0;
  }

  static bool isApiV5Version(String version) => qbMajorOf(version) >= 5;

  static const Duration _kProbeConnect = Duration(milliseconds: 600);
  static const Duration _kProbeReceive = Duration(milliseconds: 2500);

  Options get _probeOptions => Options(
        connectTimeout: _kProbeConnect,
        receiveTimeout: _kProbeReceive,
      );

  Future<void> ensureApiStyle() async {
    final ServerData? s = _server;
    if (s == null || !s.isQbittorrent) return;
    if (_apiProbeServerId == s.id) return;
    final Future<void>? flying = _apiProbeInFlight;
    if (flying != null) return flying;
    final Future<void> f = _probeApiStyle(s);
    _apiProbeInFlight = f;
    try {
      await f;
    } finally {
      if (identical(_apiProbeInFlight, f)) _apiProbeInFlight = null;
    }
  }

  Future<void> _probeApiStyle(ServerData s) async {
    try {
      final Response<dynamic> r = await _dio.get(
        '/api/v2/app/version',
        options: _probeOptions,
      );

      final String raw = (r.data?.toString() ?? '').trim();
      if (r.statusCode == 200 && raw.isNotEmpty) {
        _apiV5 = isApiV5Version(raw);
        _apiProbeServerId = s.id;

        final String api = await _probeText('/api/v2/app/webapiVersion');
        if (api.trim().isNotEmpty) probedApiVersion[s.id] = api.trim();
      }
    } catch (_) {
    }
  }

  void _ensureWriteOk(Response<dynamic> resp) {
    final int code = resp.statusCode ?? 0;
    if (code < 400) return;
    throw DioException(
      requestOptions: resp.requestOptions,
      response: resp,
      type: DioExceptionType.badResponse,
      error: '服务端拒绝了这次操作（HTTP $code）',
    );
  }

  Future<Response<dynamic>> _postOk(
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
  }) async {
    final Response<dynamic> resp =
        await _postWrite(path, params: queryParameters, data: data);
    _ensureWriteOk(resp);
    return resp;
  }

  bool _paramInBody = true;

  Future<Response<dynamic>> _postWrite(
    String path, {
    Map<String, dynamic>? params,
    Object? data,
  }) async {
    if (data != null) {
      return _dio.post<dynamic>(path, data: data, queryParameters: params);
    }
    if (params == null || params.isEmpty) {
      AppLog.instance.net('写请求 POST ${_shortPath(path)}（无参数）',
          scope: _server?.logScope);
      return _dio.post<dynamic>(path);
    }

    final String brief = '${_paramsBrief(params)} ｜ Referer ${_dio.options.baseUrl}';
    final bool firstAsBody = _paramInBody;
    AppLog.instance.net(
      '写请求 POST ${_shortPath(path)} ｜ 参数=${firstAsBody ? 'form body' : 'query string'}'
      ' ｜ $brief',
      scope: _server?.logScope,
    );
    final Response<dynamic> r1 = firstAsBody
        ? await _postForm(path, params)
        : await _dio.post<dynamic>(path, queryParameters: params);

    if (r1.statusCode != 400) return r1;
    final bool retryAsBody = !firstAsBody;
    AppLog.instance.net(
      '写请求参数位置回退：${_shortPath(path)} 不接受'
      '${firstAsBody ? 'form body' : 'query string'}（400）'
      ' → 改用${retryAsBody ? 'form body' : 'query string'}重试',
      scope: _server?.logScope,
    );
    final Response<dynamic> r2 = retryAsBody
        ? await _postForm(path, params)
        : await _dio.post<dynamic>(path, queryParameters: params);
    if (r2.statusCode != 400) {
      _paramInBody = retryAsBody;
      AppLog.instance.net(
        '写请求参数位置自适应：此后本服务器按'
        '${_paramInBody ? 'form body' : 'query string'}发送写参数',
        scope: _server?.logScope,
      );
    }
    return r2;
  }

  Future<Response<dynamic>> _postForm(
    String path,
    Map<String, dynamic> params,
  ) =>
      _dio.post<dynamic>(
        path,
        data: params,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

  static String _paramsBrief(Map<String, dynamic> p) {
    final List<String> parts = <String>[];
    p.forEach((String k, dynamic v) {
      final String key = k.toLowerCase();
      if (key.contains('pass') ||
          key.contains('sid') ||
          key.contains('token')) {
        parts.add('$k=***');
        return;
      }
      final String s = v?.toString() ?? '';
      if (key == 'hashes') {
        final List<String> items =
            s.split('|').where((String e) => e.trim().isNotEmpty).toList();
        parts.add('hashes=${items.length}项'
            '${items.isEmpty ? '' : '（首 ${_head(items.first)}）'}');
        return;
      }
      parts.add('$k=${s.length <= 24 ? s : '${s.substring(0, 24)}…'}');
    });
    return parts.join(' ｜ ');
  }

  static String _head(String s, [int n = 6]) =>
      s.length <= n ? s : s.substring(0, n);

  static String _shortPath(String path) => path.replaceFirst('/api/v2/', '');

  void setServer(ServerData s) {
    if (_server?.id != s.id) {
      unawaited(_jar.deleteAll());

      _paramInBody = true;
    }
    _server = s;

    final bool routeChanged = _dio.options.baseUrl != s.baseUrl;
    _dio.options.baseUrl = s.baseUrl;
    if (routeChanged) _routeGen++;
  }

  static Map<String, dynamic> _asMap(Response<dynamic> resp, String endpoint) {
    final dynamic d = resp.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    throw _notJson(resp, endpoint);
  }

  static List<dynamic> _asList(Response<dynamic> resp, String endpoint) {
    final dynamic d = resp.data;
    if (d is List) return d;
    throw _notJson(resp, endpoint);
  }

  static DioException _notJson(Response<dynamic> resp, String endpoint) {
    final String body = (resp.data?.toString() ?? '').trim();
    final String brief = body.length > 40 ? '${body.substring(0, 40)}…' : body;
    return DioException(
      requestOptions: resp.requestOptions,
      response: resp,
      type: DioExceptionType.badResponse,
      error: '$endpoint 返回非 JSON（HTTP ${resp.statusCode}）：'
          '${brief.isEmpty ? '空响应' : brief} —— 多半是未登录或账号密码错误',
    );
  }

  static String ensureProtocol(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return 'http://$url';
  }

  String? lastLoginError;

  Object? lastLoginErrorRaw;

  ConnErrorKind? lastLoginKind;

  bool lastLoginBanned = false;

  bool lastLoginMissingCreds = false;

  void _resetLoginResult() {
    lastLoginError = null;
    lastLoginErrorRaw = null;
    lastLoginKind = null;
    lastLoginBanned = false;
    lastLoginMissingCreds = false;
  }

  static bool _missingCreds(ServerData s) =>
      (s.username ?? '').trim().isEmpty || (s.password ?? '').isEmpty;

  static bool _isBannedBody(String body) =>
      body.toLowerCase().contains('banned');

  Future<bool> updateQbServerCookie(ServerData s, {int? routeGen}) async {
    _resetLoginResult();

    if (_missingCreds(s)) {
      lastLoginMissingCreds = true;
      lastLoginError = '账号或密码为空，已跳过登录以避免触发服务端封禁';
      AppLog.instance.net('qBittorrent 登录已跳过：账号或密码为空（${s.name}）',
          scope: s.logScope);
      return false;
    }
    if (routeGen == null || routeGen == _routeGen) setServer(s);

    final Response<dynamic> resp = await _dio.post<dynamic>(
      '${s.baseUrl}/api/v2/auth/login',
      data: FormData.fromMap(<String, String>{
        'username': s.username ?? '',
        'password': s.password ?? '',
      }),
    );

    final String body = (resp.data?.toString() ?? '').trim();

    if (_isBannedBody(body)) {
      lastLoginBanned = true;
      lastLoginError = 'IP 已被服务器封禁';
      AppLog.instance.net(
          'qBittorrent 已封禁本机 IP（HTTP ${resp.statusCode}）：${body.isEmpty ? '空响应' : body}',
          scope: s.logScope);
      return false;
    }

    final bool ok = resp.statusCode == 200 && (body == 'Ok.' || body.isEmpty);
    if (!ok) {
      lastLoginError = '服务器拒绝了登录（HTTP ${resp.statusCode}）';
      AppLog.instance.net(
          'qBittorrent 登录失败（HTTP ${resp.statusCode}）：${body.isEmpty ? '空响应' : body}',
          scope: s.logScope);
    }
    return ok;
  }

  Future<bool> checkQbServerCookie([ServerData? s, bool retriedRoute = false]) async {
    final ServerData? target = s ?? _server;
    if (target == null) return false;
    _resetLoginResult();
    setServer(target);

    final int gen = _routeGen;
    try {
      final Response<dynamic> resp = await _dio.get(
        '/api/v2/app/version',
        options: _probeOptions,
      );
      if (resp.statusCode == 200 && resp.data is String) {
        final String v = (resp.data as String).trim();
        if (v.isNotEmpty) probedVersion[target.id] = v;
        return true;
      }

      if (_isBannedBody(resp.data?.toString() ?? '')) {
        lastLoginBanned = true;
        lastLoginError = 'IP 已被服务器封禁';
        AppLog.instance.net('qBittorrent 已封禁本机 IP（探测接口返回 403）',
            scope: target.logScope);
        return false;
      }
    } catch (e) {

      lastLoginErrorRaw = e;
      lastLoginKind = NetError.classify(e);
      lastLoginError = NetError.describe(e);
      AppLog.instance.net(
        'qBittorrent 探测失败（${lastLoginKind?.name ?? 'unknown'}）：$lastLoginError',
        scope: target.logScope,
      );
    }

    if (gen != _routeGen) {
      if (retriedRoute) return false;
      final ServerData? now = _server;
      if (now == null) return false;
      AppLog.instance.net(
          '探测期间路由已切换（${target.baseUrl} → ${now.baseUrl}），改用新路由重新建立会话',
          scope: target.logScope);
      return checkQbServerCookie(now, true);
    }
    return updateQbServerCookie(target, routeGen: gen);
  }

  Future<Map<String, String>> updateQbInfo() async {
    final Future<String> versionF = _dio
        .get<String>('/api/v2/app/version', options: _probeOptions)
        .then((Response<String> r) => r.data ?? '');
    final Future<String> apiF = _probeText('/api/v2/app/webapiVersion');

    final String version = await versionF;
    final String apiVersion = await apiF;
    return <String, String>{'version': version, 'webapiVersion': apiVersion};
  }

  Future<String> _probeText(String path) async {
    try {
      final Response<String> r =
          await _dio.get<String>(path, options: _probeOptions);
      return r.data ?? '';
    } catch (_) {
      return '';
    }
  }

  static const int kParseInIsolateBytes = 512 * 1024;

  Future<Map<String, dynamic>> getTransferInfo() async {
    final Response<dynamic> resp = await _dio.get('/api/v2/transfer/info');
    return _asMap(resp, '/api/v2/transfer/info');
  }

  Future<List<Torrent>> getTorrentList({
    String? filter,
    String? category,
    int? limit,
    int? offset,
  }) async {
    final Response<dynamic> resp = await _dio.get(
      '/api/v2/torrents/info',
      queryParameters: <String, dynamic>{
        if (filter != null) 'filter': filter,
        if (category != null) 'category': category,
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      },
      options: Options(responseType: ResponseType.plain),
    );
    final dynamic data = resp.data;

    if (data is! String) {
      final List<dynamic> list = _asList(resp, '/api/v2/torrents/info');
      return list
          .map((dynamic e) => Torrent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data.length < kParseInIsolateBytes) {
      return _decodeTorrentList(data);
    }
    return Isolate.run<List<Torrent>>(() => _decodeTorrentList(data));
  }

  static List<Torrent> _decodeTorrentList(String raw) {
    if (raw.isEmpty) return <Torrent>[];
    final dynamic d = jsonDecode(raw);
    if (d is! List) return <Torrent>[];
    return <Torrent>[
      for (final dynamic e in d)
        if (e is Map<String, dynamic>) Torrent.fromJson(e),
    ];
  }

  Future<Map<String, dynamic>> getMaindata({int rid = 0}) async {
    final Response<dynamic> resp = await _dio.get(
      '/api/v2/sync/maindata',
      queryParameters: <String, dynamic>{'rid': rid},
    );
    return _asMap(resp, '/api/v2/sync/maindata');
  }

  Future<Map<String, dynamic>> updateQbMaindata({int rid = 0}) =>
      getMaindata(rid: rid);

  Future<Map<String, dynamic>> getProperties(String hash) async {
    final Response<dynamic> resp = await _dio.get(
      '/api/v2/torrents/properties',
      queryParameters: <String, dynamic>{'hash': hash},
    );
    return _asMap(resp, '/api/v2/torrents/properties');
  }

  Future<void> addTorrents({
    String? urls,
    String? filePath,
    String? savepath,
    String? category,
    List<String>? tags,
    int? dlLimit,
    int? upLimit,
    double? ratioLimit,
    int? seedingTimeLimit,
    bool paused = false,
  }) async {
    final Map<String, dynamic> fields = <String, dynamic>{
      if (urls != null) 'urls': urls,
      if (savepath != null) 'savepath': savepath,
      if (category != null) 'category': category,
      if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
      if (dlLimit != null && dlLimit > 0) 'dlLimit': '$dlLimit',
      if (upLimit != null && upLimit > 0) 'upLimit': '$upLimit',
      if (ratioLimit != null && ratioLimit > 0) 'ratioLimit': '$ratioLimit',
      if (seedingTimeLimit != null && seedingTimeLimit > 0)
        'seedingTimeLimit': '$seedingTimeLimit',
    };

    if (paused) {
      await ensureApiStyle();
      fields[_apiV5 ? 'stopped' : 'paused'] = 'true';
    }
    if (filePath != null) {
      fields['torrents'] = await MultipartFile.fromFile(filePath);
    }
    await _postOk(
      '/api/v2/torrents/add',
      data: FormData.fromMap(fields),
    );
  }

  Future<void> _pauseOrResume(String hashes, {required bool pause}) async {
    await ensureApiStyle();
    final String modern =
        pause ? '/api/v2/torrents/stop' : '/api/v2/torrents/start';
    final String legacy =
        pause ? '/api/v2/torrents/pause' : '/api/v2/torrents/resume';
    final String first = _apiV5 ? modern : legacy;
    final String second = _apiV5 ? legacy : modern;
    String used = first;

    final Map<String, dynamic> p = <String, dynamic>{'hashes': hashes};
    final Response<dynamic> r1 = await _postWrite(first, params: p);
    Response<dynamic> r = r1;
    if (r1.statusCode == 404 || r1.statusCode == 405) {
      r = await _postWrite(second, params: p);
      used = second;
      if (r.statusCode != 404 && r.statusCode != 405) {
        _apiV5 = !_apiV5;
        _apiProbeServerId = _server?.id;

        AppLog.instance.net(
          '暂停端点自适应：${_endpointName(first)} 不可用（${r1.statusCode}）'
          ' → 改用 ${_endpointName(second)}，此后按 qB v${_apiV5 ? '5' : '4'} 风格',
          scope: _server?.logScope,
        );
      }
    }
    _ensureWriteOk(r);

    AppLog.instance.net(
      '${pause ? '暂停' : '继续'}种子：${_endpointName(used)}'
      '（qB v${_apiV5 ? '5' : '4'} 风格）',
      scope: _server?.logScope,
    );
  }

  static String _endpointName(String path) =>
      path.replaceFirst('/api/v2/torrents/', '');

  Future<void> pauseTorrent(String hashes) =>
      _pauseOrResume(hashes, pause: true);

  Future<void> resumeTorrent(String hashes) =>
      _pauseOrResume(hashes, pause: false);

  Future<void> deleteTorrents(String hashes, {bool deleteFiles = false}) async {
    await _postOk(
      '/api/v2/torrents/delete',
      queryParameters: <String, dynamic>{
        'hashes': hashes,
        'deleteFiles': deleteFiles,
      },
    );
  }

  Future<void> deleteTorrent(String hashes, {bool deleteFiles = false}) =>
      deleteTorrents(hashes, deleteFiles: deleteFiles);

  Future<void> recheckTorrents(String hashes) async {
    await _postOk(
      '/api/v2/torrents/recheck',
      queryParameters: <String, dynamic>{'hashes': hashes},
    );
  }

  Future<void> recheckTorrent(String hashes) => recheckTorrents(hashes);

  Future<void> reannounceTorrent(String hashes) async {
    await _postOk(
      '/api/v2/torrents/reannounce',
      queryParameters: <String, dynamic>{'hashes': hashes},
    );
  }

  Future<void> setName(String hash, String name) async {
    await _postOk(
      '/api/v2/torrents/rename',
      queryParameters: <String, dynamic>{'hash': hash, 'name': name},
    );
  }

  Future<void> topPrio(String hashes) async {
    await _postOk(
      '/api/v2/torrents/topPrio',
      queryParameters: <String, dynamic>{'hashes': hashes},
    );
  }

  Future<void> bottomPrio(String hashes) async {
    await _postOk(
      '/api/v2/torrents/bottomPrio',
      queryParameters: <String, dynamic>{'hashes': hashes},
    );
  }

  Future<void> increasePrio(String hashes) async {
    await _postOk(
      '/api/v2/torrents/increasePrio',
      queryParameters: <String, dynamic>{'hashes': hashes},
    );
  }

  Future<void> decreasePrio(String hashes) async {
    await _postOk(
      '/api/v2/torrents/decreasePrio',
      queryParameters: <String, dynamic>{'hashes': hashes},
    );
  }

  Future<void> filePrio(String hash, String id, int priority) async {
    await _postOk(
      '/api/v2/torrents/filePrio',
      queryParameters: <String, dynamic>{
        'hash': hash,
        'id': id,
        'priority': priority,
      },
    );
  }

  Future<void> addTags(String hashes, String tags) async {
    await _postOk(
      '/api/v2/torrents/addTags',
      queryParameters: <String, dynamic>{'hashes': hashes, 'tags': tags},
    );
  }

  Future<void> removeTags(String hashes, String tags) async {
    await _postOk(
      '/api/v2/torrents/removeTags',
      queryParameters: <String, dynamic>{'hashes': hashes, 'tags': tags},
    );
  }

  Future<void> setTags(String hashes, String tags) async {
    await _postOk(
      '/api/v2/torrents/setTags',
      queryParameters: <String, dynamic>{'hashes': hashes, 'tags': tags},
    );
  }

  Future<void> createTags(String tags) async {
    await _postOk(
      '/api/v2/torrents/createTags',
      queryParameters: <String, dynamic>{'tags': tags},
    );
  }

  Future<void> deleteTags(String tags) async {
    await _postOk(
      '/api/v2/torrents/deleteTags',
      queryParameters: <String, dynamic>{'tags': tags},
    );
  }

  Future<List<String>> getTags() async {
    final Response<dynamic> resp = await _dio.get('/api/v2/torrents/tags');
    return _asList(resp, '/api/v2/torrents/tags').cast<String>();
  }

  Future<void> createCategory(String category, {String? savePath}) async {
    await _postOk(
      '/api/v2/torrents/createCategory',
      queryParameters: <String, dynamic>{
        'category': category,
        if (savePath != null) 'savePath': savePath,
      },
    );
  }

  Future<void> editCategory(String category, {String? savePath}) async {
    await _postOk(
      '/api/v2/torrents/editCategory',
      queryParameters: <String, dynamic>{
        'category': category,
        if (savePath != null) 'savePath': savePath,
      },
    );
  }

  Future<void> removeCategories(String categories) async {
    await _postOk(
      '/api/v2/torrents/removeCategories',
      queryParameters: <String, dynamic>{'categories': categories},
    );
  }

  Future<Map<String, dynamic>> getCategories() async {
    final Response<dynamic> resp = await _dio.get('/api/v2/torrents/categories');
    return _asMap(resp, '/api/v2/torrents/categories');
  }

  Future<void> setCategory(String hashes, String category) async {
    await _postOk(
      '/api/v2/torrents/setCategory',
      queryParameters: <String, dynamic>{
        'hashes': hashes,
        'category': category,
      },
    );
  }

  Future<void> setShareLimits(
    String hashes, {
    double? ratioLimit,
    int? seedingTimeLimit,
  }) async {
    await _postOk(
      '/api/v2/torrents/setShareLimits',
      queryParameters: <String, dynamic>{
        'hashes': hashes,
        'ratioLimit': ratioLimit ?? -1,
        'seedingTimeLimit': seedingTimeLimit ?? -1,
      },
    );
  }

  Future<void> setTorrentLimit(
    String hashes, {
    int? downloadLimit,
    int? uploadLimit,
  }) async {
    if (downloadLimit != null) {
      await _postOk(
        '/api/v2/torrents/setDownloadLimit',
        queryParameters: <String, dynamic>{
          'hashes': hashes,
          'limit': downloadLimit,
        },
      );
    }
    if (uploadLimit != null) {
      await _postOk(
        '/api/v2/torrents/setUploadLimit',
        queryParameters: <String, dynamic>{
          'hashes': hashes,
          'limit': uploadLimit,
        },
      );
    }
  }

  Future<void> setServerRatio(String hashes, double ratioLimit) =>
      setShareLimits(hashes, ratioLimit: ratioLimit);

  Future<void> toggleSpeedLimitsMode() async {
    await _postOk('/api/v2/transfer/toggleSpeedLimitsMode');
  }

  Future<void> setServerLimit({
    int? downloadLimit,
    int? uploadLimit,
  }) async {
    if (downloadLimit != null) {
      await _postOk(
        '/api/v2/transfer/setDownloadLimit',
        queryParameters: <String, dynamic>{'limit': downloadLimit},
      );
    }
    if (uploadLimit != null) {
      await _postOk(
        '/api/v2/transfer/setUploadLimit',
        queryParameters: <String, dynamic>{'limit': uploadLimit},
      );
    }
  }

  Future<void> setServerAltLimit({
    int? downloadLimit,
    int? uploadLimit,
  }) async {
    await _setAppPreferences(<String, dynamic>{
      if (downloadLimit != null) 'alt_dl_limit': downloadLimit,
      if (uploadLimit != null) 'alt_up_limit': uploadLimit,
    });
  }

  Future<void> setLocation(String hashes, String location) async {
    await _postOk(
      '/api/v2/torrents/setLocation',
      queryParameters: <String, dynamic>{
        'hashes': hashes,
        'location': location,
      },
    );
  }

  Future<void> setSavePath(String path) =>
      _setAppPreferences(<String, dynamic>{'save_path': path});

  Future<void> setTempPath(String path) =>
      _setAppPreferences(<String, dynamic>{'temp_path': path});

  Future<void> setTempPathEnabled(bool enabled) =>
      _setAppPreferences(<String, dynamic>{'temp_path_enabled': enabled});

  Future<void> setForceStart(String hashes, bool value) async {
    await _postOk(
      '/api/v2/torrents/setForceStart',
      queryParameters: <String, dynamic>{
        'hashes': hashes,
        'value': value,
      },
    );
  }

  Future<void> setSuperSeeding(String hashes, bool value) async {
    await _postOk(
      '/api/v2/torrents/setSuperSeeding',
      queryParameters: <String, dynamic>{
        'hashes': hashes,
        'value': value,
      },
    );
  }

  Future<void> setAutoManagement(String hashes, bool enable) async {
    await _postOk(
      '/api/v2/torrents/setAutoManagement',
      queryParameters: <String, dynamic>{
        'hashes': hashes,
        'enable': enable,
      },
    );
  }

  Future<void> setAutoTmmEnabled(bool enabled) =>
      _setAppPreferences(<String, dynamic>{'auto_tmm_enabled': enabled});

  Future<void> toggleSequentialDownload(String hashes) async {
    await _postOk(
      '/api/v2/torrents/toggleSequentialDownload',
      queryParameters: <String, dynamic>{'hashes': hashes},
    );
  }

  Future<void> toggleFirstLastPiecePrio(String hashes) async {
    await _postOk(
      '/api/v2/torrents/toggleFirstLastPiecePrio',
      queryParameters: <String, dynamic>{'hashes': hashes},
    );
  }

  Future<void> setPreallocateAll(bool enabled) =>
      _setAppPreferences(<String, dynamic>{'preallocate_all': enabled});

  Future<void> setIncompleteFilesExt(bool enabled) =>
      _setAppPreferences(<String, dynamic>{'incomplete_files_ext': enabled});

  Future<void> setMaxConnec({
    int? maxConnec,
    int? maxConnecPerTorrent,
    int? maxUploads,
    int? maxUploadsPerTorrent,
  }) =>
      _setAppPreferences(<String, dynamic>{
        if (maxConnec != null) 'max_connec': maxConnec,
        if (maxConnecPerTorrent != null)
          'max_connec_per_torrent': maxConnecPerTorrent,
        if (maxUploads != null) 'max_uploads': maxUploads,
        if (maxUploadsPerTorrent != null)
          'max_uploads_per_torrent': maxUploadsPerTorrent,
      });

  Future<void> setServerSeedingLimit({
    double? maxRatio,
    int? maxSeedingTime,
    int? maxInactiveSeedingTime,
    bool? enabled,
  }) =>
      _setAppPreferences(<String, dynamic>{
        if (maxRatio != null) 'max_ratio': maxRatio,
        if (maxSeedingTime != null) 'max_seeding_time': maxSeedingTime,
        if (maxInactiveSeedingTime != null)
          'max_inactive_seeding_time': maxInactiveSeedingTime,
        if (enabled != null) 'max_ratio_enabled': enabled,
      });

  Future<void> setServerQueueing({
    bool? queueing,
    int? maxActiveDownloads,
    int? maxActiveUploads,
    int? maxActiveTorrents,
    int? maxSeedingTime,
  }) =>
      _setAppPreferences(<String, dynamic>{
        if (queueing != null) 'queueing_enabled': queueing,
        if (maxActiveDownloads != null)
          'max_active_downloads': maxActiveDownloads,
        if (maxActiveUploads != null) 'max_active_uploads': maxActiveUploads,
        if (maxActiveTorrents != null)
          'max_active_torrents': maxActiveTorrents,
        if (maxSeedingTime != null) 'max_seeding_time': maxSeedingTime,
      });

  Future<void> addTracker(String hash, String urls) async {
    await _postOk(
      '/api/v2/torrents/addTrackers',
      queryParameters: <String, dynamic>{'hash': hash, 'urls': urls},
    );
  }

  Future<void> removeTracker(String hash, String urls) async {
    await _postOk(
      '/api/v2/torrents/removeTrackers',
      queryParameters: <String, dynamic>{'hash': hash, 'urls': urls},
    );
  }

  Future<void> editTracker(String hash, String origUrl, String newUrl) async {
    await _postOk(
      '/api/v2/torrents/editTrackers',
      queryParameters: <String, dynamic>{
        'hash': hash,
        'origUrl': origUrl,
        'newUrl': newUrl,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getTrackers(String hash) async {
    final Response<dynamic> resp = await _dio.get(
      '/api/v2/torrents/trackers',
      queryParameters: <String, dynamic>{'hash': hash},
    );
    final List<dynamic> list = _asList(resp, '/api/v2/torrents/trackers');
    return list.map((dynamic e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getTorrentFiles(String hash) async {
    final Response<dynamic> resp = await _dio.get(
      '/api/v2/torrents/files',
      queryParameters: <String, dynamic>{'hash': hash},
    );
    final List<dynamic> list = _asList(resp, '/api/v2/torrents/files');
    return list.map((dynamic e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getTorrentPeers(String hash) async {
    final Response<dynamic> resp = await _dio.get(
      '/api/v2/sync/torrentPeers',
      queryParameters: <String, dynamic>{'hash': hash},
    );
    final Map<String, dynamic> data =
        _asMap(resp, '/api/v2/sync/torrentPeers');

    final dynamic rawPeers = data['peers'];
    final Map<String, dynamic> peers = rawPeers is Map
        ? Map<String, dynamic>.from(rawPeers)
        : <String, dynamic>{};
    return peers.values
        .map((dynamic e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> banPeers(String peers) async {
    await _postOk(
      '/api/v2/transfer/banPeers',
      queryParameters: <String, dynamic>{'peers': peers},
    );
  }

  /// 分块状态：0=未下载 1=下载中 2=已完成（部分版本出现校验态）
  Future<List<int>> getPieceStates(String hash) async {
    final Response<dynamic> resp = await _dio.get(
      '/api/v2/torrents/pieceStates',
      queryParameters: <String, dynamic>{'hash': hash},
    );
    final List<dynamic> list = _asList(resp, '/api/v2/torrents/pieceStates');
    return list.map((dynamic e) => (e as num?)?.toInt() ?? 0).toList();
  }

  Future<void> addPeers(String hashes, String peers) async {
    await _postOk(
      '/api/v2/torrents/addPeers',
      queryParameters: <String, dynamic>{'hashes': hashes, 'peers': peers},
    );
  }

  Future<void> renameTorrentFile(String hash, String oldPath, String newPath) async {
    await _postOk(
      '/api/v2/torrents/renameFile',
      queryParameters: <String, dynamic>{
        'hash': hash,
        'oldPath': oldPath,
        'newPath': newPath,
      },
    );
  }

  Future<void> renameTorrentFolder(String hash, String oldPath, String newPath) async {
    await _postOk(
      '/api/v2/torrents/renameFolder',
      queryParameters: <String, dynamic>{
        'hash': hash,
        'oldPath': oldPath,
        'newPath': newPath,
      },
    );
  }

  /// infohash v1/v2、seen_complete 等低频元数据（qB 5.x 起有 v1/v2 字段）
  Future<Map<String, dynamic>> getTorrentMeta(String hash) async {
    final Response<dynamic> resp = await _dio.get(
      '/api/v2/torrents/info',
      queryParameters: <String, dynamic>{'hashes': hash},
    );
    final List<dynamic> list = _asList(resp, '/api/v2/torrents/info');
    if (list.isEmpty) return <String, dynamic>{};
    return Map<String, dynamic>.from(list.first);
  }

  Future<List<QbLog>> getLog({int lastKnownId = -1, bool info = true}) async {
    final Response<dynamic> resp = await _dio.get(
      '/api/v2/log/main',
      queryParameters: <String, dynamic>{
        'last_known_id': lastKnownId,
        'info': info,
      },
    );
    final List<dynamic> list = _asList(resp, '/api/v2/log/main');
    return list
        .map((dynamic e) => QbLog.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<int>> exportTorrent(String hash) async {
    final Response<List<int>> resp = await _dio.get<List<int>>(
      '/api/v2/torrents/export',
      queryParameters: <String, dynamic>{'hash': hash},
      options: Options(responseType: ResponseType.bytes),
    );
    return resp.data ?? <int>[];
  }

  Future<List<Map<String, dynamic>>> getFiles(String hash) =>
      getTorrentFiles(hash);

  Future<List<Map<String, dynamic>>> getPeers(String hash) =>
      getTorrentPeers(hash);

  Future<List<QbLog>> getQbLogs({int lastKnownId = -1, bool info = true}) =>
      getLog(lastKnownId: lastKnownId, info: info);

  Future<void> showBanPeers(String peers) => banPeers(peers);

  Future<List<Torrent>> updateSelect(List<String> hashes) async {
    if (hashes.isEmpty) return <Torrent>[];
    final Response<dynamic> resp = await _dio.get(
      '/api/v2/torrents/info',
      queryParameters: <String, dynamic>{'hashes': hashes.join('|')},
    );
    final List<dynamic> list = _asList(resp, '/api/v2/torrents/info');
    return list
        .map((dynamic e) => Torrent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> getPreferences() async {
    final Response<dynamic> resp = await _dio.get('/api/v2/app/preferences');
    return _asMap(resp, '/api/v2/app/preferences');
  }

  Future<void> _setAppPreferences(Map<String, dynamic> prefs) async {
    await _postOk(
      '/api/v2/app/setPreferences',
      data: FormData.fromMap(<String, dynamic>{
        'json': jsonEncode(prefs),
      }),
    );
  }

  Future<void> setPreferences(Map<String, dynamic> patch) async {
    if (patch.isEmpty) return;
    await _setAppPreferences(patch);
  }

  Future<QbIpFilter> getIpFilter() async =>
      QbIpFilter.fromPrefs(await getPreferences());

  Future<void> setIpFilter(QbIpFilter filter, {QbIpFilter? base}) async {
    final Map<String, dynamic> patch = base == null
        ? <String, dynamic>{
            QbIpFilter.keyEnabled: filter.enabled,
            QbIpFilter.keyTrackers: filter.filterTrackers,
            QbIpFilter.keyBanned: filter.bannedIps,
          }
        : filter.diffFrom(base);
    if (patch.isEmpty) {
      AppLog.instance.net('IP 过滤无变化，跳过写入', scope: _server?.logScope);
      return;
    }
    await _setAppPreferences(patch);
  }
}
