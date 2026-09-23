import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/pages/server_list_page.dart';

ServerData trSrv() => ServerData(
      id: 'tr-1',
      name: 'TR',
      type: 'transmission',
      host: '192.168.1.9',
      port: 9091,
    );

Dio fakeTrDio() {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://192.168.1.9:9091'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      String method = '';
      final dynamic d = o.data;
      if (d is Map) {
        method = (d['method'] ?? '').toString();
      } else if (d is String) {
        try {
          final dynamic m = jsonDecode(d);
          if (m is Map) method = (m['method'] ?? '').toString();
        } catch (_) {
        }
      }
      h.resolve(Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: <String, dynamic>{
          'result': 'success',
          'arguments': method == 'torrent-get'
              ? <String, dynamic>{'torrents': <dynamic>[]}
              : <String, dynamic>{},
        },
      ));
    },
  ));
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall call) async => null);
    Get.testMode = true;
    Get.reset();
  });

  group('① 轮询刷新不得把已建立的连接退回 connecting', () {
    test('★ TR 二次刷新时仍是 ok（修复前会退回 connecting → 徽章闪「获取列表...」）',
        () async {
      final ServerData s = trSrv();

      final ServerController sc =
          Get.put(ServerController(tr: TrMethod(dio: fakeTrDio())));
      sc.servers.assignAll(<ServerData>[s]);
      sc.select(s);

      final TorrentController tc = TorrentController();

      await tc.refresh();
      expect(sc.connStatus[s.id], ConnStatus.ok,
          reason: '假传输返回成功 → 应判定为已连接');

      final Future<void> again = tc.refresh();
      expect(sc.connStatus[s.id], ConnStatus.ok,
          reason: '★ 已有连接时轮询刷新不得退回 connecting'
              '（修复前这里会是 connecting → 卡片每 3 秒闪一次「获取列表...」）');
      await again;
      expect(sc.connStatus[s.id], ConnStatus.ok);
    });

    test('首次刷新（从未连过）仍应进入 connecting，好让徽章显示「获取列表...」',
        () async {
      final ServerData s = trSrv();
      final ServerController sc =
          Get.put(ServerController(tr: TrMethod(dio: fakeTrDio())));
      sc.servers.assignAll(<ServerData>[s]);
      sc.select(s);
      final TorrentController tc = TorrentController();

      expect(sc.connStatus[s.id], isNull, reason: '还没拉过 → idle');

      final Future<void> f = tc.refresh();
      expect(sc.connStatus[s.id], ConnStatus.connecting,
          reason: '首次连接应进入 connecting（否则用户看不到任何进行中的提示）');
      await f;
      expect(sc.connStatus[s.id], ConnStatus.ok);
    });
  });

  group('② 已连接且未配局域网 → 卡片应显示「公网」', () {
    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(
        home: const ServerListPage(),
        initialBinding: AppBinding(),
      ));
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('★ ok + 非局域网 → 徽章显示「公网」（修复前被整块隐藏）',
        (WidgetTester tester) async {
      Get.put(ThemeController(), permanent: true);
      await pumpPage(tester);

      final ServerController sc = Get.find<ServerController>();
      final ServerData s = trSrv();
      sc.servers.assignAll(<ServerData>[s]);

      sc.reportConnected(s.id);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('公网'), findsWidgets,
          reason: '★ 已连接 + 未配局域网 → 应显示「公网」，而不是整块消失');
      expect(find.text('连接中...'), findsNothing,
          reason: '已连接且无在途刷新 → 不应再显示「获取列表...」');
    });

    testWidgets('从未拉过（idle）+ 非局域网 → 不显示徽章', (WidgetTester tester) async {
      Get.put(ThemeController(), permanent: true);
      await pumpPage(tester);

      final ServerController sc = Get.find<ServerController>();
      sc.servers.assignAll(<ServerData>[trSrv()]);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('公网'), findsNothing);
      expect(find.text('连接中...'), findsNothing);
    });
  });
}
