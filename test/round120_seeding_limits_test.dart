import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
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
      'max_ratio': 2.0,
      'max_ratio_enabled': true,
      'max_seeding_time': 120,
      'max_seeding_time_enabled': false,
      'max_inactive_seeding_time': 60,
      'max_inactive_seeding_time_enabled': true,
    };

class _QbFake {
  bool loggedIn = false;
  final List<Map<String, dynamic>> written = <Map<String, dynamic>>[];

  Dio dio() {
    final Dio d = Dio(BaseOptions(
      validateStatus: (int? s) => s != null && s < 500,
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) {
        final String p = o.uri.path.replaceFirst('/api/v2', '');
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
        h.resolve(Response<dynamic>(
            requestOptions: o, statusCode: 200, data: <String, dynamic>{}));
      },
    ));
    return d;
  }
}

class _TrFake {
  final List<Map<String, dynamic>> sets = <Map<String, dynamic>>[];

  /// TR 4.1+（kebab 新键名）
  final Map<String, dynamic> session = <String, dynamic>{
    'speed-limit-up': 512,
    'speed-limit-down': 1024,
    'alt-speed-enabled': false,
    'download-dir': '/tr/downloads',
    'dht-enabled': true,
    'pex-enabled': true,
    'lpd-enabled': false,
    'encryption': 'preferred',
    'seed-ratio-limit': 3.0,
    'seed-ratio-limited': true,
    'upload-limit': 10,
    'idle-seeding-limit': 45,
    'idle-seeding-limit-enabled': true,
  };

  /// 切到 TR ≤4.0（旧键名）
  void useLegacyKeys() {
    session
      ..remove('seed-ratio-limit')
      ..remove('seed-ratio-limited')
      ..remove('upload-limit')
      ..['seedRatioLimit'] = 2.5
      ..['seedRatioLimited'] = false
      ..['upload-slots-per-torrent'] = 8;
  }

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
        final Map<String, dynamic> a = Map<String, dynamic>.from(
            m['arguments'] as Map? ?? <String, dynamic>{});
        if (method == 'session-set') sets.add(a);
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

/// _numCell 标签行内嵌的启用开关（label → 最近 Row → 后代 switch）
Finder _cellSwitch(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
      matching: find.byType(CupertinoSwitch),
    );

Finder _saveButtonOfGroup(String label) => find.descendant(
      of: find
          .ancestor(of: find.text(label), matching: find.byType(ExpansionTile))
          .first,
      matching: find.byIcon(Icons.check_rounded),
    );

Finder _cellTextField(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
      matching: find.byType(TextField),
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

  test('① qB：API read 白名单带回做种限制 enabled 键', () async {
    final _QbFake fake = _QbFake();
    final QbPrefsApi api = QbPrefsApi(
        client: QbMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    api.attach(qbSrv());
    await expectLater(api.ensureSession(), completion(isTrue));

    final Map<String, dynamic> read = await api.read();
    expect(read[PrefKey.maxRatio], 2.0);
    expect(read[PrefKey.maxRatioEnabled], true);
    expect(read[PrefKey.maxSeedingTime], 120);
    expect(read[PrefKey.maxSeedingTimeEnabled], false);
    expect(read[PrefKey.maxInactiveSeedingTime], 60);
    expect(read[PrefKey.maxInactiveSeedingTimeEnabled], true);
  });

  test('② TR ≤4.0（旧 camel 键）：read 双键映射读回', () async {
    final _TrFake fake = _TrFake()..useLegacyKeys();
    final TrPrefsApi api = TrPrefsApi(
        client: TrMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    api.attach(trSrv());
    await expectLater(api.ensureSession(), completion(isTrue));

    final Map<String, dynamic> read = await api.read();
    expect(read[PrefKey.maxRatio], 2.5, reason: '旧键 seedRatioLimit 应映射 maxRatio');
    expect(read[PrefKey.maxRatioEnabled], false);
    expect(read[PrefKey.maxUploadsPerTorrent], 8,
        reason: '旧键 upload-slots-per-torrent 应映射 maxUploadsPerTorrent');
    expect(read[PrefKey.maxInactiveSeedingTime], 45);
    expect(read[PrefKey.maxInactiveSeedingTimeEnabled], true);
  });

  test('③ TR 4.1+（kebab 新键）：read 读回', () async {
    final _TrFake fake = _TrFake();
    final TrPrefsApi api = TrPrefsApi(
        client: TrMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    api.attach(trSrv());
    await expectLater(api.ensureSession(), completion(isTrue));

    final Map<String, dynamic> read = await api.read();
    expect(read[PrefKey.maxRatio], 3.0, reason: '新键 seed-ratio-limit 应映射 maxRatio');
    expect(read[PrefKey.maxRatioEnabled], true);
    expect(read[PrefKey.maxUploadsPerTorrent], 10);
  });

  test('④ TR：write 比率/上传槽位双键下发（新键 + 旧别名同值）', () async {
    final _TrFake fake = _TrFake();
    final TrPrefsApi api = TrPrefsApi(
        client: TrMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    api.attach(trSrv());
    await expectLater(api.ensureSession(), completion(isTrue));

    await api.write(<String, dynamic>{
      PrefKey.maxRatio: 5.0,
      PrefKey.maxRatioEnabled: true,
      PrefKey.maxUploadsPerTorrent: 12,
      PrefKey.maxInactiveSeedingTime: 90,
    });
    expect(fake.sets.last, <String, dynamic>{
      'seed-ratio-limit': 5.0,
      'seedRatioLimit': 5.0,
      'seed-ratio-limited': true,
      'seedRatioLimited': true,
      'upload-limit': 12,
      'upload-slots-per-torrent': 12,
      'idle-seeding-limit': 90,
    }, reason: '4.1 键 + 4.0 别名同值双发；idle 键两版同名不双发');
  });

  testWidgets('⑤ qB 页面：做种限制组开关渲染 + 切换只下发 enabled 单键',
      (WidgetTester tester) async {
    final _QbFake fake = _QbFake();
    ServerSettingPage.debugPrefsOverride =
        QbPrefsApi(client: QbMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, qbSrv());
    await _expand(tester, '设置做种限制');

    expect(tester.widget<CupertinoSwitch>(_cellSwitch('最大分享比率')).value, true,
        reason: 'max_ratio_enabled=true → 开');
    expect(tester.widget<CupertinoSwitch>(_cellSwitch('最长做种时间')).value, false,
        reason: 'max_seeding_time_enabled=false → 关');
    expect(tester.widget<CupertinoSwitch>(_cellSwitch('非活动做种时间')).value, true);

    await tester.tap(_cellSwitch('非活动做种时间'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(fake.written.last, <String, dynamic>{
      'max_inactive_seeding_time_enabled': false,
    }, reason: '开关只下发 enabled 单键');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('⑥ qB 保存：空输入不下发、不再夹带 enabled=true',
      (WidgetTester tester) async {
    final _QbFake fake = _QbFake();
    ServerSettingPage.debugPrefsOverride =
        QbPrefsApi(client: QbMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, qbSrv());
    await _expand(tester, '设置做种限制');

    await tester.enterText(_cellTextField('最大分享比率'), '');
    await tester.enterText(_cellTextField('最长做种时间'), '');
    await tester.enterText(_cellTextField('非活动做种时间'), '90');
    await tester.pump(const Duration(milliseconds: 200));

    final Finder saveBtn = _saveButtonOfGroup('最大分享比率');
    await tester.ensureVisible(saveBtn);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(saveBtn);
    await tester.pump(const Duration(milliseconds: 600));

    expect(fake.written.last, <String, dynamic>{
      'max_inactive_seeding_time': 90,
    }, reason: '空输入不下发（无 -1），且不夹带 max_ratio_enabled/max_seeding_time_enabled');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('⑦ TR 页面：闲置做种开关渲染 + 切换下发 idle-seeding-limit-enabled',
      (WidgetTester tester) async {
    final _TrFake fake = _TrFake();
    ServerSettingPage.debugPrefsOverride = TrPrefsApi(
        client: TrMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, trSrv());
    await _expand(tester, '设置做种限制');

    expect(find.text('最长做种时间'), findsNothing, reason: 'TR 无总做种时间');
    expect(tester.widget<CupertinoSwitch>(_cellSwitch('最大分享比率')).value, true,
        reason: 'seed-ratio-limited=true → 开');
    expect(tester.widget<CupertinoSwitch>(_cellSwitch('非活动做种时间')).value, true,
        reason: 'idle-seeding-limit-enabled=true → 开');

    await tester.tap(_cellSwitch('非活动做种时间'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(fake.sets.last, <String, dynamic>{'idle-seeding-limit-enabled': false});

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('⑧ 窄屏 320dp：做种限制行式布局无溢出截断',
      (WidgetTester tester) async {
    final List<String> problems = <String>[];
    final void Function(FlutterErrorDetails)? oldOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails d) {
      final String s = d.exceptionAsString();
      if (s.contains('Unable to load asset')) return;
      if (s.contains('overflowed')) problems.add(s.split('\n').first);
      oldOnError?.call(d);
    };
    addTearDown(() => FlutterError.onError = oldOnError);

    final _QbFake fake = _QbFake();
    ServerSettingPage.debugPrefsOverride =
        QbPrefsApi(client: QbMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, qbSrv());
    // Mate 80 Pro 级窄宽（320 逻辑 dp）模拟极限场景
    tester.view.physicalSize = const Size(960, 2400);
    tester.view.devicePixelRatio = 3.0;
    await tester.pump(const Duration(milliseconds: 100));
    await _expand(tester, '设置做种限制');

    expect(find.text('最大分享比率'), findsOneWidget);
    expect(problems, isEmpty,
        reason: '窄屏+大字下不应 RenderFlex 溢出：${problems.take(3)}');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
