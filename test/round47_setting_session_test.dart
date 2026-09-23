import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/prefs/server_prefs.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/utils/ip_geo.dart';
import 'package:torrent_manager/pages/server_setting_page.dart';
import 'package:torrent_manager/utils/net_error.dart';

ServerData qbSrv() => ServerData(
      id: 'srv-1',
      name: 'NAS',
      type: 'qbittorrent',
      host: 'nas.example.com',
      port: 8080,
      username: 'admin',
      password: 'secret',
    );

class _QbFake {
  bool loginOk = true;

  bool loggedIn = false;

  final List<String> calls = <String>[];

  int countOf(String path) =>
      calls.where((String c) => c.endsWith(path)).length;

  Dio dio() {
    final Dio d = Dio(BaseOptions(

      validateStatus: (int? s) => s != null && s < 500,
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) {
        final String p = o.uri.path.replaceFirst('/api/v2', '');
        calls.add('${o.method} $p');
        if (p.endsWith('/auth/login')) {
          loggedIn = loginOk;

          h.resolve(Response<dynamic>(
              requestOptions: o,
              statusCode: 200,
              data: loginOk ? 'Ok.' : 'Fails.'));
          return;
        }
        if (!loggedIn) {
          h.resolve(Response<dynamic>(
              requestOptions: o, statusCode: 403, data: 'Forbidden'));
          return;
        }
        if (p.endsWith('/app/version')) {
          h.resolve(Response<dynamic>(
              requestOptions: o, statusCode: 200, data: 'v5.0.5'));
          return;
        }
        if (p.endsWith('/app/preferences')) {
          h.resolve(Response<dynamic>(
              requestOptions: o,
              statusCode: 200,
              data: <String, dynamic>{
                'save_path': '/downloads',
                'ip_filter_enabled': true,
              }));
          return;
        }
        if (p.endsWith('/torrents/categories')) {
          h.resolve(Response<dynamic>(
              requestOptions: o, statusCode: 200, data: <String, dynamic>{}));
          return;
        }
        if (p.endsWith('/sync/maindata')) {
          h.resolve(Response<dynamic>(
              requestOptions: o,
              statusCode: 200,
              data: <String, dynamic>{
                'rid': 1,
                'server_state': <String, dynamic>{
                  'use_alt_speed_limits': false,
                },
              }));
          return;
        }
        h.resolve(Response<dynamic>(
            requestOptions: o, statusCode: 200, data: '{}'));
      },
    ));
    return d;
  }
}

Future<void> _pumpSetting(
  WidgetTester tester,
  _QbFake fake, {
  int settleMs = 600,
}) async {
  ServerSettingPage.debugPrefsOverride = QbPrefsApi(
    client: QbMethod(dio: fake.dio()),
    resolve: (ServerData s) => s,
  );
  Get.testMode = true;
  Get.reset();
  Get.put(ThemeController(), permanent: true);
  final ServerController sc = Get.put(ServerController());
  await tester.pump(const Duration(milliseconds: 50));
  sc.current.value = qbSrv();
  await tester.pumpWidget(GetMaterialApp(
    home: const ServerSettingPage(),
    initialBinding: AppBinding(),
  ));
  await tester.pump(Duration(milliseconds: settleMs));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();

    IpGeo.offline = true;
  });
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall call) async => null);
  });

  tearDown(() {
    ServerSettingPage.debugPrefsOverride = null;
    IpGeo.offline = false;
  });

  group('⑤ NetError 不再把 403 说成「账号或密码错误」', () {
    DioException err(int code, [String body = 'Forbidden']) => DioException(
          requestOptions: RequestOptions(path: '/api/v2/x'),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/api/v2/x'),
            statusCode: code,
            data: body,
          ),
        );

    test('403 → 指向「未登录 / 会话失效」，不再提密码', () {
      final String s = NetError.describe(err(403));
      expect(s, contains('未登录或会话已失效'));

      expect(s.contains('密码'), isFalse);
    });

    test('401 保持原意（Transmission 的密码错确实是 401）', () {
      expect(NetError.describe(err(401)), contains('账号或密码错误'));
    });

    test('403 + banned 正文仍优先判为「IP 被封禁」', () {
      final String s = NetError.describe(
          err(403, 'Your IP address has been banned after too many failed '
              'authentication attempts.'));
      expect(s.contains('封禁'), isTrue);
    });
  });

  testWidgets('① 未登录 → 自动建立会话 → 偏好读得到、不再 403', (WidgetTester tester) async {
    final _QbFake fake = _QbFake();
    await _pumpSetting(tester, fake);

    expect(fake.countOf('/auth/login'), 1, reason: '应自动登录一次');

    expect(fake.countOf('/app/preferences'), greaterThanOrEqualTo(1));
    expect(fake.countOf('/sync/maindata'), greaterThanOrEqualTo(1));

    expect(find.textContaining('没能读取这台服务器的设置'), findsNothing);
  });

  testWidgets('② 3 秒轮询跑多轮，登录仍只发一笔', (WidgetTester tester) async {
    final _QbFake fake = _QbFake();
    await _pumpSetting(tester, fake);

    final int afterFirst = fake.countOf('/auth/login');
    expect(afterFirst, 1);

    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 3));
    }

    expect(fake.countOf('/auth/login'), 1,
        reason: '会话必须缓存 —— 每轮重登会让 qB 记失败认证并封 IP');

    expect(fake.countOf('/sync/maindata'), greaterThan(1));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('③ 登录失败 → 不再发业务请求，并给出准确原因', (WidgetTester tester) async {
    final _QbFake fake = _QbFake()..loginOk = false;
    await _pumpSetting(tester, fake);

    expect(fake.countOf('/auth/login'), 1);

    expect(fake.countOf('/app/preferences'), 0,
        reason: '会话没建立就不该发偏好请求');
    expect(fake.countOf('/torrents/categories'), 0);
    expect(fake.countOf('/sync/maindata'), 0);

    expect(find.textContaining('服务器拒绝了登录'), findsOneWidget);

    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 3));
    }
    expect(fake.countOf('/auth/login'), 1, reason: '失败结果同样必须缓存');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('④ 会话失败后点刷新 → 重开会话，恢复后能读到偏好', (WidgetTester tester) async {
    final _QbFake fake = _QbFake()..loginOk = false;
    await _pumpSetting(tester, fake);
    expect(fake.countOf('/auth/login'), 1);

    fake.loginOk = true;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump(const Duration(milliseconds: 600));

    expect(fake.countOf('/auth/login'), 2, reason: '刷新应重开会话并再登一次');
    expect(fake.countOf('/app/preferences'), greaterThanOrEqualTo(1));
    expect(find.textContaining('没能读取这台服务器的设置'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
