import 'dart:async';
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
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/pages/torrent_list_page.dart';
import 'package:torrent_manager/utils/formatter.dart';

Torrent _t(
  String hash, {
  String name = '资源',
  int size = 500,
  String state = 'seeding',
  String? dir,
}) =>
    Torrent(
      hash: hash,
      name: name,
      size: size,
      progress: 0.5,
      state: state,
      dlSpeed: 0,
      upSpeed: 0,
      numSeeds: 0,
      numLeechs: 0,
      ratio: 0,
      savePath: dir,
    );

ServerData qbSrv() => ServerData(
      id: 'qb-1',
      name: 'QB',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'admin',
      password: 'pw',
    );

Dio fakeQb(List<String> calls, {String? rawBody}) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://192.168.1.10:8080'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      final String p = o.uri.path;
      calls.add('${o.method} ${o.uri}');
      Response<dynamic> ok(Object? data) =>
          Response<dynamic>(requestOptions: o, statusCode: 200, data: data);
      if (p.endsWith('/auth/login')) {
        h.resolve(ok('Ok.'));
      } else if (p.endsWith('/app/version')) {
        h.resolve(ok('v4.6.2'));
      } else if (p.endsWith('/app/webapiVersion')) {
        h.resolve(ok('2.11.2'));
      } else if (p.endsWith('/torrents/info')) {
        h.resolve(ok(rawBody ?? <Map<String, dynamic>>[]));
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
  return dio;
}

String bigTorrentJson(int n) {
  final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  for (int i = 0; i < n; i++) {
    rows.add(<String, dynamic>{
      'hash': 'h$i',
      'name': 'seed-$i-${'x' * 80}',
      'size': 1024 * (i + 1),
      'progress': 0.5,
      'state': 'downloading',
      'dlspeed': 0,
      'upspeed': 0,
      'num_seeds': 1,
      'num_leechs': 2,
      'ratio': 0.5,
      'uploaded': 1,
      'downloaded': 2,
      'save_path': '/dl/seed-$i',
      'category': 'cat',
      'tags': 'tag',
    });
  }
  return jsonEncode(rows);
}

Future<TorrentController> pumpList(
  WidgetTester tester, {
  List<Torrent>? items,
}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final ServerController sc =
      Get.put(ServerController(qb: QbMethod(dio: fakeQb(<String>[]))));
  Get.put(ThemeController(), permanent: true);
  final ServerData srv = qbSrv();
  sc.servers.assignAll(<ServerData>[srv]);

  await tester.pumpWidget(GetMaterialApp(
    home: const TorrentListPage(),
    initialBinding: AppBinding(),
  ));
  await tester.pump(const Duration(milliseconds: 50));
  sc.select(srv);
  await tester.pump(const Duration(milliseconds: 50));

  final TorrentController ctrl = Get.find<TorrentController>();
  ctrl.debugSetItems(items ?? <Torrent>[_t('h1', name: '资源一', dir: '/dl')]);
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return ctrl;
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

  tearDown(Get.reset);

  group('① A1 visibleItems 结果缓存', () {
    TorrentController newCtl() {
      Get.put(ServerController(qb: QbMethod(dio: fakeQb(<String>[]))));
      return TorrentController();
    }

    test('★ 输入没变 → 复用同一份结果（修复前每读一次就全量过滤+排序）', () {
      final TorrentController tc = newCtl();
      tc.debugSetItems(<Torrent>[_t('a'), _t('b'), _t('c')]);

      final List<Torrent> first = tc.visibleItems;
      final List<Torrent> second = tc.visibleItems;
      expect(identical(first, second), isTrue,
          reason: '指纹未变 → 必须命中缓存，不能再算一遍');
      expect(first.length, 3);
    });

    test('★ 整表替换（数据版本 +1）→ 缓存失效并重算', () {
      final TorrentController tc = newCtl();
      tc.debugSetItems(<Torrent>[_t('a')]);
      final List<Torrent> first = tc.visibleItems;
      expect(first.length, 1);

      tc.debugSetItems(<Torrent>[_t('a'), _t('b')]);
      final List<Torrent> second = tc.visibleItems;
      expect(identical(first, second), isFalse,
          reason: '★ 数据换了却复用旧缓存 = 列表永远不更新');
      expect(second.length, 2);
    });

    test('★ 改关键词 → 缓存失效（否则搜索框打了字列表不动）', () {
      final TorrentController tc = newCtl();
      tc.debugSetItems(
          <Torrent>[_t('a', name: '电影A'), _t('b', name: '剧集B')]);
      final List<Torrent> first = tc.visibleItems;

      tc.keyword.value = '剧集';
      final List<Torrent> second = tc.visibleItems;
      expect(identical(first, second), isFalse);
      expect(second.length, 1);
      expect(second.single.name, '剧集B');
    });

    test('★ 改筛选集合（RxList 增删**不改引用**）→ 缓存仍要失效', () {
      final TorrentController tc = newCtl();
      tc.debugSetItems(<Torrent>[_t('a', dir: '/dl/电影')]);
      final List<Torrent> first = tc.visibleItems;

      tc.selPaths.add('/dl/音乐');
      final List<Torrent> second = tc.visibleItems;
      expect(identical(first, second), isFalse,
          reason: '★ 指纹必须含筛选集合的**内容**，不能只比引用');
      expect(second, isEmpty);
    });

    test('改排序方向 → 缓存失效', () {
      final TorrentController tc = newCtl();
      tc.debugSetItems(<Torrent>[_t('a', size: 10), _t('b', size: 99)]);
      final List<Torrent> first = tc.visibleItems;

      tc.sortDesc.value = false;
      final List<Torrent> second = tc.visibleItems;
      expect(identical(first, second), isFalse);
    });
  });

  group('② A4 滑动期间挂起自动刷新', () {
    test('★ 滑动中 refreshAuto 一个请求都不发（停下才发）', () async {
      final List<String> calls = <String>[];
      final ServerController sc =
          Get.put(ServerController(qb: QbMethod(dio: fakeQb(calls))));
      sc.servers.assignAll(<ServerData>[qbSrv()]);
      sc.select(qbSrv());
      final TorrentController tc = TorrentController();

      tc.setScrollPaused(true);
      await tc.refreshAuto();
      expect(calls, isEmpty,
          reason: '★ A4：滑动中不该取数 —— 整表替换会把滑动打断');

      tc.setScrollPaused(false);
      await tc.refreshAuto();
      expect(calls, isNotEmpty, reason: '停下后必须恢复取数（否则数据永远停更）');
    });

    test('手动下拉刷新不受滑动影响（用户主动要数据不能被挡）', () async {
      final List<String> calls = <String>[];
      final ServerController sc =
          Get.put(ServerController(qb: QbMethod(dio: fakeQb(calls))));
      sc.servers.assignAll(<ServerData>[qbSrv()]);
      sc.select(qbSrv());
      final TorrentController tc = TorrentController();

      tc.setScrollPaused(true);
      unawaited(tc.refresh());
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(calls, isNotEmpty, reason: '★ 只挡自动刷新 —— 下拉刷新仍要照发');
    });
  });

  group('③ 取消首屏分页（回到一笔全量）', () {
    test('★ 一次 refresh 只发一笔 /torrents/info，且不带 limit', () async {
      final List<String> calls = <String>[];
      final ServerController sc =
          Get.put(ServerController(qb: QbMethod(dio: fakeQb(calls))));
      sc.servers.assignAll(<ServerData>[qbSrv()]);
      sc.select(qbSrv());
      final TorrentController tc = TorrentController();

      await tc.refresh();

      final Iterable<String> info =
          calls.where((String c) => c.contains('/torrents/info'));
      expect(info.length, 1,
          reason: '★ 第 43 轮的「首屏 limit=30 + 后台拉全量」已取消 —— 只该有一笔');
      expect(info.single.contains('limit='), isFalse,
          reason: '★ 不再分页 ⇒ 请求里不该出现 limit 参数');
    });
  });

  group('④ B3 关掉 KeepAlive', () {
    testWidgets('★ 纵向列表的 KeepAlive 必须关掉（几万条时内存只增不减）',
        (WidgetTester tester) async {
      await pumpList(tester);

      final Iterable<SliverChildBuilderDelegate> delegates = tester
          .widgetList<SliverList>(find.byType(SliverList))
          .map((SliverList s) => s.delegate)
          .whereType<SliverChildBuilderDelegate>();
      expect(delegates, isNotEmpty, reason: '得找得到种子列表的 sliver');
      expect(
          delegates.any(
              (SliverChildBuilderDelegate d) => !d.addAutomaticKeepAlives),
          isTrue,
          reason: '★ 种子列表必须关掉 KeepAlive —— 几万条一路滑下来，'
              '否则滑出视口的行会一直保着 State，内存只增不减');
    });

    testWidgets('关掉 KeepAlive 后列表照样渲染得出种子',
        (WidgetTester tester) async {
      final TorrentController tc = await pumpList(tester);
      expect(tc.items.length, 1, reason: '★ 关 KeepAlive 不能把数据弄丢');
      expect(find.text('资源一'), findsWidgets);
    });
  });

  group('⑤ A5 大响应解析进 isolate', () {
    test('★ 超过阈值的大响应：解析结果正确（走 isolate 也与主线程一致）', () async {
      final String big = bigTorrentJson(1800);
      expect(big.length, greaterThan(QbMethod.kParseInIsolateBytes),
          reason: '构造的样本必须真的超过阈值，否则测的不是 isolate 分支');

      final List<String> calls = <String>[];
      final QbMethod qb = QbMethod(dio: fakeQb(calls, rawBody: big));

      final List<Torrent> list = await qb.getTorrentList();
      expect(list.length, 1800);
      expect(list.first.hash, 'h0');
      expect(list.last.hash, 'h1799');
      expect(list.first.savePath, '/dl/seed-0');
    });

    test('小响应仍在主线程解析（开 isolate 反而更慢），结果一致', () async {
      final List<String> calls = <String>[];
      final QbMethod qb = QbMethod(
        dio: fakeQb(calls,
            rawBody: jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{'hash': 'h1', 'name': '小库', 'size': 2048},
            ])),
      );
      final List<Torrent> list = await qb.getTorrentList();
      expect(list.length, 1);
      expect(list.single.hash, 'h1');
    });

    test('★ 已解码的响应（非 String）走回老路径 —— 行为与改动前一致', () async {
      final List<String> calls = <String>[];
      final QbMethod qb = QbMethod(dio: fakeQb(calls));
      final List<Torrent> list = await qb.getTorrentList();
      expect(list, isEmpty);
    });
  });

  group('⑥ B6 格式化结果缓存', () {
    List<String> sample() => <String>[
          Formatter.setSize(0),
          Formatter.setSize(1023),
          Formatter.setSize(1048576),
          Formatter.setSize(33285996544),
          Formatter.setSizeCompact(1048576),
          Formatter.setSpeed(0),
          Formatter.setSpeed(1048576),
          Formatter.setRatio(-1),
          Formatter.setRatio(1.23456),
          Formatter.setProgress(0.5),
          Formatter.setProgress(1.9),
          Formatter.statusIcon('downloading').codePoint.toString(),
          Formatter.statusIcon('stoppedDL').codePoint.toString(),
        ];

    test('★ 缓存不影响正确性：冷 / 热两遍逐项一致', () {
      Formatter.clearFormatCache();
      final List<String> cold = sample();
      final List<String> warm = sample();
      expect(warm, cold);
      expect(cold[2], '1.00 MB');
      expect(cold[3], '31.00 GB');
      expect(cold[8], '1.23');
      expect(cold[9], '50.0%');
      expect(cold[10], '100.0%');
    });

    test('★ setStatusColor 不缓存 Color —— 换一套配色立刻跟着变', () {
      Formatter.clearFormatCache();
      const ColorScheme light = ColorScheme.light();
      const ColorScheme dark = ColorScheme.dark();

      Formatter.setStatusColor('uploading', light);
      Formatter.setStatusColor('uploading', dark);
      expect(Formatter.setStatusColor('uploading', light), light.primary);
      expect(Formatter.setStatusColor('uploading', dark), dark.primary,
          reason: '★ 若把 Color 也缓存了，主题改色将永远不生效');
    });

    test('★ 写满容量后淘汰最旧的，结果依然正确（不会串值）', () {
      Formatter.clearFormatCache();
      const int n = Formatter.fmtCacheSize + 200;
      for (int i = 1; i <= n; i++) {
        expect(Formatter.setSize(i * 1024), isNotEmpty);
      }

      expect(Formatter.setSize(1024), '1.00 KB');
      expect(Formatter.setSize(1048576), '1.00 MB');
      expect(Formatter.setSize(0), '0 B');
    });
  });

  group('⑦ C1 搜索关键词防抖', () {
    List<Torrent> two() => <Torrent>[
          _t('h1', name: '电影A', dir: '/dl'),
          _t('h2', name: '剧集B', dir: '/dl'),
        ];

    testWidgets('★ 敲字当帧不做全量过滤，220ms 后才落关键词',
        (WidgetTester tester) async {
      final TorrentController tc = await pumpList(tester, items: two());
      expect(tc.keyword.value, '');

      await tester.enterText(find.byType(TextField), '电');
      await tester.pump();
      expect(tc.keyword.value, '',
          reason: '★ 每敲一个字符就全量过滤一遍 = 搜索框打字一卡一卡');

      await tester.pump(const Duration(milliseconds: 300));
      expect(tc.keyword.value, '电', reason: '防抖窗口过后必须真的生效');
      expect(find.text('剧集B'), findsNothing);
      expect(find.text('电影A'), findsWidgets);
    });

    testWidgets('★ 连续输入只在最后一次触发（中间的按键被合并掉）',
        (WidgetTester tester) async {
      final TorrentController tc = await pumpList(tester, items: two());

      await tester.enterText(find.byType(TextField), '剧');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), '剧集');
      await tester.pump(const Duration(milliseconds: 100));

      expect(tc.keyword.value, '',
          reason: '★ 窗口内的中间态不该触发过滤 —— 这正是防抖的意义');

      await tester.pump(const Duration(milliseconds: 300));
      expect(tc.keyword.value, '剧集');
    });

    testWidgets('点清除按钮是"立刻清掉"，不走防抖', (WidgetTester tester) async {
      final TorrentController tc = await pumpList(tester, items: two());

      await tester.enterText(find.byType(TextField), '剧集');
      await tester.pump(const Duration(milliseconds: 300));
      expect(tc.keyword.value, '剧集');

      await tester.tap(find.byIcon(Icons.clear_all).first);
      await tester.pump();
      expect(tc.keyword.value, '',
          reason: '★ 清除是明确的即时动作 —— 不能等 220ms');
    });
  });
}
