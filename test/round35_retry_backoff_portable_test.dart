import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/pages/server_dialog.dart';
import 'package:torrent_manager/pages/server_list_page.dart';
import 'package:torrent_manager/utils/crypto_box.dart';
import 'package:torrent_manager/utils/net_error.dart';

ServerData qbSrv(String id, String host, {String? user, String? pass}) =>
    ServerData(
      id: id,
      name: 'NAS-$id',
      type: 'qbittorrent',
      host: host,
      port: 8080,
      username: user,
      password: pass,
    );

class _TextAdapter implements HttpClientAdapter {
  _TextAdapter(this.body, {this.statusCode = 200});

  final String body;
  final int statusCode;

  final List<String> paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/plain'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

DioException _dioErr(
  DioExceptionType type, {
  int? code,
  String? body,
  Object? inner,
}) {
  final RequestOptions opt = RequestOptions(path: '/api/v2/app/version');
  return DioException(
    requestOptions: opt,
    type: type,
    response: code == null
        ? null
        : Response<dynamic>(requestOptions: opt, statusCode: code, data: body),
    error: inner,
  );
}

Dio _countingDio(List<String> log) {
  final Dio dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      log.add('${o.uri.host}${o.uri.path}');
      final String p = o.uri.path;
      if (p.contains('maindata')) {
        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: <String, dynamic>{
            'rid': 1,
            'server_state': <String, dynamic>{'queued_io_jobs': 1},
            'torrents': <String, dynamic>{},
          },
        ));
        return;
      }
      if (p.contains('/app/version')) {
        h.resolve(Response<dynamic>(
            requestOptions: o, statusCode: 200, data: '4.6.2'));
        return;
      }
      if (p.contains('/app/webapiVersion')) {
        h.resolve(Response<dynamic>(
            requestOptions: o, statusCode: 200, data: '2.11.2'));
        return;
      }
      if (p.contains('/auth/login')) {
        h.resolve(Response<dynamic>(
            requestOptions: o, statusCode: 200, data: 'Ok.'));
        return;
      }
      h.resolve(Response<dynamic>(
          requestOptions: o, statusCode: 200, data: <dynamic>[]));
    },
  ));
  return dio;
}

Dio _qbDio(String baseUrl) => Dio(BaseOptions(
      baseUrl: baseUrl,
      validateStatus: (int? s) => s != null && s < 500,
    ));

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

  group('★ ConnErrorKind：错误分类决定「挂起」还是「退避」', () {
    test('IP 封禁（403 + banned 正文）→ ipBanned，且文案说清是封禁不是密码错', () {
      final DioException e = _dioErr(
        DioExceptionType.badResponse,
        code: 403,
        body: 'Your IP address has been banned after too many failed '
            'authentication attempts.',
      );
      expect(NetError.classify(e), ConnErrorKind.ipBanned);
      expect(NetError.classify(e).isFatal, isTrue);
      expect(NetError.describe(e), contains('封禁'),
          reason: '★ 若按 401/403 通用分支处理，用户会被「账号或密码错误」误导，'
              '越改密码越封');
    });

    test('401 / 403（无 banned）→ authFailed', () {
      expect(
        NetError.classify(_dioErr(DioExceptionType.badResponse, code: 401)),
        ConnErrorKind.authFailed,
      );
      expect(
        NetError.classify(_dioErr(DioExceptionType.badResponse, code: 403)),
        ConnErrorKind.authFailed,
      );
    });

    test('404 / 证书失败 → addressInvalid（配置写错，等多久都不会好）', () {
      expect(
        NetError.classify(_dioErr(DioExceptionType.badResponse, code: 404)),
        ConnErrorKind.addressInvalid,
      );
      expect(
        NetError.classify(_dioErr(DioExceptionType.badCertificate)),
        ConnErrorKind.addressInvalid,
      );
      expect(ConnErrorKind.addressInvalid.isFatal, isTrue);
    });

    test('超时 / 连接被拒 / 网络不可达 → unreachable（值得退避重试）', () {
      expect(
        NetError.classify(_dioErr(DioExceptionType.connectionTimeout)),
        ConnErrorKind.unreachable,
      );
      expect(
        NetError.classify(_dioErr(
          DioExceptionType.connectionError,
          inner: const SocketException('Connection refused'),
        )),
        ConnErrorKind.unreachable,
      );
      expect(
        NetError.classify(_dioErr(
          DioExceptionType.connectionError,
          inner: const SocketException('Network is unreachable'),
        )),
        ConnErrorKind.unreachable,
      );
      expect(ConnErrorKind.unreachable.isRetryable, isTrue);
      expect(ConnErrorKind.unreachable.isFatal, isFalse);
    });

    test('域名解析不了 → addressInvalid（"域名写错了"不是网络问题）', () {
      expect(
        NetError.classify(_dioErr(
          DioExceptionType.connectionError,
          inner: const SocketException('Failed host lookup: ddns.example.com'),
        )),
        ConnErrorKind.addressInvalid,
      );
    });

    test('无法归类 → unknown（仍按可重试处理，不能凭空停机）', () {
      expect(NetError.classify(Exception('boom')), ConnErrorKind.unknown);
      expect(ConnErrorKind.unknown.isFatal, isFalse);
    });
  });

  group('★ qB 登录：凭据不全绝不发请求（封 IP 的根因闸门）', () {
    test('密码为空 → 返回 false、标记 missingCreds，且**一个请求都没发**', () async {
      final _TextAdapter ad = _TextAdapter('Ok.');
      final Dio dio = _qbDio('http://192.168.1.5:8080');
      dio.httpClientAdapter = ad;
      final QbMethod qb = QbMethod(dio: dio);

      final bool ok =
          await qb.updateQbServerCookie(qbSrv('q1', '192.168.1.5', user: 'admin'));

      expect(ok, isFalse);
      expect(qb.lastLoginMissingCreds, isTrue);
      expect(qb.lastLoginBanned, isFalse);
      expect(ad.paths, isEmpty,
          reason: '★ 空密码登录会被 qB 记成一次失败认证，3 秒一轮很快命中 '
              'MaxAuthenticationFailCount（默认 5）→ 封禁来源 IP');
    });

    test('账号为空同样不发请求', () async {
      final _TextAdapter ad = _TextAdapter('Ok.');
      final Dio dio = _qbDio('http://192.168.1.5:8080');
      dio.httpClientAdapter = ad;
      final QbMethod qb = QbMethod(dio: dio);

      expect(await qb.updateQbServerCookie(qbSrv('q1', '192.168.1.5', pass: 'p')),
          isFalse);
      expect(qb.lastLoginMissingCreds, isTrue);
      expect(ad.paths, isEmpty);
    });

    test('403 + banned → lastLoginBanned，且识别成"封禁"而非"密码错"', () async {
      final Dio dio = _qbDio('http://192.168.1.5:8080');
      dio.httpClientAdapter = _TextAdapter(
        'Your IP address has been banned after too many failed '
        'authentication attempts.',
        statusCode: 403,
      );
      final QbMethod qb = QbMethod(dio: dio);

      final bool ok = await qb.updateQbServerCookie(
          qbSrv('q1', '192.168.1.5', user: 'admin', pass: 'x'));

      expect(ok, isFalse);
      expect(qb.lastLoginBanned, isTrue);
      expect(ServerController.qbKindOf(qb), ConnErrorKind.ipBanned);
    });

    test('★ 探测阶段就发现封禁 → 连登录请求都不发（每发一次都算一次失败认证）',
        () async {
      final _TextAdapter ad = _TextAdapter(
        'Your IP address has been banned after too many failed '
        'authentication attempts.',
        statusCode: 403,
      );
      final Dio dio = _qbDio('http://192.168.1.5:8080');
      dio.httpClientAdapter = ad;
      final QbMethod qb = QbMethod(dio: dio);

      final bool ok = await qb.checkQbServerCookie(
          qbSrv('q1', '192.168.1.5', user: 'admin', pass: 'x'));

      expect(ok, isFalse);
      expect(qb.lastLoginBanned, isTrue);
      expect(ad.paths.length, 1,
          reason: '★ 只应有那一次探测（/app/version），**不得**再 POST /auth/login');
      expect(ad.paths.single, contains('/app/version'));
    });

    test('Fails. → 普通鉴权失败（不是 missingCreds / banned）', () async {
      final Dio dio = _qbDio('http://192.168.1.5:8080');
      dio.httpClientAdapter = _TextAdapter('Fails.');
      final QbMethod qb = QbMethod(dio: dio);

      final bool ok = await qb.updateQbServerCookie(
          qbSrv('q1', '192.168.1.5', user: 'admin', pass: 'wrong'));

      expect(ok, isFalse);
      expect(qb.lastLoginMissingCreds, isFalse);
      expect(qb.lastLoginBanned, isFalse);
      expect(ServerController.qbKindOf(qb), ConnErrorKind.authFailed);
    });
  });

  group('★ 指数退避与停机挂起', () {
    test('可重试类：失败后进入退避窗口，窗口过后放行', () {
      final ServerController sc = ServerController();
      DateTime now = DateTime(2026, 9, 21, 10, 0, 0);
      sc.nowProvider = () => now;

      sc.reportFailure('a', Exception('boom'));
      expect(sc.retryAttempt['a'], 1);
      expect(sc.isSuspended('a'), isFalse, reason: '可重试类不该立刻挂起');
      expect(sc.shouldSkipRefresh('a'), isTrue, reason: '退避窗口内应跳过');

      now = now.add(const Duration(seconds: 3));
      expect(sc.shouldSkipRefresh('a'), isFalse, reason: '3s 后应放行');
    });

    test('退避档位 3 → 6 → 12 → 30s，之后保持在 30s', () {
      final ServerController sc = ServerController();
      DateTime now = DateTime(2026, 9, 21, 10, 0, 0);
      sc.nowProvider = () => now;

      const List<int> want = <int>[3, 6, 12, 30, 30, 30];
      for (int i = 0; i < want.length; i++) {
        sc.reportFailure('a', Exception('boom'));
        expect(sc.retryAttempt['a'], i + 1);

        now = now.add(Duration(milliseconds: want[i] * 1000 - 1));
        expect(sc.shouldSkipRefresh('a'), isTrue,
            reason: '第 ${i + 1} 次失败后应等 ${want[i]}s');
        now = now.add(const Duration(milliseconds: 1));
        expect(sc.shouldSkipRefresh('a'), isFalse);
      }
    });

    test('连续失败 10 次 → 彻底挂起（不再自动重试）', () {
      final ServerController sc = ServerController();
      DateTime now = DateTime(2026, 9, 21, 10, 0, 0);
      sc.nowProvider = () => now;

      for (int i = 0; i < ServerController.kMaxConsecutiveFailures - 1; i++) {
        sc.reportFailure('a', Exception('boom'));
        now = now.add(const Duration(hours: 1)); 
      }
      expect(sc.isSuspended('a'), isFalse, reason: '第 9 次还不该挂起');
      sc.reportFailure('a', Exception('boom'));
      expect(sc.isSuspended('a'), isTrue,
          reason: '★ 第 10 次失败必须停机，否则就是无限重试');
      expect(sc.shouldSkipRefresh('a'), isTrue);
      expect(sc.shouldSkipRefresh('a', force: true), isFalse,
          reason: '手动重试必须能突破挂起');
    });

    test('四类致命错误**立即**挂起（不等 10 次）', () {
      for (final ConnErrorKind k in <ConnErrorKind>[
        ConnErrorKind.missingConfig,
        ConnErrorKind.authFailed,
        ConnErrorKind.ipBanned,
        ConnErrorKind.addressInvalid,
      ]) {
        final ServerController sc = ServerController();
        sc.reportFailureKind('a', k, 'x');
        expect(sc.isSuspended('a'), isTrue, reason: '$k 应立即挂起');
        expect(sc.retryAttempt['a'], 1);
      }
    });

    test('鉴权失败走 reportAuthFailure，文案前缀仍是「登录失败：」', () {
      final ServerController sc = ServerController();
      sc.reportAuthFailure('a', '账号或密码错误（HTTP 401）');
      expect(sc.connStatus['a'], ConnStatus.failed);
      expect(sc.connError['a'], startsWith('登录失败'),
          reason: '★ 种子页依据该前缀决定显示「重新登录」还是「重试」');
      expect(sc.isSuspended('a'), isTrue);
    });

    test('成功会清空计数、退避窗口与挂起标记', () {
      final ServerController sc = ServerController();
      DateTime now = DateTime(2026, 9, 21, 10, 0, 0);
      sc.nowProvider = () => now;

      sc.reportFailureKind('a', ConnErrorKind.ipBanned, '封了');
      expect(sc.isSuspended('a'), isTrue);
      sc.reportConnected('a');
      expect(sc.isSuspended('a'), isFalse);
      expect(sc.retryAttempt['a'], isNull);
      expect(sc.shouldSkipRefresh('a'), isFalse);
    });

    test('resumeServer / resumeAll 都能解除挂起', () {
      final ServerController sc = ServerController();
      sc.reportAuthFailure('a', 'x');
      sc.reportAuthFailure('b', 'x');
      expect(sc.isSuspended('a'), isTrue);
      sc.resumeServer('a');
      expect(sc.isSuspended('a'), isFalse);
      expect(sc.isSuspended('b'), isTrue, reason: 'resumeServer 只影响一台');
      sc.resumeAll();
      expect(sc.isSuspended('b'), isFalse);
    });

    test('编辑保存（updateServer）会解除挂起 —— 用户拍板的三个解除入口之一',
        () async {
      final ServerController sc = ServerController();
      final ServerData s = qbSrv('a', '10.0.0.1', user: 'u', pass: 'p');
      sc.servers.assignAll(<ServerData>[s]);
      sc.reportFailureKind('a', ConnErrorKind.missingConfig, '缺配置');
      expect(sc.isSuspended('a'), isTrue);

      await sc.updateServer(s.copyWith(host: '10.0.0.9'));
      expect(sc.isSuspended('a'), isFalse);
      expect(sc.retryAttempt['a'], isNull);
    });

    test('配置校验：地址 / 端口缺失或非法 → missingConfig', () {
      expect(ServerController.configProblemOf(qbSrv('a', '')), isNotNull);
      expect(
        ServerController.configProblemOf(
            qbSrv('a', '10.0.0.1').copyWith(port: 0)),
        isNotNull,
      );
      expect(
        ServerController.configProblemOf(
            qbSrv('a', '10.0.0.1').copyWith(port: 70000)),
        isNotNull,
      );
      expect(ServerController.configProblemOf(qbSrv('a', '10.0.0.1')), isNull,
          reason: '★ 只查结构性缺陷：账号密码缺失交给登录层拦，'
              '否则会把"服务端开了匿名访问"误判成配置错');
    });

    test('删除服务器会连带清掉挂起 / 退避状态（删了再加同一台不能"继承"）',
        () async {
      final ServerController sc = ServerController();
      final ServerData s = qbSrv('a', '10.0.0.1');
      sc.servers.assignAll(<ServerData>[s]);
      sc.reportFailureKind('a', ConnErrorKind.ipBanned, '封了');
      await sc.deleteServer('a');
      expect(sc.isSuspended('a'), isFalse);
      expect(sc.retryAttempt['a'], isNull);
    });
  });

  group('★ refreshAllServers 的门控', () {
    test('挂起的服务器不参与轮询；手动刷新（showProgress）强制重试全部',
        () async {
      final List<String> log = <String>[];
      final ServerController sc = ServerController();
      sc.qbFactory = () => QbMethod(dio: _countingDio(log));
      sc.servers.assignAll(<ServerData>[
        qbSrv('a', '10.0.0.1', user: 'u', pass: 'p'),
        qbSrv('b', '10.0.0.2', user: 'u', pass: 'p'),
      ]);
      sc.reportFailureKind('b', ConnErrorKind.ipBanned, '封了');
      expect(sc.isSuspended('b'), isTrue);

      log.clear();
      await sc.refreshAllServers();
      expect(log.any((String p) => p.startsWith('10.0.0.1')), isTrue,
          reason: 'a 应该被刷');
      expect(log.any((String p) => p.startsWith('10.0.0.2')), isFalse,
          reason: '★ 挂起的 b 必须被跳过（此前是无条件重试）');

      log.clear();
      await sc.refreshAllServers(showProgress: true);
      expect(sc.isSuspended('b'), isFalse, reason: '手动刷新 = 强制全部重试');
      expect(log.any((String p) => p.startsWith('10.0.0.1')), isTrue);
      expect(log.any((String p) => p.startsWith('10.0.0.2')), isTrue,
          reason: '两台都要刷');
    });

    test('地址为空的服务器**一个请求都不发**，直接挂起', () async {
      final List<String> log = <String>[];
      final ServerController sc = ServerController();
      sc.qbFactory = () => QbMethod(dio: _countingDio(log));
      sc.servers.assignAll(<ServerData>[qbSrv('a', '', user: 'u', pass: 'p')]);

      await sc.refreshAllServers();
      expect(log, isEmpty, reason: '★ 前置参数校验没过就不该发请求');
      expect(sc.isSuspended('a'), isTrue);
      expect(sc.suspendKind['a'], ConnErrorKind.missingConfig);
    });

    test('retryOne：解除该台挂起并只重试它一台', () async {
      final List<String> log = <String>[];
      final ServerController sc = ServerController();
      sc.qbFactory = () => QbMethod(dio: _countingDio(log));
      final ServerData a = qbSrv('a', '10.0.0.1', user: 'u', pass: 'p');
      final ServerData b = qbSrv('b', '10.0.0.2', user: 'u', pass: 'p');
      sc.servers.assignAll(<ServerData>[a, b]);
      sc.reportFailureKind('a', ConnErrorKind.authFailed, '密码错');
      sc.reportFailureKind('b', ConnErrorKind.authFailed, '密码错');

      log.clear();
      await sc.retryOne(a);
      expect(sc.isSuspended('a'), isFalse);
      expect(sc.isSuspended('b'), isTrue, reason: 'retryOne 不该动别的服务器');
      expect(log.any((String p) => p.startsWith('10.0.0.1')), isTrue,
          reason: '被点的那台要真的发请求');
      expect(log.any((String p) => p.startsWith('10.0.0.2')), isFalse,
          reason: '★ 只重试它一台');
    });
  });

  group('★ 便携口令加密备份（信封 v2）', () {
    test('round-trip：口令加密 → 同一口令可解出原文', () async {
      const String plain = '[{"id":"a","password":"secret"}]';
      final String env = await CryptoBox.encryptWithPassphrase(plain, 'pass1234');

      expect(CryptoBox.isPortableEnvelope(env), isTrue);
      expect(env, contains('"v":2'));
      expect(env, contains('PBKDF2-HMAC-SHA256'));
      expect(env, contains('"iter"'));
      expect(env, isNot(contains('secret')),
          reason: '★ 明文绝不能出现在文件里');

      expect(await CryptoBox.decryptWithPassphrase(env, 'pass1234'), plain);
    });

    test('口令错误 → 抛 CryptoBoxException（GCM 校验失败）', () async {
      final String env =
          await CryptoBox.encryptWithPassphrase('hello', 'right-pass');
      expect(
        () => CryptoBox.decryptWithPassphrase(env, 'wrong-pass'),
        throwsA(isA<CryptoBoxException>()),
      );
    });

    test('v2 信封不能走本机密钥解密 —— 必须给出「换入口 + 输口令」的指引', () async {
      final String env =
          await CryptoBox.encryptWithPassphrase('hello', 'pass1234');
      expect(CryptoBox.isEnvelope(env), isTrue,
          reason: 'isEnvelope 仍应认它（用来判断"这是个备份文件"）');
      expect(
        () => CryptoBox.tryDecrypt(env),
        throwsA(predicate((Object e) =>
            e is CryptoBoxException && e.message.contains('便携备份'))),
        reason: '★ 报"密钥不匹配/文件已损坏"会把用户往"文件坏了"引',
      );
    });

    test('普通 JSON / v1 信封走便携解密 → 明确报「不是便携备份」', () async {
      expect(
        () => CryptoBox.decryptWithPassphrase('[]', 'pass1234'),
        throwsA(isA<CryptoBoxException>()),
      );
      final String v1 = await CryptoBox.encrypt('[]');
      expect(CryptoBox.isPortableEnvelope(v1), isFalse);
      expect(
        () => CryptoBox.decryptWithPassphrase(v1, 'pass1234'),
        throwsA(isA<CryptoBoxException>()),
      );
    });

    test('空口令拒绝加密 / 解密', () async {
      expect(
        () => CryptoBox.encryptWithPassphrase('x', ''),
        throwsA(isA<CryptoBoxException>()),
      );
    });

    test('★ 端到端：导出便携备份 → 导入 → **密码一并迁移**', () async {
      final ServerController src = ServerController();
      src.servers.assignAll(<ServerData>[
        qbSrv('a', '10.0.0.1', user: 'admin', pass: 'pw-A'),
        qbSrv('b', '10.0.0.2', user: 'admin', pass: 'pw-B'),
      ]);
      final String env = await src.buildPortableBackup('pass1234');

      final ServerController dst = ServerController();
      final int added = await dst.importPortableBackup(env, 'pass1234');

      expect(added, 2);
      expect(dst.servers.length, 2);
      expect(dst.servers[0].password, 'pw-A',
          reason: '★ 这正是"每次导入都丢服务器密码"要修的点');
      expect(dst.servers[1].password, 'pw-B');
      expect(dst.servers[0].username, 'admin');
    });

    test('便携导入：同 id 整条覆盖（含密码），不同 id 新增', () async {
      final ServerController src = ServerController();
      src.servers.assignAll(<ServerData>[
        qbSrv('a', '10.0.0.9', user: 'new', pass: 'new-pw'),
        qbSrv('c', '10.0.0.3', user: 'u', pass: 'pw-C'),
      ]);
      final String env = await src.buildPortableBackup('pass1234');

      final ServerController dst = ServerController();
      dst.servers.assignAll(<ServerData>[
        qbSrv('a', '10.0.0.1', user: 'old', pass: 'old-pw'),
      ]);
      final int added = await dst.importPortableBackup(env, 'pass1234');

      expect(added, 1);
      expect(dst.servers.length, 2);
      final ServerData a = dst.servers.firstWhere((ServerData e) => e.id == 'a');
      expect(a.password, 'new-pw',
          reason: '便携备份本来就带密码，它才是"更权威"的那一份');
      expect(a.host, '10.0.0.9');
    });

    test('导入后会解除这些服务器的挂起（密码刚被补上，不该还停着）', () async {
      final ServerController src = ServerController();
      src.servers.assignAll(<ServerData>[
        qbSrv('a', '10.0.0.1', user: 'u', pass: 'pw'),
      ]);
      final String env = await src.buildPortableBackup('pass1234');

      final ServerController dst = ServerController();
      dst.servers.assignAll(<ServerData>[qbSrv('a', '10.0.0.1', user: 'u')]);
      dst.reportFailureKind('a', ConnErrorKind.missingConfig, '缺密码');
      expect(dst.isSuspended('a'), isTrue);

      await dst.importPortableBackup(env, 'pass1234');
      expect(dst.isSuspended('a'), isFalse);
      expect(dst.servers.single.password, 'pw');
    });

    test('明文 JSON 导出**仍不含密码**（两条通道语义不能被混同）', () {
      final ServerController sc = ServerController();
      sc.servers.assignAll(<ServerData>[
        qbSrv('a', '10.0.0.1', user: 'admin', pass: 'pw-A'),
      ]);
      final String json = sc.exportJson();
      expect(json, isNot(contains('pw-A')));
      expect(jsonDecode(json), isA<List<dynamic>>());
    });
  });

  group('★ 服务器卡片：重试按钮 / 挂起芯片 / 失败文案', () {
    Future<void> pumpPage(WidgetTester tester) async {
      Get.put(ThemeController(), permanent: true);
      await tester.pumpWidget(GetMaterialApp(
        home: const ServerListPage(),
        initialBinding: AppBinding(),
      ));
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('失败 → 出现「重试」按钮；可重试类**不**显示挂起芯片',
        (WidgetTester tester) async {
      await pumpPage(tester);
      final ServerController sc = Get.find<ServerController>();
      sc.servers.assignAll(<ServerData>[qbSrv('a', '10.0.0.1')]);
      await tester.pump();

      expect(find.text('重试'), findsNothing, reason: '没失败就不该有重试按钮');

      sc.reportFailure('a', Exception('boom'));
      await tester.pump();
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('已暂停重试'), findsNothing,
          reason: 'unknown 类只退避，不挂起');
      expect(find.textContaining('刷新失败'), findsOneWidget);
    });

    testWidgets('鉴权失败 → 挂起芯片出现，且失败文案**没有双重前缀**',
        (WidgetTester tester) async {
      await pumpPage(tester);
      final ServerController sc = Get.find<ServerController>();
      sc.servers.assignAll(<ServerData>[qbSrv('a', '10.0.0.1')]);
      await tester.pump();

      sc.reportAuthFailure('a', '账号或密码错误（HTTP 401）');
      await tester.pump();

      expect(find.text('已暂停重试'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      expect(find.textContaining('刷新失败：登录失败'), findsNothing);
      expect(find.text('登录失败：账号或密码错误（HTTP 401）'), findsOneWidget);
    });

    testWidgets('缺凭据挂起 → 文案直接说"未填写账号或密码"，不加「刷新失败：」',
        (WidgetTester tester) async {
      await pumpPage(tester);
      final ServerController sc = Get.find<ServerController>();
      sc.servers.assignAll(<ServerData>[qbSrv('a', '10.0.0.1')]);
      await tester.pump();

      sc.reportFailureKind('a', ConnErrorKind.missingConfig, '未填写账号或密码');
      await tester.pump();
      expect(find.text('已暂停重试'), findsOneWidget);
      expect(find.textContaining('刷新失败：未填写账号'), findsNothing);
      expect(find.text('未填写账号或密码'), findsOneWidget);
    });

    testWidgets('点卡片「重试」→ 解除挂起并触发一次该服务器的刷新',
        (WidgetTester tester) async {
      await pumpPage(tester);
      final ServerController sc = Get.find<ServerController>();
      final List<String> log = <String>[];
      sc.qbFactory = () => QbMethod(dio: _countingDio(log));
      sc.servers.assignAll(<ServerData>[
        qbSrv('a', '10.0.0.1', user: 'u', pass: 'p'),
      ]);
      sc.reportFailureKind('a', ConnErrorKind.authFailed, '密码错');
      await tester.pump();
      expect(sc.isSuspended('a'), isTrue);

      log.clear();
      await tester.tap(find.text('重试'));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(sc.isSuspended('a'), isFalse, reason: '★ 卡片重试 = 解除挂起');
      expect(log, isNotEmpty, reason: '并且真的发起了请求');
      expect(log.any((String p) => p.contains('/app/version')), isTrue);
    });
  });

  group('★ server_dialog：编辑保存时的密码语义', () {
    Future<void> pumpPage(WidgetTester tester) async {
      Get.put(ThemeController(), permanent: true);
      await tester.pumpWidget(GetMaterialApp(
        home: const ServerListPage(),
        initialBinding: AppBinding(),
      ));
      await tester.pump(const Duration(milliseconds: 50));
    }

    tearDown(() {
      qbProbeFactory = QbMethod.new;
      trProbeFactory = TrMethod.new;
    });

    testWidgets('★ 编辑态把密码栏清空后保存 → 仍保留原密码（不再写 null）',
        (WidgetTester tester) async {
      await pumpPage(tester);
      final ServerController sc = Get.find<ServerController>();
      final ServerData s = qbSrv('a', '10.0.0.1', user: 'admin', pass: 'pw-A');
      sc.servers.assignAll(<ServerData>[s]);
      await tester.pump();

      ServerData? submitted;
      qbProbeFactory = () => _CapturingQb((ServerData v) => submitted = v);

      final BuildContext ctx = tester.element(find.byType(ServerListPage));
      unawaited(showServerDialog(ctx, editing: s));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(
          find.widgetWithText(TextFormField, '密码'), '');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, '保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(submitted, isNotNull,
          reason: '★ 编辑态密码留空必须**通过校验**并走到连通性校验 —— '
              '旧代码在这里报「请输入密码」，从导入数据打开的服务器根本保存不了');
      expect(submitted!.password, 'pw-A',
          reason: '★ 留空 = 保持原密码，绝不能被固化成 null');
    });

    testWidgets('新增态密码仍为必填（放宽只针对编辑）', (WidgetTester tester) async {
      await pumpPage(tester);
      final BuildContext ctx = tester.element(find.byType(ServerListPage));
      unawaited(showServerDialog(ctx));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.widgetWithText(TextButton, '添加'));
      await tester.pump();

      expect(find.text('请输入密码'), findsOneWidget,
          reason: '★ 新增服务器缺凭据照样不许保存（凭据缺失会触发服务端封禁）');
    });
  });
}

class _CapturingQb extends QbMethod {
  _CapturingQb(this.onCall);

  final void Function(ServerData) onCall;

  @override
  Future<bool> updateQbServerCookie(ServerData s, {int? routeGen}) async {
    onCall(s);
    return false;
  }
}
