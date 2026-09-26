import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/pages/server_list_page.dart';
import 'package:torrent_manager/pages/torrent_list_page.dart';
import 'package:torrent_manager/utils/formatter.dart';
import 'package:torrent_manager/utils/strings.dart';
import 'package:torrent_manager/widgets/disk_io_chip.dart';
import 'package:torrent_manager/widgets/io_chip.dart';

ServerData trSrv() => ServerData(
      id: 'tr-1',
      name: 'TR',
      type: 'transmission',
      host: '192.168.1.9',
      port: 9091,
    );

ServerData qbSrv() => ServerData(
      id: 'qb-1',
      name: '家庭 NAS',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
    );

Dio fakeTrDio({void Function()? onCall, bool fail = false}) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://192.168.1.9:9091'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      onCall?.call();
      if (fail) {
        h.reject(DioException(
          requestOptions: o,
          type: DioExceptionType.connectionTimeout,
          error: '模拟取版本号失败',
        ));
        return;
      }

      String method = '';
      final dynamic d = o.data;
      if (d is String) {
        try {
          final dynamic m = jsonDecode(d);
          if (m is Map) method = (m['method'] ?? '').toString();
        } catch (_) {
        }
      } else if (d is Map) {
        method = (d['method'] ?? '').toString();
      }
      h.resolve(Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: <String, dynamic>{
          'result': 'success',
          'arguments': method == 'torrent-get'
              ? <String, dynamic>{'torrents': <dynamic>[]}
              : <String, dynamic>{'version': '4.0.5'},
        },
      ));
    },
  ));
  return dio;
}

Torrent sampleTorrent() => const Torrent(
      hash: 'h1',
      name: '示例种子',
      size: 10000000,
      progress: 0.5,
      state: 'downloading',
      dlSpeed: 2048,
      upSpeed: 1024,
      numSeeds: 12,
      numLeechs: 3,
      ratio: 2.31,
      downloaded: 300000000,
      uploaded: 120000000,
    );

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

  group('① 版本号（qB `/api/v2/app/version` / TR `session-get.version`）', () {
    test('★ 取一次即缓存，后续调用不再发请求', () async {
      int calls = 0;
      final ServerData s = trSrv();
      final ServerController sc = Get.put(
          ServerController(tr: TrMethod(dio: fakeTrDio(onCall: () => calls++))));
      sc.servers.assignAll(<ServerData>[s]);

      await sc.ensureVersion(s);
      expect(sc.serverVersion[s.id], '4.0.5', reason: '应解析出 session-get 的 version');
      final int afterFirst = calls;
      expect(afterFirst, greaterThan(0), reason: '第一次必须真的去取');

      await sc.ensureVersion(s);
      await sc.ensureVersion(s);
      expect(calls, afterFirst,
          reason: '★ 已有缓存 → 绝不能再发请求'
              '（版本号是静态信息，进了 3 秒轮询就是纯浪费）');
    });

    test('★ 并发调用只发一笔（同一台在飞时短路）', () async {
      int calls = 0;
      final ServerData s = trSrv();
      final ServerController sc = Get.put(
          ServerController(tr: TrMethod(dio: fakeTrDio(onCall: () => calls++))));
      sc.servers.assignAll(<ServerData>[s]);

      await Future.wait(<Future<void>>[
        sc.ensureVersion(s),
        sc.ensureVersion(s),
        sc.ensureVersion(s),
      ]);
      expect(calls, 1, reason: '★ 三笔并发只应发一笔（`_versionInFlight` 短路）');
      expect(sc.serverVersion[s.id], '4.0.5');
    });

    test('★ 取不到版本号时不写缓存、也不抛异常（绝不能影响连接）', () async {
      final ServerData s = trSrv();
      final ServerController sc = Get.put(
          ServerController(tr: TrMethod(dio: fakeTrDio(fail: true))));
      sc.servers.assignAll(<ServerData>[s]);

      await sc.ensureVersion(s);
      expect(sc.serverVersion[s.id], isNull, reason: '失败不写缓存，下次连上还会再试');
    });

    test('★ 删除服务器会清掉版本号缓存（否则删掉再加同一台会显示旧版本）',
        () async {
      final ServerData s = trSrv();
      final ServerController sc =
          Get.put(ServerController(tr: TrMethod(dio: fakeTrDio())));
      sc.servers.assignAll(<ServerData>[s]);
      await sc.ensureVersion(s);
      expect(sc.serverVersion[s.id], isNotNull);

      await sc.deleteServer(s.id);
      expect(sc.serverVersion[s.id], isNull,
          reason: '★ 运行时状态要跟着服务器一起清（与 connStatus 同一个坑）');
    });
  });

  group('② 服务器卡片', () {
    Future<void> pumpServerPage(WidgetTester tester) async {
      Get.put(ThemeController(), permanent: true);
      await tester.pumpWidget(GetMaterialApp(
        home: const ServerListPage(),
        initialBinding: AppBinding(),
      ));
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('★ 显示版本号芯片（形如 `qB 4.6.2`）', (WidgetTester tester) async {
      await pumpServerPage(tester);
      final ServerController sc = Get.find<ServerController>();
      final ServerData s = qbSrv();
      sc.servers.assignAll(<ServerData>[s]);

      sc.reportConnected(s.id);
      sc.serverVersion[s.id] = '4.6.2';
      sc.serverVersion.refresh();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('qB 4.6.2'), findsOneWidget,
          reason: '★ 服务器卡片必须显示当前服务器版本信息');
    });

    testWidgets('★ 统计区四列两行：同行标签 dy 必须完全一致（横竖对齐）',
        (WidgetTester tester) async {
      await pumpServerPage(tester);
      final ServerController sc = Get.find<ServerController>();
      final ServerData s = qbSrv();
      sc.servers.assignAll(<ServerData>[s]);
      sc.reportConnected(s.id);

      sc.cacheTorrents(s.id, <Torrent>[sampleTorrent()]);
      await tester.pump(const Duration(milliseconds: 50));

      const List<String> row1 = <String>['种子数量', '下载中', '做种', '上传中'];
      const List<String> row2 = <String>['暂停下载', '暂停上传', '校验状态', '错误'];

      Finder label(String l) => find.descendant(
            of: find.byType(Card),
            matching: find.byWidgetPredicate((Widget w) =>
                w is Text &&
                (w.data?.startsWith(l) ??
                    (w.textSpan?.toPlainText().startsWith(l) ?? false))),
          );

      for (final String l in <String>[...row1, ...row2]) {
        expect(label(l), findsWidgets, reason: '统计网格缺少「$l」');
      }

      final double y1 = tester.getTopLeft(label(row1.first).first).dy;
      for (final String l in row1.skip(1)) {
        expect(tester.getTopLeft(label(l).first).dy, y1,
            reason: '★ 第一行「$l」没有与同行对齐（说明又退回了 Wrap 流式排列）');
      }
      final double y2 = tester.getTopLeft(label(row2.first).first).dy;
      for (final String l in row2.skip(1)) {
        expect(tester.getTopLeft(label(l).first).dy, y2,
            reason: '★ 第二行「$l」没有与同行对齐');
      }
      expect(y2, greaterThan(y1), reason: '第二行应在第一行下方');
    });

    testWidgets('★ 速度行已并入总计卡速度带（第 75 轮）：卡片只留磁盘 I/O 芯片',
        (WidgetTester tester) async {
      await pumpServerPage(tester);
      final ServerController sc = Get.find<ServerController>();
      final ServerData s = qbSrv();
      sc.servers.assignAll(<ServerData>[s]);
      sc.reportConnected(s.id);
      sc.cacheTorrents(s.id, <Torrent>[sampleTorrent()]);

      sc.ioJobs[s.id] = 37;
      sc.ioJobs.refresh();
      await tester.pump(const Duration(milliseconds: 50));

      final String up = Formatter.setSpeed(1024);
      final String down = Formatter.setSpeed(2048);

      Finder cardSpeed(String s) => find.byWidgetPredicate((Widget w) =>
          w is Text && w.data == s && w.style?.fontSize == 10);

      expect(cardSpeed(up), findsNothing, reason: '卡片速度行应已移除');
      expect(cardSpeed(down), findsNothing, reason: '卡片速度行应已移除');

      expect(find.byType(IoChip), findsOneWidget,
          reason: '★ 需求 4：qBittorrent 服务器卡片要有磁盘 I/O 数');
      expect(find.text('I/O: 37'), findsOneWidget,
          reason: '★ 需求 4：I/O 芯片显示的必须是 `queued_io_jobs` 的原值');
    });

    testWidgets('★ 需求 4：Transmission 卡片**隐藏** I/O 格（TR 无此字段）',
        (WidgetTester tester) async {
      await pumpServerPage(tester);
      final ServerController sc = Get.find<ServerController>();
      final ServerData s = trSrv();
      sc.servers.assignAll(<ServerData>[s]);
      sc.reportConnected(s.id);
      sc.cacheTorrents(s.id, <Torrent>[sampleTorrent()]);

      sc.ioJobs[s.id] = 5;
      sc.ioJobs.refresh();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(IoChip), findsNothing,
          reason: '★ 需求 4：Transmission 没有 queued_io_jobs → 该格必须隐藏，'
              '不能编一个数字出来');
      expect(find.byType(DiskIoChip), findsNothing,
          reason: '★ 服务器卡片已不再显示「磁盘读写量」');
    });
  });

  group('③ 种子卡片', () {
    testWidgets('★ 上传在前、下载在后（v2：方向走图标），流量行含磁盘读写芯片',
        (WidgetTester tester) async {
      Get.put(ThemeController(), permanent: true);
      await tester.pumpWidget(GetMaterialApp(
        home: const TorrentListPage(),
        initialBinding: AppBinding(),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final TorrentController ctrl = Get.find<TorrentController>();
      final Torrent t = sampleTorrent();
      ctrl.items.assignAll(<Torrent>[t]);
      await tester.pump(const Duration(milliseconds: 200));

      final String up = Formatter.setSpeed(t.newUpspeed);
      final String down = Formatter.setSpeed(t.newDownSpeed);
      expect(find.text(up), findsOneWidget,
          reason: 'v2：箭头改为 Icon，速度文本不再带 ▲/▼ 前缀');
      expect(find.text(down), findsOneWidget);
      expect(tester.getTopLeft(find.text(up)).dx,
          lessThan(tester.getTopLeft(find.text(down)).dx),
          reason: '★ 需求 3：种子卡片同样「上传在前、下载在后」');

      expect(find.byType(DiskIoChip), findsOneWidget,
          reason: '★ 需求 4：磁盘读写芯片仍在卡上（v2 在流量行右端）');

      expect(
        tester.getTopLeft(find.byType(DiskIoChip)).dy,
        greaterThan(tester.getTopLeft(find.text(up)).dy),
        reason: '★ 需求 4：芯片在速度行的**下方**（紧随速度之后）',
      );
    });
  });

  group('④ 磁盘读写芯片口径', () {
    testWidgets('★ 文案为「上传：X · 下载：Y」，上传取 uploaded、下载取 downloaded',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: DiskIoChip(written: 300000000, read: 120000000),
        ),
      ));

      final String expectText = '${S.ioUploadPrefix}'
          '${Formatter.setSize(120000000)}'
          ' · ${S.ioDownloadPrefix}${Formatter.setSize(300000000)}';
      expect(find.text(expectText), findsOneWidget,
          reason: '★ 上传 = uploaded（从磁盘读出）、下载 = downloaded（落地磁盘）；'
              '两张卡片共用本组件，口径不得各写一套');
    });
  });
}
