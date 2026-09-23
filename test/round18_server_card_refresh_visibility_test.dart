import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/pages/server_list_page.dart';
import 'package:torrent_manager/widgets/app_toast.dart';

ServerData qbSrv(String id, String host) => ServerData(
      id: id,
      name: 'NAS-$id',
      type: 'qbittorrent',
      host: host,
      port: 8080,
    );

Dio gatedQb(Future<void> gate) {
  final Dio dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) async {
      await gate;
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
      if (p.contains('/torrents/info')) {
        h.resolve(Response<dynamic>(
            requestOptions: o, statusCode: 200, data: <dynamic>[]));
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
        requestOptions: o,
        statusCode: 200,
        data: <String, dynamic>{},
      ));
    },
  ));
  return dio;
}

ServerController createControllers(Dio dio) {
  final ServerController sc =
      Get.put(ServerController(qb: QbMethod(dio: dio)));
  Get.put(ThemeController(), permanent: true);
  Get.put(TorrentController());
  return sc;
}

void installTwoServers(ServerController sc, Dio dio) {
  sc.qbFactory = () => QbMethod(dio: dio);
  sc.servers.assignAll(<ServerData>[
    qbSrv('a', '10.0.0.1'), 
    qbSrv('b', '10.0.0.2'), 
  ]);
  sc.current.value = sc.servers.first;
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
    AppToast.resetForTest();
  });

  tearDown(AppToast.resetForTest);

  group('⑦ 两台卡片都要有「获取列表...」（需求 7）', () {
    test('★ 非当前服务器的刷新链路也要上报 connecting（与主链路对称）', () async {
      final Completer<void> gate = Completer<void>();
      final Dio dio = gatedQb(gate.future);
      final ServerController sc = createControllers(dio);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      installTwoServers(sc, dio);
      expect(Get.isRegistered<TorrentController>(), isTrue,
          reason: '对照组成立的前提：当前服务器走的是主链路');
      expect(sc.servers.length, 2);

      final Future<void> run = sc.refreshAllServers();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(sc.connStatus['a'], ConnStatus.connecting,
          reason: '当前服务器一直有「获取列表...」中间态');
      expect(sc.connStatus['b'], ConnStatus.connecting,
          reason: '★ 非当前服务器也必须进入「获取列表...」—— 这正是用户看到'
              '「第二的卡片没有显示」的根因：后台链路此前全程不上报 connecting，'
              '卡片从 idle 直接跳到终态，刷新过程对用户完全不可见');

      gate.complete();
      await run;
      expect(sc.connStatus['a'], ConnStatus.ok);
      expect(sc.connStatus['b'], ConnStatus.ok,
          reason: '本次只补中间态，终态语义不能变');
    });

    test('★ 已连接（ok）的卡片不得因轮询退回 connecting（防徽章闪烁）', () async {
      final Dio dio = gatedQb(Future<void>.value());
      final ServerController sc = createControllers(dio);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      installTwoServers(sc, dio);

      await sc.refreshAllServers();
      expect(sc.connStatus['a'], ConnStatus.ok);
      expect(sc.connStatus['b'], ConnStatus.ok);

      final Completer<void> gate2 = Completer<void>();
      sc.qbFactory = () => QbMethod(dio: gatedQb(gate2.future));
      final Future<void> run = sc.refreshAllServers();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(sc.connStatus['a'], ConnStatus.ok, reason: 'ok 不退回 connecting');
      expect(sc.connStatus['b'], ConnStatus.ok,
          reason: '★ B 同样：假如连已连接的卡片也每 3 秒打回「获取列表...」，'
              '徽章就会在「公网 / 局域网」与「获取列表...」之间反复闪 ——'
              '那是上一轮刚修掉的坑，不能为了本条需求退回去');

      gate2.complete();
      await run;
    });

    testWidgets('★ 页面上要同时出现**两处**「获取列表...」（用户可见口径）',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final Completer<void> gate = Completer<void>();
      final Dio dio = gatedQb(gate.future);
      final ServerController sc = createControllers(dio);

      await tester.pumpWidget(const GetMaterialApp(home: ServerListPage()));

      await tester.pump(const Duration(milliseconds: 50));
      expect(identical(Get.find<ServerController>(), sc), isTrue,
          reason: '页面拿到的必须是我们注入的那个实例');

      installTwoServers(sc, dio);
      await tester.pump();

      unawaited(sc.refreshAllServers());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.text('连接中...'), findsNWidgets(2),
          reason: '★ 两张卡片都应显示「获取列表...」—— 用户反馈的正是'
              '「只有排第一的卡片会显示，第二的卡片没有显示」');

      gate.complete();

      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      AppToast.resetForTest();
    });
  });
}
