import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
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
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/pages/server_setting_page.dart';
import 'package:torrent_manager/utils/ip_geo.dart';

ServerData qbSrv() => ServerData(
      id: 'srv-1',
      name: 'NAS',
      type: 'qbittorrent',
      host: 'nas.example.com',
      port: 8080,
      username: 'admin',
      password: 'secret',
    );

ServerData trSrv() => ServerData(
      id: 'srv-tr',
      name: 'TR',
      type: 'transmission',
      host: 'tr.example.com',
      port: 9091,
      username: 'admin',
      password: 'secret',
    );

Map<String, dynamic> qbPrefs() => <String, dynamic>{
      'save_path': '/downloads',
      'dht': true,
      'pex': true,
      'lsd': false,
      'anonymous_mode': false,
      'encryption': 0,
    };

class _QbFake {
  bool loggedIn = false;
  final List<String> calls = <String>[];
  final List<Map<String, dynamic>> written = <Map<String, dynamic>>[];

  Dio dio() {
    final Dio d = Dio(BaseOptions(
      validateStatus: (int? s) => s != null && s < 500,
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) {
        final String p = o.uri.path.replaceFirst('/api/v2', '');
        calls.add('${o.method} $p');
        if (p.endsWith('/auth/login')) {
          loggedIn = true;
          h.resolve(Response<dynamic>(
              requestOptions: o, statusCode: 200, data: 'Ok.'));
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
              requestOptions: o, statusCode: 200, data: qbPrefs()));
          return;
        }
        if (p.endsWith('/app/setPreferences')) {
          final dynamic body = o.data;
          final String raw = body is FormData
              ? (body.fields
                  .where((MapEntry<String, String> e) => e.key == 'json')
                  .map((MapEntry<String, String> e) => e.value)
                  .join())
              : '$body';
          try {
            written.add(Map<String, dynamic>.from(jsonDecode(raw) as Map));
          } catch (_) {
            written.add(<String, dynamic>{'RAW': raw});
          }
          h.resolve(Response<dynamic>(
              requestOptions: o, statusCode: 200, data: ''));
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
            requestOptions: o, statusCode: 200, data: <String, dynamic>{}));
      },
    ));
    return d;
  }
}

class _TrFake {
  final List<String> methods = <String>[];
  final List<Map<String, dynamic>> args = <Map<String, dynamic>>[];

  Map<String, dynamic> lastSet = <String, dynamic>{};

  final Map<String, dynamic> session = <String, dynamic>{
    'speed-limit-up': 512,
    'speed-limit-down': 1024,
    'alt-speed-enabled': false,
    'download-dir': '/tr/downloads',
    'dht-enabled': true,
    'pex-enabled': true,
    'lpd-enabled': false,
    'encryption': 'preferred',
  };

  Dio dio() {
    final Dio d = Dio(BaseOptions(
      validateStatus: (int? s) => s != null && s < 500,
      followRedirects: false,
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) {
        final String? sid =
            o.headers['X-Transmission-Session-Id'] as String?;
        if (sid == null) {
          h.resolve(Response<dynamic>(
            requestOptions: o,
            statusCode: 409,
            headers: Headers.fromMap(<String, List<String>>{
              'x-transmission-session-id': <String>['tr-sid-1'],
            }),
            data: '',
          ));
          return;
        }
        final dynamic body = o.data;
        final Map<String, dynamic> m = body is Map
            ? Map<String, dynamic>.from(body)
            : (jsonDecode('$body') as Map<String, dynamic>);
        final String method = '${m['method']}';
        methods.add(method);
        final Map<String, dynamic> a =
            Map<String, dynamic>.from(m['arguments'] as Map? ?? <String, dynamic>{});
        args.add(a);
        if (method == 'session-set') lastSet = a;
        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: <String, dynamic>{
            'result': 'success',
            'arguments':
                method == 'session-get' ? session : <String, dynamic>{},
          },
        ));
      },
    ));
    return d;
  }
}

Future<void> _pump(WidgetTester tester, ServerData server) async {
  tester.view.physicalSize = const Size(1500, 9000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  Get.testMode = true;
  Get.reset();
  Get.put(ThemeController(), permanent: true);
  final ServerController sc = Get.put(ServerController());
  await tester.pump(const Duration(milliseconds: 50));
  sc.current.value = server;

  await tester.pumpWidget(GetMaterialApp(
    home: const ServerSettingPage(),
    initialBinding: AppBinding(),
  ));
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> _expand(WidgetTester tester, String title) async {
  final Finder f = find.text(title);
  expect(f, findsOneWidget, reason: '找不到分组：$title');
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _switchOf(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
      matching: find.byType(CupertinoSwitch),
    );

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

  testWidgets('① qB：网络发现组渲染 DHT/PEX/LSD/匿名模式 + 协议加密档位',
      (WidgetTester tester) async {
    final _QbFake fake = _QbFake();
    ServerSettingPage.debugPrefsOverride =
        QbPrefsApi(client: QbMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, qbSrv());
    await _expand(tester, '网络发现');

    expect(find.text('启用 DHT（分布式哈希表）'), findsOneWidget);
    expect(find.text('启用 PEX（对等交换）'), findsOneWidget);
    expect(find.text('启用 LSD（本地对等发现）'), findsOneWidget);
    expect(find.text('匿名模式'), findsOneWidget);
    expect(find.text('协议加密'), findsOneWidget);
    expect(find.text('优先加密'), findsOneWidget, reason: 'encryption=0 → 优先加密');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('② qB：切 DHT 开关只下发 dht 一个键', (WidgetTester tester) async {
    final _QbFake fake = _QbFake();
    ServerSettingPage.debugPrefsOverride =
        QbPrefsApi(client: QbMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, qbSrv());
    await _expand(tester, '网络发现');

    await tester.tap(_switchOf('启用 DHT（分布式哈希表）'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(fake.written, isNotEmpty);
    expect(fake.written.last, <String, dynamic>{'dht': false},
        reason: '只发改动的一项');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('③ qB：协议加密三档可选，选强制加密下发 encryption=1',
      (WidgetTester tester) async {
    final _QbFake fake = _QbFake();
    ServerSettingPage.debugPrefsOverride =
        QbPrefsApi(client: QbMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, qbSrv());
    await _expand(tester, '网络发现');

    await tester.tap(find.text('优先加密'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('禁用加密'), findsOneWidget, reason: 'qB 三档都在');

    await tester.tap(find.text('强制加密'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(fake.written, isNotEmpty);
    expect(fake.written.last, <String, dynamic>{'encryption': 1});

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('④ TR：匿名模式不渲染，协议加密只有两档（无禁用加密）',
      (WidgetTester tester) async {
    final _TrFake fake = _TrFake();
    ServerSettingPage.debugPrefsOverride = TrPrefsApi(
        client: TrMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, trSrv());
    await _expand(tester, '网络发现');

    expect(find.text('匿名模式'), findsNothing,
        reason: 'TR 没有匿名模式，不能渲染一个无效开关');
    expect(find.text('协议加密'), findsOneWidget);
    expect(find.text('优先加密'), findsOneWidget, reason: "preferred → 优先加密");

    await tester.tap(find.text('优先加密'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('禁用加密'), findsNothing,
        reason: 'TR 没有「禁用加密」档');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('⑤ TR：选强制加密下发 sessionSet encryption=required',
      (WidgetTester tester) async {
    final _TrFake fake = _TrFake();
    ServerSettingPage.debugPrefsOverride = TrPrefsApi(
        client: TrMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, trSrv());
    await _expand(tester, '网络发现');

    await tester.tap(find.text('优先加密'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('强制加密'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(fake.lastSet, <String, dynamic>{'encryption': 'required'});

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  test('⑥ TR：API 层 DHT/PEX/LSD 映射 + 加密读写换算', () async {
    final _TrFake fake = _TrFake();
    final TrPrefsApi api = TrPrefsApi(
        client: TrMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    final ServerData s = trSrv();
    api.attach(s);
    await expectLater(api.ensureSession(), completion(isTrue));

    await api.write(<String, dynamic>{
      PrefKey.dht: false,
      PrefKey.pex: true,
      PrefKey.lsd: false,
    });
    expect(fake.lastSet, <String, dynamic>{
      'dht-enabled': false,
      'pex-enabled': true,
      'lpd-enabled': false,
    });

    await api.write(<String, dynamic>{PrefKey.anonymousMode: true});
    expect(fake.lastSet, <String, dynamic>{
      'dht-enabled': false,
      'pex-enabled': true,
      'lpd-enabled': false,
    }, reason: 'TR 无匿名模式，不得下发任何字段');

    fake.lastSet = <String, dynamic>{};
    await api.write(<String, dynamic>{PrefKey.encryption: 1});
    expect(fake.lastSet, <String, dynamic>{'encryption': 'required'});
    await api.write(<String, dynamic>{PrefKey.encryption: 0});
    expect(fake.lastSet, <String, dynamic>{'encryption': 'preferred'});

    fake.session['encryption'] = 'required';
    Map<String, dynamic> read = await api.read();
    expect(read[PrefKey.encryption], 1);
    fake.session['encryption'] = 'tolerated';
    read = await api.read();
    expect(read[PrefKey.encryption], 0);
  });

  test('⑦ qB：API 层 read 白名单带回发现相关键', () async {
    final _QbFake fake = _QbFake();
    final QbPrefsApi api = QbPrefsApi(
        client: QbMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    final ServerData s = qbSrv();
    api.attach(s);
    await expectLater(api.ensureSession(), completion(isTrue));

    final Map<String, dynamic> read = await api.read();
    expect(read[PrefKey.dht], true);
    expect(read[PrefKey.pex], true);
    expect(read[PrefKey.lsd], false);
    expect(read[PrefKey.anonymousMode], false);
    expect(read[PrefKey.encryption], 0);
    expect(api.supports(PrefKey.anonymousMode), isTrue);
  });
}
