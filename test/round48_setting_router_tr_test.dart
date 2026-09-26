import 'dart:convert';

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
      useHttps: true,
      lanHost: '192.168.1.5',
      lanPort: 8080,
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
      'up_limit': 1048576,
      'dl_limit': 2097152,
      'max_connec': 500,
      'queueing_enabled': true,
      'ip_filter_enabled': true,
      'banned_IPs': '192.168.1.77\n10.0.0.5',
    };

class _QbFake {
  bool loggedIn = false;
  final List<String> hosts = <String>[];
  final List<String> calls = <String>[];
  final List<Map<String, dynamic>> written = <Map<String, dynamic>>[];

  int countOf(String path) =>
      calls.where((String c) => c.endsWith(path)).length;

  Dio dio() {
    final Dio d = Dio(BaseOptions(
      validateStatus: (int? s) => s != null && s < 500,
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) {
        hosts.add(o.uri.host);
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
  final List<String> hosts = <String>[];
  final List<String> methods = <String>[];
  final List<Map<String, dynamic>> args = <Map<String, dynamic>>[];

  Map<String, dynamic> lastSet = <String, dynamic>{};

  final Map<String, dynamic> session = <String, dynamic>{
    'speed-limit-up': 512,
    'speed-limit-down': 1024,
    'alt-speed-up': 128,
    'alt-speed-down': 256,
    'alt-speed-enabled': true,
    'download-dir': '/tr/downloads',
    'incomplete-dir': '/tr/tmp',
    'incomplete-dir-enabled': true,
    'download-queue-enabled': true,
    'download-queue-size': 7,
    'seed-queue-size': 5,
    'seedRatioLimit': 2.0,
    'idle-seeding-limit': 30,
    'peer-limit-global': 300,
    'peer-limit-per-torrent': 60,
    'upload-slots-per-torrent': 4,
    'rename-partial-files': true,
    'blocklist-enabled': true,
    'blocklist-url': 'https://example.com/list.gz',
    'blocklist-size': 12345,
  };

  Dio dio() {
    final Dio d = Dio(BaseOptions(
      validateStatus: (int? s) => s != null && s < 500,
      followRedirects: false,
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) {
        hosts.add(o.uri.host);

        final String? sid = o.headers['X-Transmission-Session-Id'] as String?;
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

Future<void> _pump(
  WidgetTester tester, {
  required ServerData server,
  bool lanUsing = false,
  void Function(ServerController sc)? setup,
}) async {
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

  if (lanUsing) sc.lanUsing[server.id] = true;

  setup?.call(sc);
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
  await tester.pump(const Duration(milliseconds: 400));
}

List<String> _fieldTexts(WidgetTester tester) => tester
    .widgetList<TextField>(find.byType(TextField))
    .map((TextField t) => t.controller?.text ?? '')
    .toList();

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

  testWidgets('① ★ 局域网可达时，设置页的请求全部打到局域网地址（生产接线）',
      (WidgetTester tester) async {
    final _QbFake fake = _QbFake();

    await _pump(
      tester,
      server: qbSrv(),
      lanUsing: true,
      setup: (ServerController sc) => sc.qbFactory = () => QbMethod(dio: fake.dio()),
    );

    expect(fake.hosts, isNotEmpty, reason: '应当发过请求（用户报障时这里一笔都没有）');
    expect(fake.hosts, everyElement('192.168.1.5'),
        reason: '★ 设置页必须走局域网地址。出现 nas.example.com 说明退回了公网'
            '——在"局域网可达、公网不可达"的家庭网络里，那正是"参数全空"的成因');
    expect(fake.hosts, isNot(contains('nas.example.com')));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('② targetFor：局域网可达 → 换成局域网地址；不可达 → 保持公网',
      (WidgetTester tester) async {
    Get.testMode = true;
    Get.reset();
    Get.put(ThemeController(), permanent: true);
    final ServerController sc = Get.put(ServerController());
    await tester.pump(const Duration(milliseconds: 50));

    final ServerData s = qbSrv();
    expect(sc.targetFor(s).baseUrl, 'https://nas.example.com:8080');
    sc.lanUsing[s.id] = true;
    expect(sc.targetFor(s).baseUrl, 'http://192.168.1.5:8080',
        reason: '局域网可达时必须切到局域网地址（这正是设置页此前缺的一步）');
  });

  testWidgets('③ qB：偏好回填 + 限速按 KB/s 显示', (WidgetTester tester) async {
    final _QbFake fake = _QbFake();
    ServerSettingPage.debugPrefsOverride =
        QbPrefsApi(client: QbMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, server: qbSrv());
    await _expand(tester, '限速设置');

    final List<String> texts = _fieldTexts(tester);
    expect(texts, contains('1024'), reason: '1048576 字节/秒 → 1024 KB/s');
    expect(texts, contains('2048'));
    expect(find.textContaining('没能读取这台服务器的设置'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('④ TR：session-get 的值回填，KB/s 换算成字节/秒后仍显示 KB/s',
      (WidgetTester tester) async {
    final _TrFake fake = _TrFake();
    ServerSettingPage.debugPrefsOverride = TrPrefsApi(
        client: TrMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, server: trSrv());
    await _expand(tester, '限速设置');

    final List<String> texts = _fieldTexts(tester);

    expect(texts, contains('512'), reason: 'TR 的 speed-limit-up=512 KB/s');
    expect(texts, contains('1024'));
    expect(fake.methods, contains('session-get'));

    expect(find.textContaining('没能读取这台服务器的设置'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('⑤ TR：分类 / 标签整组不渲染（qB 独有接口）', (WidgetTester tester) async {
    final _TrFake fake = _TrFake();
    ServerSettingPage.debugPrefsOverride = TrPrefsApi(
        client: TrMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, server: trSrv());

    expect(find.text('限速设置'), findsOneWidget);
    expect(find.text('管理分类'), findsNothing, reason: 'TR 没有"分类"这个概念');
    expect(find.text('管理标签'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('⑥ TR：黑名单组是"整份订阅"版，没有逐条添加按钮',
      (WidgetTester tester) async {
    final _TrFake fake = _TrFake();
    ServerSettingPage.debugPrefsOverride = TrPrefsApi(
        client: TrMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, server: trSrv());
    await _expand(tester, '黑名单 / IP 过滤');

    expect(find.text('添加'), findsNothing,
        reason: 'TR 上不能出现"添加单条"的假象');
    expect(find.text('保存黑名单'), findsNothing);
    expect(find.text('订阅地址'), findsOneWidget);
    expect(find.textContaining('当前屏蔽'), findsOneWidget);

    expect(_fieldTexts(tester), contains('https://example.com/list.gz'));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('⑦ 归属地：内网段直接出结果（IpGeo.offline=true 下也不会卡住）',
      (WidgetTester tester) async {
    final _QbFake fake = _QbFake();
    ServerSettingPage.debugPrefsOverride =
        QbPrefsApi(client: QbMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, server: qbSrv());
    await _expand(tester, '黑名单 / IP 过滤');

    expect(find.textContaining('内网 IP'), findsWidgets,
        reason: '内网地址必须本地判定，不能联网查归属地');
    expect(find.textContaining('查询归属地'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('⑧ qB：改限速只下发 up_limit / dl_limit 两个键',
      (WidgetTester tester) async {
    final _QbFake fake = _QbFake();
    ServerSettingPage.debugPrefsOverride =
        QbPrefsApi(client: QbMethod(dio: fake.dio()), resolve: (ServerData s) => s);
    await _pump(tester, server: qbSrv());
    await _expand(tester, '限速设置');

    final Finder up = find.byType(TextField).first;
    await tester.enterText(up, '64');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('更改').first);
    await tester.pump(const Duration(milliseconds: 600));

    expect(fake.written, isNotEmpty, reason: '应当下发了一次偏好');
    final Map<String, dynamic> w = fake.written.last;
    expect(w.keys.toSet(), <String>{'up_limit', 'dl_limit'},
        reason: '只发改动的两项，别把页面没接的几百个键一起写回去');
    expect(w['up_limit'], 64 * 1024);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
