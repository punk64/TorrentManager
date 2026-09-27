import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/app/theme.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/pages/torrent_add_page.dart';

ServerData _qbSrv() => ServerData(
      id: 'qb-1',
      name: '家庭 NAS',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'admin',
      password: 'adminadmin',
    );

ServerData _trSrv() => ServerData(
      id: 'tr-1',
      name: 'TR 远程',
      type: 'transmission',
      host: '192.168.1.5',
      port: 9091,
    );

Dio fakeAddDio(List<Map<String, MapEntry<String, String>>> captured) {
  final Dio dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.1.10:8080',
    validateStatus: (int? s) => s != null && s < 500,
    followRedirects: false,
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      final String path = o.uri.path;
      Response<dynamic> ok(Object? data) =>
          Response<dynamic>(requestOptions: o, statusCode: 200, data: data);

      if (path.endsWith('/auth/login')) {
        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: 'Ok.',
          headers: Headers.fromMap(<String, List<String>>{
            'set-cookie': <String>['SID=abc; path=/'],
          }),
        ));
        return;
      }
      if (path.endsWith('/app/version')) {
        h.resolve(ok('v4.6.7'));
        return;
      }
      if (path.endsWith('/app/webapiVersion')) {
        h.resolve(ok('2.11.2'));
        return;
      }
      if (path.endsWith('/torrents/add')) {
        final Object? data = o.data;
        if (data is FormData) {
          captured.add(<String, MapEntry<String, String>>{
            for (final MapEntry<String, String> e in data.fields) e.key: e,
          });
        }
        h.resolve(ok('Ok.'));
        return;
      }
      h.resolve(ok(<String, dynamic>{}));
    },
  ));
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall call) async => null);
    Get.testMode = true;
    Get.reset();
  });

  test('addTorrents 传递 tags/限速字段，0 值不发送', () async {
    final List<Map<String, MapEntry<String, String>>> captured =
        <Map<String, MapEntry<String, String>>>[];
    final QbMethod qb = QbMethod(dio: fakeAddDio(captured));

    await qb.addTorrents(
      urls: 'magnet:?xt=urn:btih:abc',
      savepath: '/downloads',
      category: '电影',
      tags: <String>['4K', 'HDR'],
      dlLimit: 2 * 1024 * 1024,
      upLimit: 512 * 1024,
      ratioLimit: 1.5,
      seedingTimeLimit: 90,
      paused: true,
    );

    expect(captured, hasLength(1), reason: '必须恰好发出一次 /torrents/add');
    final Map<String, MapEntry<String, String>> f = captured.single;
    String val(String k) => f[k]!.value;
    expect(f.containsKey('urls'), isTrue);
    expect(val('savepath'), '/downloads');
    expect(val('category'), '电影');
    expect(val('tags'), '4K,HDR');
    expect(val('dlLimit'), '${2 * 1024 * 1024}');
    expect(val('upLimit'), '${512 * 1024}');
    expect(val('ratioLimit'), '1.5');
    expect(val('seedingTimeLimit'), '90');
    expect(f.containsKey('paused'), isTrue);
  });

  test('addTorrents 全 0 限速时不发送任何 limit 字段', () async {
    final List<Map<String, MapEntry<String, String>>> captured =
        <Map<String, MapEntry<String, String>>>[];
    final QbMethod qb = QbMethod(dio: fakeAddDio(captured));

    await qb.addTorrents(
      urls: 'magnet:?xt=urn:btih:abc',
      tags: <String>[],
      dlLimit: 0,
      upLimit: 0,
      ratioLimit: 0,
      seedingTimeLimit: 0,
    );

    expect(captured, hasLength(1));
    final Map<String, MapEntry<String, String>> f = captured.single;
    expect(f.containsKey('tags'), isFalse, reason: '空标签不发字段');
    expect(f.containsKey('dlLimit'), isFalse, reason: '0=不限，不发送');
    expect(f.containsKey('upLimit'), isFalse);
    expect(f.containsKey('ratioLimit'), isFalse);
    expect(f.containsKey('seedingTimeLimit'), isFalse);
    expect(f.containsKey('urls'), isTrue);
  });

  testWidgets('qB：显示 标签行 + 限速与分享 2×2', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(445 * 2, 985 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Get.put(ThemeController(), permanent: true);
    final ServerController sc =
        Get.put(ServerController(qb: QbMethod(dio: fakeAddDio(<Map<String, MapEntry<String, String>>>[]))));
    final ServerData srv = _qbSrv();
    sc.servers.assignAll(<ServerData>[srv]);
    sc.current.value = srv;

    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.dark,
      home: const TorrentAddPage(),
      initialBinding: AppBinding(),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('限速与分享'), findsOneWidget,
        reason: 'qB 必须显示限速与分享组卡');
    expect(find.text('下载限速'), findsOneWidget);
    expect(find.text('上传限速'), findsOneWidget);
    expect(find.text('做种时限'), findsOneWidget);
    expect(find.text('分享上限'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing, reason: '未选标签时只有入口 chip');
    expect(find.byType(ActionChip), findsOneWidget, reason: '标签入口 chip');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('TR：不显示限速与分享（torrent-add 不支持）', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(445 * 2, 985 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Get.put(ThemeController(), permanent: true);
    final ServerController sc =
        Get.put(ServerController(qb: QbMethod(dio: fakeAddDio(<Map<String, MapEntry<String, String>>>[]))));
    final ServerData srv = _trSrv();
    sc.servers.assignAll(<ServerData>[srv]);
    sc.current.value = srv;

    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.dark,
      home: const TorrentAddPage(),
      initialBinding: AppBinding(),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('限速与分享'), findsNothing,
        reason: 'TR 的 torrent-add 不支持限速字段，必须门控隐藏');
    expect(find.text('下载限速'), findsNothing);
    expect(find.text('上传限速'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
