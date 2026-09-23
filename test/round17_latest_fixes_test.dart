














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







Dio fakeQb({
  Map<String, dynamic> Function(int round)? serverState,
  List<Map<String, dynamic>>? torrents,
}) {
  int round = 0;
  final Dio dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      final String p = o.uri.path;
      if (p.contains('maindata')) {
        round++;
        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: <String, dynamic>{
            'rid': round,
            'server_state':
                serverState?.call(round) ?? <String, dynamic>{'rid_stub': 1},
            'torrents': <String, dynamic>{
              for (final Map<String, dynamic> t in torrents ?? const [])
                (t['hash'] ?? '').toString(): t,
            },
          },
        ));
        return;
      }
      if (p.contains('/torrents/info')) {
        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: torrents ?? <dynamic>[],
        ));
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

Map<String, dynamic> _torrent(String host) => <String, dynamic>{
      'hash': 'h_$host',
      'name': 'T-$host',
      'size': 1024,
      'progress': 0.5,
      'state': 'downloading',
      'upspeed': 512,
      'dlspeed': 10,
    };

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

  
  
  
  group('① 提示浮层位置（最新需求 1）', () {
    testWidgets('★ 提示落在屏幕**下半部分**，且仍在根 Overlay（不被遮挡）',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: AppToast.navigatorKey,
        home: const Scaffold(body: Center(child: Text('页面'))),
      ));
      await tester.pump();

      AppToast.show('底部提示');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260)); 

      final Finder toast = find.text('底部提示');
      expect(toast, findsOneWidget, reason: '★ 提示必须渲染出来');

      final Size screen =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      final Rect r = tester.getRect(toast);

      expect(r.center.dy, greaterThan(screen.height * 0.6),
          reason: '★ 需求 1：提示要浮在**屏幕底部上方**，'
              '而不是贴在页面上沿（那是上一版的实现，用户已明确否定）');
      expect(screen.height - r.bottom, lessThan(160),
          reason: '★ 提示应贴着底部（只留 SafeArea + margin 的间距）');

      
      expect(
        find.ancestor(of: toast, matching: find.byType(Overlay)),
        findsOneWidget,
        reason: '★ 位置改了，但"盖在所有页面/对话框之上"这条不能丢',
      );
      expect(
        find.ancestor(of: toast, matching: find.byType(Scaffold)),
        findsNothing,
        reason: '★ 提示不得是页面 Scaffold 的后代',
      );

      
      AppToast.resetForTest();
      await tester.pump();
    });
  });

  
  
  
  group('② 手动刷新动画（最新需求 2）', () {
    testWidgets('★ 点刷新按钮后**立刻**进入刷新态（showProgress 必须传 true）',
        (WidgetTester tester) async {
      Get.put(ThemeController(), permanent: true);
      await tester.pumpWidget(GetMaterialApp(
        home: const ServerListPage(),
        initialBinding: AppBinding(),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      final ServerController sc = Get.find<ServerController>();
      sc.qbFactory = () => QbMethod(dio: fakeQb(serverState: (_) => {'queued_io_jobs': 1}));
      sc.servers.assignAll(<ServerData>[qbSrv('a', '10.0.0.1')]);
      await tester.pump();

      
      
      final Finder spin = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(RotationTransition),
      );
      expect(spin, findsOneWidget);

      await tester.tap(spin);
      await tester.pump();

      
      expect(sc.isManualRefreshing, isTrue,
          reason: '★ 若调用处没传 `showProgress: true`，`manualRefreshing` 永远是'
              '空集 —— 刷新图标不转、卡片不进刷新态，整段动画形同虚设');

      
      
      
      
      
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 800));

      expect(sc.isManualRefreshing, isFalse, reason: '刷新结束后标记必须清干净');
      
      AppToast.resetForTest();
      await tester.pump();
    });

    test('★ 局域网毫秒级返回时，「刷新中」仍至少保留 700ms（否则动画看不见）',
        () async {
      final ServerController sc = Get.put(ServerController());
      sc.qbFactory = () =>
          QbMethod(dio: fakeQb(serverState: (_) => {'queued_io_jobs': 1}));
      sc.servers.assignAll(<ServerData>[qbSrv('a', '10.0.0.1')]);

      final Stopwatch sw = Stopwatch()..start();
      await sc.refreshAllServers(showProgress: true);
      final int ms = sw.elapsedMilliseconds;

      expect(sc.manualRefreshing, isEmpty, reason: '收工后标记必须清干净');
      expect(ms, greaterThanOrEqualTo(650),
          reason: '★ 假传输是瞬时返回的：没有「最短可见时长」的话这里只有几毫秒，'
              '真机上转圈一闪而过，用户根本看不出正在重新连接取数据');
    });
  });

  
  
  
  group('③ I/O 数链路（最新需求 3）', () {
    test('★ server_state 增量缺席 queued_io_jobs 时，保留上一轮的已知值', () async {
      final ServerController sc = Get.put(ServerController());
      sc.qbFactory = () => QbMethod(
            dio: fakeQb(
              
              serverState: (int round) => round == 1
                  ? <String, dynamic>{'queued_io_jobs': 7}
                  : <String, dynamic>{'up_info_speed': 100},
              torrents: <Map<String, dynamic>>[_torrent('10.0.0.1')],
            ),
          );
      final ServerData s = qbSrv('a', '10.0.0.1');
      sc.servers.assignAll(<ServerData>[s]);

      await sc.refreshAllServers();
      expect(sc.ioJobs['a'], 7, reason: '第 1 轮拿到了 7');

      await sc.refreshAllServers();
      expect(sc.ioJobs['a'], 7,
          reason: '★ 第 2 轮的增量没带 `queued_io_jobs` —— 必须保留 7。'
              '此前用 `ServerState.fromJson` 新建对象，会把它打回 0（永远是绿色）');
    });

    test('★ qB 不返回 queued_io_jobs 时**不写表** → 卡片隐藏该格（不编假的绿色 0）',
        () async {
      final ServerController sc = Get.put(ServerController());
      sc.qbFactory = () => QbMethod(
            dio: fakeQb(
              serverState: (_) => <String, dynamic>{'up_info_speed': 100},
              torrents: <Map<String, dynamic>>[_torrent('10.0.0.1')],
            ),
          );
      final ServerData s = qbSrv('a', '10.0.0.1');
      sc.servers.assignAll(<ServerData>[s]);

      await sc.refreshAllServers();
      expect(sc.connStatus['a'], ConnStatus.ok, reason: '连接本身是成功的');
      expect(sc.ioJobs.containsKey('a'), isFalse,
          reason: '★ 服务端没这个字段 → 不该写一个 0 进去。'
              '绿色的「I/O: 0」会被读成"磁盘空闲"，实际只是"没这个数据"');
    });

    test('★ qB 的全量 refresh() 也要取回 server_state（I/O 不再要等下一轮增量）',
        () async {
      final ServerController sc = Get.put(
        ServerController(
          qb: QbMethod(
            dio: fakeQb(
              serverState: (_) => <String, dynamic>{'queued_io_jobs': 23},
              torrents: <Map<String, dynamic>>[_torrent('10.0.0.1')],
            ),
          ),
        ),
      );
      final ServerData s = qbSrv('a', '10.0.0.1');
      sc.servers.assignAll(<ServerData>[s]);
      
      
      
      sc.current.value = s;
      final TorrentController tc = Get.put(TorrentController());

      
      
      
      tc.setListVisible(true);

      
      for (int i = 0; i < 60 && tc.items.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(tc.items, isNotEmpty, reason: '全量种子表应来自 /torrents/info');
      expect(sc.ioJobs['a'], 23,
          reason: '★ 全量这一拍就必须拿到 `server_state` —— 否则卡片上的「I/O」'
              '要等下一轮增量才冒出来，看起来就是"没跟其他组件同步"');
    });
  });
}
