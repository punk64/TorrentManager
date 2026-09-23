import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/utils/crypto_box.dart';

ServerData srv({
  String id = 'qb-1',
  String host = '5.5.5.5',
  int port = 443,
  String? lanHost,
  int? lanPort,
}) =>
    ServerData(
      id: id,
      name: 'NAS-$id',
      type: 'qbittorrent',
      host: host,
      port: port,
      lanHost: lanHost,
      lanPort: lanPort,
      username: 'u',
      password: 'p',
    );

class _SessionQbServer implements HttpClientAdapter {
  _SessionQbServer(this.log, {this.onUnauthedVersion});

  final List<String> log;

  final void Function()? onUnauthedVersion;

  bool _hookFired = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = o.uri.path;
    final String host = o.uri.host;
    final String cookie = '${o.headers['cookie'] ?? ''}';
    final bool authed = cookie.contains('SID=');
    int code = 200;
    String body = '[]';
    String? setCookie;

    if (path.contains('/auth/login')) {
      body = 'Ok.';
      setCookie = 'SID=$host; path=/';
    } else if (path.contains('/app/version')) {
      if (authed) {
        body = 'v4.6.2';
      } else {
        code = 403;
        body = 'Forbidden';
        if (!_hookFired && onUnauthedVersion != null) {
          _hookFired = true;
          onUnauthedVersion!();
        }
      }
    } else if (path.contains('/app/webapiVersion')) {
      body = '2.11.2';
    } else if (path.contains('/torrents/info')) {
      body = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'hash': 'h1',
          'name': '示例种子',
          'size': 1000,
          'progress': 1.0,
          'state': 'uploading',
        },
      ]);
    } else if (path.contains('/sync/maindata')) {
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'rid': 1,
          'server_state': <String, dynamic>{'queued_io_jobs': 0},
          'torrents': <String, dynamic>{},
        }),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );
    }

    log.add('$code ${o.method} $host$path');
    return ResponseBody.fromString(
      body,
      code,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/plain'],
        if (setCookie != null) 'set-cookie': <String>[setCookie],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

QbMethod _qbWith(_SessionQbServer server) {
  final Dio dio = Dio(BaseOptions(

    validateStatus: (int? s) => s != null && s < 500,
  ));
  dio.httpClientAdapter = server;
  return QbMethod(dio: dio);
}

int _loginsTo(List<String> log, String host) => log
    .where((String e) => e.contains('/auth/login') && e.contains(' $host/'))
    .length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
    Get.reset();

    CryptoBox.testIterationsOverride = CryptoBox.minIterations;
  });

  tearDown(() {
    CryptoBox.testIterationsOverride = null;
  });

  test('★ 探测期间切到局域网：必须在新路由上登录，而不是放弃导致 403', () async {
    final List<String> log = <String>[];
    final ServerData pub = srv(host: '5.5.5.5', lanHost: '10.0.0.1', lanPort: 8080);
    final ServerData lan = pub.connectionTarget(viaLan: true);
    expect(lan.host, '10.0.0.1', reason: '前置：connectionTarget 应给出局域网地址');

    QbMethod? self;
    final QbMethod c = _qbWith(_SessionQbServer(
      log,
      onUnauthedVersion: () => self?.setServer(lan),
    ));
    self = c;

    final bool ok = await c.checkQbServerCookie(pub);
    expect(ok, isTrue, reason: '★ 修复前：这里直接 false，上层裸奔请求 → 403 挂起');

    expect(_loginsTo(log, '10.0.0.1'), 1,
        reason: '★ 登录要发到切换后的局域网地址');
    expect(_loginsTo(log, '5.5.5.5'), 0,
        reason: '★ 不该再把登录浪费在已被放弃的公网路由上');

    try {
      await c.getTorrentList();
    } catch (_) {
    }
    expect(
      log.any((String e) => e.startsWith('200 GET 10.0.0.1/api/v2/torrents/info')),
      isTrue,
      reason: '★ 列表请求不再 403（会话在正确的域里）',
    );
  });

  test('无竞态时行为不变：探测 403 → 正常登录 → 一次到位', () async {
    final List<String> log = <String>[];
    final QbMethod c = _qbWith(_SessionQbServer(log));

    final bool ok = await c.checkQbServerCookie(srv(host: '10.9.9.9', port: 8080));
    expect(ok, isTrue);
    expect(_loginsTo(log, '10.9.9.9'), 1, reason: '常规路径：登录一次');
  });

  test('★ 列表请求 403（会话失效）：补登录后重试成功，不再误报密码错误', () async {
    final List<String> log = <String>[];
    int infoCalls = 0;
    final Dio dio = Dio(BaseOptions(
      baseUrl: 'http://10.0.0.7:8080',
      validateStatus: (int? s) => s != null && s < 500,
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) {
        final String p = o.uri.path;
        log.add('${o.method} $p');
        Response<dynamic> ok(Object? data) =>
            Response<dynamic>(requestOptions: o, statusCode: 200, data: data);
        if (p.endsWith('/auth/login')) {
          h.resolve(ok('Ok.'));
        } else if (p.endsWith('/app/version')) {
          h.resolve(ok('v4.6.2'));
        } else if (p.endsWith('/torrents/info')) {
          infoCalls++;

          h.resolve(infoCalls == 1
              ? Response<dynamic>(
                  requestOptions: o, statusCode: 403, data: 'Forbidden')
              : ok(<Map<String, dynamic>>[
                  <String, dynamic>{
                    'hash': 'h1',
                    'name': '示例种子',
                    'size': 1000,
                    'progress': 1.0,
                    'state': 'uploading',
                  },
                ]));
        } else if (p.endsWith('/sync/maindata')) {
          h.resolve(ok(<String, dynamic>{
            'rid': 1,
            'server_state': <String, dynamic>{},
          }));
        } else {
          h.resolve(ok(''));
        }
      },
    ));

    final ServerController sc =
        Get.put(ServerController(qb: QbMethod(dio: dio)));
    final ServerData s = srv(id: 'qb-1', host: '10.0.0.7', port: 8080);
    sc.servers.assignAll(<ServerData>[s]);
    sc.current.value = s;
    sc.qbFactory = () => QbMethod(dio: dio);
    Get.put<ThemeController>(ThemeController(), permanent: true);
    final TorrentController ctrl = Get.put(TorrentController());

    await Future<void>.delayed(const Duration(milliseconds: 300));
    log.clear();
    infoCalls = 0;

    await ctrl.refresh();

    expect(infoCalls, 2,
        reason: '★ 第一笔 403 后应重试一次（共两笔列表请求）');
    expect(ctrl.items.length, 1,
        reason: '★ 重试成功后列表要有数据（此前直接报错挂起）');
    expect(sc.connStatus['qb-1'], ConnStatus.ok,
        reason: '★ 不能再把这次 403 上报成 authFailed 挂起');
  });

  test('★ addServer / updateServer 后立即刷新该卡片', () async {
    final List<String> log = <String>[];
    final ServerController sc = ServerController(qb: _qbWith(_SessionQbServer(log)));
    sc.qbFactory = () => _qbWith(_SessionQbServer(log));
    final ServerData s = srv(id: 'qb-2', host: '10.0.0.9', port: 8080);

    await sc.addServer(s);

    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      log.any((String e) => e.contains('10.0.0.9/api/v2/app/version')),
      isTrue,
      reason: '★ 保存后应立即发起该卡的连接（此前要等 3 秒轮询的第一拍）',
    );
    expect(sc.connStatus['qb-2'], ConnStatus.ok,
        reason: '★ 卡片应直接亮起（连接成功）');

    log.clear();
    final ServerData s2 = s.copyWith(host: '10.0.0.10');
    await sc.updateServer(s2);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      log.any((String e) => e.contains('10.0.0.10/api/v2/app/version')),
      isTrue,
      reason: '★ 编辑保存后立即按新地址重连',
    );
  });
}
