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
import 'package:torrent_manager/pages/torrent_info_overview_page.dart';
import 'package:torrent_manager/pages/torrent_list_page.dart';
import 'package:torrent_manager/utils/formatter.dart';
import 'package:torrent_manager/utils/strings.dart';
import 'package:torrent_manager/widgets/slidable_tile.dart';

ServerData qbSrv() => ServerData(
      id: 'qb-1',
      name: '家庭 NAS',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'admin',
      password: 'adminadmin',
    );

Torrent mkTorrent({
  required String hash,
  String name = '同名资源',
  String state = 'downloading',
  String? comment,
  int size = 1000000,
  double ratio = 2.31,
  int numComplete = 0,
  int numIncomplete = 0,
  int uploaded = 0,
  int downloaded = 0,

  String? savePath,
}) =>
    Torrent(
      hash: hash,
      name: name,
      size: size,
      progress: 0.5,
      state: state,
      dlSpeed: 0,
      upSpeed: 0,
      numSeeds: 12,
      numLeechs: 3,
      ratio: ratio,
      comment: comment,
      numComplete: numComplete,
      numIncomplete: numIncomplete,
      uploaded: uploaded,
      downloaded: downloaded,
      savePath: savePath,
    );

Map<String, dynamic> qbTorrentJson({
  String hash = 'h1',
  String state = 'downloading',
}) =>
    <String, dynamic>{
      'hash': hash,
      'name': '示例种子',
      'size': 10000000,
      'progress': 0.5,
      'state': state,
      'dlspeed': 0,
      'upspeed': 0,
      'num_seeds': 12,
      'num_leechs': 3,
      'ratio': 2.31,
      'downloaded': 300000000,
      'uploaded': 120000000,
      'num_complete': 88,
      'num_incomplete': 7,
    };

Dio fakeQbDio(
  List<String> calls, {
  String version = 'v4.6.2',
  bool pauseOk = true,
  bool stopOk = true,
  List<Map<String, dynamic>> Function()? torrents,
}) {
  final Dio dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.1.10:8080',
    validateStatus: (int? s) => s != null && s < 500,
    followRedirects: false,
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      final String path = o.uri.path;
      calls.add('${o.method} $path');

      Response<dynamic> ok(Object? data) =>
          Response<dynamic>(requestOptions: o, statusCode: 200, data: data);
      Response<dynamic> no(int code) =>
          Response<dynamic>(requestOptions: o, statusCode: code, data: '');

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
        h.resolve(ok(version));
        return;
      }
      if (path.endsWith('/app/webapiVersion')) {
        h.resolve(ok('2.11.2'));
        return;
      }
      if (path.endsWith('/torrents/info')) {
        h.resolve(ok(torrents?.call() ?? <Map<String, dynamic>>[]));
        return;
      }
      if (path.endsWith('/sync/maindata')) {
        h.resolve(ok(<String, dynamic>{
          'rid': 1,
          'server_state': <String, dynamic>{},
        }));
        return;
      }

      if (path.endsWith('/torrents/pause') || path.endsWith('/torrents/resume')) {
        h.resolve(pauseOk ? ok('') : no(404));
        return;
      }
      if (path.endsWith('/torrents/stop') || path.endsWith('/torrents/start')) {
        h.resolve(stopOk ? ok('') : no(404));
        return;
      }
      h.resolve(ok(''));
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

  Future<TorrentController> pumpListPage(
    WidgetTester tester, {
    required List<String> calls,
    String version = 'v4.6.2',
    bool pauseOk = true,
    bool stopOk = true,
    List<Map<String, dynamic>> Function()? torrents,
    List<Torrent>? items,
  }) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ServerController sc = Get.put(ServerController(
      qb: QbMethod(
        dio: fakeQbDio(
          calls,
          version: version,
          pauseOk: pauseOk,
          stopOk: stopOk,
          torrents: torrents,
        ),
      ),
    ));
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
    ctrl.items.assignAll(items ?? <Torrent>[Torrent.fromJson(qbTorrentJson())]);
    await tester.pump(const Duration(milliseconds: 50));
    return ctrl;
  }

  Future<void> swipe(WidgetTester tester, double dx) async {
    await tester.drag(find.byType(SlidableTile).first, Offset(dx, 0));
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> settle(WidgetTester tester, [int frames = 24]) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('① 查询辅种弹层信息', () {
    testWidgets('★ 每行显示站点（主域名）+ 做种人数 + 上传下载量',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];

      final Torrent me = mkTorrent(
        hash: 'h1',
        name: '同名资源',
        comment: 'https://hdcity.com/details.php?id=1',
        numComplete: 12,
        numIncomplete: 2,
        savePath: '/dl/同名资源',
      );
      final Torrent sub = mkTorrent(
        hash: 'h2',
        name: '同名资源',
        comment: 'https://hdsky.me/details.php?id=2',
        state: 'seeding',
        numComplete: 88,
        numIncomplete: 7,
        uploaded: 120000000,
        downloaded: 300000000,
        savePath: '/dl/同名资源',
      );
      await pumpListPage(
        tester,
        calls: calls,
        items: <Torrent>[me, sub],
      );

      await swipe(tester, 600);
      await tester.tap(
        find
            .descendant(
              of: find.byType(SlidableTile),
              matching: find.byIcon(Icons.search),
            )
            .first,
      );
      await settle(tester);

      expect(find.textContaining(S.querySubTorrents), findsOneWidget,
          reason: '★ 弹层标题应带条目数');

      Finder inSheet(Finder f) =>
          find.descendant(of: find.byType(ListTile), matching: f);

      final List<Text> lines =
          tester.widgetList<Text>(inSheet(find.byType(Text))).toList();
      expect(lines.length, 3, reason: '★ 每行只允许两行小字（外加标题的种子名）');
      final String row1 = lines[1].data ?? '';
      final String row2 = lines[2].data ?? '';

      expect(row1, contains(S.fieldSiteShort), reason: '★ 简写字段名「站点」');
      expect(row1, contains('hdsky.me'),
          reason: '★ 辅种行必须显示站点主域名（用户点名要的信息）');
      expect(row1, isNot(contains('h***')),
          reason: '★ 本页不打码：打码后就白列了，用户看不出是哪个站');
      expect(row1, isNot(contains('hdcity.com')),
          reason: '★ 列表里只列**其它**辅种，当前这条不该出现');

      expect(row1, contains(S.fieldSeeders), reason: '★ 做种人数与站点同行');
      expect(row1, contains('88/7'),
          reason: '★ 人数口径与卡片一致（`做种/下载(连接)`）');
      expect(row1, contains(Formatter.setStatus('seeding')),
          reason: '★ 种子状态与站点同行');

      expect(row2, contains(S.fieldRatioShort), reason: '★ 分享率（简写）');
      expect(row2, contains(S.fieldUpShort), reason: '★ 上传量（简写）');
      expect(row2, contains(S.fieldDlShort), reason: '★ 下载量（简写）');
      expect(row2, isNot(contains('hdsky.me')), reason: '★ 站点只在第一行');
      expect(row2, isNot(contains(Formatter.setStatus('seeding'))),
          reason: '★ 状态只在第一行');

      expect(inSheet(find.textContaining(S.fieldUploaded)), findsNothing,
          reason: '★ 「上传总量」已简写为「上传」');
      expect(inSheet(find.textContaining(S.fieldDownloaded)), findsNothing,
          reason: '★ 「下载总量」已简写为「下载」');
    });
  });

  group('② 暂停 / 继续端点按 qB 版本自适应', () {
    test('★ 版本号解析', () {
      expect(QbMethod.qbMajorOf('v4.6.2'), 4);
      expect(QbMethod.qbMajorOf('5.0.5'), 5);
      expect(QbMethod.qbMajorOf('v5.1.0beta1'), 5);
      expect(QbMethod.qbMajorOf(''), 0);
      expect(QbMethod.qbMajorOf('乱七八糟'), 0);
      expect(QbMethod.isApiV5Version('v4.6.2'), isFalse);
      expect(QbMethod.isApiV5Version('v5.0.5'), isTrue);
    });

    testWidgets('★ qB 4.x：左滑暂停打到 `/torrents/pause`，且不碰新端点',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];
      await pumpListPage(tester, calls: calls, version: 'v4.6.2');
      await swipe(tester, -600);

      calls.clear();
      await tester.tap(find.descendant(
        of: find.byType(SlidableTile),
        matching: find.byIcon(Icons.pause),
      ));
      await settle(tester);

      expect(calls.where((String c) => c.contains('/torrents/pause')).length, 1,
          reason: '★ qB 4.x 必须走老端点 `pause`');
      expect(calls.where((String c) => c.contains('/torrents/stop')).length, 0,
          reason: '★ 不该白打一笔新端点');
    });

    testWidgets('★ qB 5.x：左滑暂停打到 `/torrents/stop`（旧端点已删除）',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];
      await pumpListPage(tester, calls: calls, version: 'v5.0.5');
      await swipe(tester, -600);

      calls.clear();
      await tester.tap(find.descendant(
        of: find.byType(SlidableTile),
        matching: find.byIcon(Icons.pause),
      ));
      await settle(tester);

      expect(calls.where((String c) => c.contains('/torrents/stop')).length, 1,
          reason: '★ qB 5.x 必须走 `stop` —— 这是「点了没反应」的根因所在');
      expect(
          calls.where((String c) => c.contains('/torrents/pause')).length, 0,
          reason: '★ 不该先打一笔注定 404 的老端点（那正是线上症状）');
    });

    testWidgets('★ 探测不准时用 404 反推换端点，并把结论写回（第二笔不再试错）',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];

      await pumpListPage(
        tester,
        calls: calls,
        version: 'v4.6.2',
        pauseOk: false,
        stopOk: true,

        torrents: () => <Map<String, dynamic>>[qbTorrentJson()],
      );
      await swipe(tester, -600);

      calls.clear();
      await tester.tap(find.descendant(
        of: find.byType(SlidableTile),
        matching: find.byIcon(Icons.pause),
      ));
      await settle(tester);
      expect(calls.where((String c) => c.contains('/torrents/pause')).length, 1,
          reason: '先按版本判定的老端点试一笔');
      expect(calls.where((String c) => c.contains('/torrents/stop')).length, 1,
          reason: '★ 404 后必须自动换新端点重试');

      final TorrentController tc = Get.find<TorrentController>();
      tc.items.value = tc.items
          .map((Torrent x) =>
              x.updateQbData(<String, dynamic>{'state': 'downloading'}))
          .toList();
      await tester.pump();

      calls.clear();
      await swipe(tester, -600); 
      await tester.tap(find.descendant(
        of: find.byType(SlidableTile),
        matching: find.byIcon(Icons.pause),
      ));
      await settle(tester);
      expect(
          calls.where((String c) => c.contains('/torrents/pause')).length, 0,
          reason: '★ 结论要写回：第二笔不该再打老端点');
      expect(calls.where((String c) => c.contains('/torrents/stop')).length, 1);
    });

    testWidgets('★ 两个端点都不认 → 不再静默：界面上必须给出错误',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];
      final TorrentController ctrl = await pumpListPage(
        tester,
        calls: calls,
        version: 'v4.6.2',
        pauseOk: false,
        stopOk: false,
      );
      await swipe(tester, -600);

      await tester.tap(find.descendant(
        of: find.byType(SlidableTile),
        matching: find.byIcon(Icons.pause),
      ));
      await settle(tester);

      expect(ctrl.error.value, isNotNull,
          reason: '★ 写操作 4xx 必须冒泡成错误，不能再"静默成功"');
      expect(ctrl.error.value, contains('404'));
    });
  });

  group('③ 暂停生效后的界面反馈', () {
    testWidgets('★ 列表卡片：暂停后按钮翻转为 `play_arrow`（绿色开始）',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];
      bool paused = false;
      final TorrentController ctrl = await pumpListPage(
        tester,
        calls: calls,
        version: 'v5.0.5',
        torrents: () => <Map<String, dynamic>>[
          qbTorrentJson(state: paused ? 'stoppedDL' : 'downloading'),
        ],
      );
      await swipe(tester, -600);
      expect(
        find.descendant(
            of: find.byType(SlidableTile), matching: find.byIcon(Icons.pause)),
        findsOneWidget,
        reason: '前置：未暂停时左滑按钮是橙色「暂停」',
      );

      paused = true;
      await tester.tap(find.descendant(
        of: find.byType(SlidableTile),
        matching: find.byIcon(Icons.pause),
      ));
      await settle(tester);

      expect(ctrl.items.first.state, 'stoppedDL',
          reason: '刷新后列表拿到的是 qB 5.x 的 `stoppedDL`');
      expect(ctrl.items.first.isPause, isTrue,
          reason: '★ `isPause` 必须认得 `stoppedDL`（5.x 的状态串）');
      await swipe(tester, -600);
      expect(
        find.descendant(
            of: find.byType(SlidableTile),
            matching: find.byIcon(Icons.play_arrow)),
        findsOneWidget,
        reason: '★ 暂停生效后按钮必须翻转成绿色「开始」',
      );
    });

    testWidgets('★ 详情页：点「暂停」打到正确端点，且状态回写进 current',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final List<String> calls = <String>[];
      bool paused = false;
      final ServerController sc = Get.put(ServerController(
        qb: QbMethod(
          dio: fakeQbDio(
            calls,
            version: 'v5.0.5',
            torrents: () => <Map<String, dynamic>>[
              qbTorrentJson(state: paused ? 'stoppedDL' : 'downloading'),
            ],
          ),
        ),
      ));
      Get.put(ThemeController(), permanent: true);
      final ServerData srv = qbSrv();
      sc.servers.assignAll(<ServerData>[srv]);

      await tester.pumpWidget(GetMaterialApp(
        initialBinding: AppBinding(),
        home: const Scaffold(body: TorrentInfoOverviewPage()),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      sc.select(srv);
      await tester.pump(const Duration(milliseconds: 50));

      final TorrentController ctrl = Get.find<TorrentController>();
      final Torrent t = Torrent.fromJson(qbTorrentJson());
      ctrl.items.assignAll(<Torrent>[t]);
      ctrl.current.value = t;
      await tester.pump(const Duration(milliseconds: 50));

      calls.clear();
      paused = true;
      await tester.tap(find.text('暂停'));
      await settle(tester);

      expect(calls.where((String c) => c.contains('/torrents/stop')).length, 1,
          reason: '★ 详情页的暂停与卡片走同一条链路，端点必须同样自适应');
      expect(ctrl.current.value?.state, 'stoppedDL',
          reason: '★ 详情页必须跟着刷新后的 `items` 回写 `current`'
              '（否则界面停在"打开详情那一刻"的快照，看着就像没生效）');
    });
  });

  group('④ qB 5.x 状态串 `stopped*`', () {
    test('★ 文案 / 图标 / 颜色都要认 `stoppedDL` `stoppedUP`', () {
      expect(Formatter.setStatus('stoppedDL'), S.stPausedDl,
          reason: '★ 不认的话 5.x 上暂停的种子会显示成「下载中」');
      expect(Formatter.setStatus('stoppedUP'), S.stPausedUp,
          reason: '★ 不认的话会显示成「做种中」');
      expect(Formatter.statusIcon('stoppedDL'), Icons.pause);
      expect(Formatter.statusIcon('stoppedUP'), Icons.pause);

      expect(Formatter.setStatus('pausedDL'), S.stPausedDl);
      expect(Formatter.setStatus('pausedUP'), S.stPausedUp);
      expect(Formatter.statusIcon('pausedDL'), Icons.pause);

      expect(Formatter.setStatus('stopped'), S.stPaused);
      expect(Formatter.statusIcon('stopped'), Icons.pause);

      expect(Formatter.statusIcon('downloading'), Icons.arrow_circle_down);
      expect(Formatter.statusIcon('uploading'), Icons.arrow_circle_up);
    });
  });
}
