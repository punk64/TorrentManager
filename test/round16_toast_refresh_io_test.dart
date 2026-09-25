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
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/pages/server_list_page.dart';
import 'package:torrent_manager/widgets/app_toast.dart';

ServerData qbSrv(String id, String host) => ServerData(
      id: id,
      name: 'NAS-$id',
      type: 'qbittorrent',
      host: host,
      port: 8080,
    );

ServerData trSrv() => ServerData(
      id: 'tr-1',
      name: 'TR',
      type: 'transmission',
      host: '192.168.1.9',
      port: 9091,
    );

Dio fakeQbDio({
  required int Function(String host) ioJobsFor,
  Completer<void>? gate,
  void Function(String host)? onMaindata,
}) {
  final Dio dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) async {
      final String host = o.uri.host;
      final String p = o.uri.path;
      if (p.contains('maindata')) {
        onMaindata?.call(host);
        if (gate != null) await gate.future;
        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: <String, dynamic>{
            'rid': 1,
            'server_state': <String, dynamic>{
              'queued_io_jobs': ioJobsFor(host),
            },
            'torrents': <String, dynamic>{
              'h_$host': <String, dynamic>{
                'name': 'T-$host',
                'size': 1024,
                'dlspeed': 10,
              },
            },
          },
        ));
        return;
      }
      if (p.contains('/app/version')) {
        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: '4.6.2',
        ));
        return;
      }
      if (p.contains('/app/webapiVersion')) {
        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: '2.11.2',
        ));
        return;
      }
      if (p.contains('/auth/login')) {
        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: 'Ok.',
        ));
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

Torrent tn(String hash, String name, {int size = 100, int dlSpeed = 0}) => Torrent(
      hash: hash,
      name: name,
      size: size,
      progress: 0.5,
      state: 'downloading',
      dlSpeed: dlSpeed,
      upSpeed: 0,
      numSeeds: 0,
      numLeechs: 0,
      ratio: 1,
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
    AppToast.resetForTest();
  });

  tearDown(AppToast.resetForTest);

  group('① 提示层（需求 1）', () {
    testWidgets('★ 提示挂在 Navigator 根 Overlay 上，不挂在页面 Scaffold 内',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: AppToast.navigatorKey,
        home: const Scaffold(body: Center(child: Text('页面'))),
      ));
      await tester.pump();

      AppToast.show('最上层提示');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final Finder toast = find.text('最上层提示');
      expect(toast, findsOneWidget, reason: '★ 提示必须渲染出来');
      expect(find.byType(SnackBar), findsNothing,
          reason: '★ 不能再退回 `ScaffoldMessenger` 的 SnackBar —— '
              '它挂在页面 Scaffold 之内，层级低于对话框/底部弹层，会被盖住');
      expect(
        find.ancestor(of: toast, matching: find.byType(Overlay)),
        findsOneWidget,
        reason: '★ 提示必须位于 Overlay（根浮层）里',
      );
      expect(
        find.ancestor(of: toast, matching: find.byType(Scaffold)),
        findsNothing,
        reason: '★ 提示**不得**是页面 Scaffold 的后代（那是旧实现的层级问题根源）',
      );

      AppToast.resetForTest();
      await tester.pump();
    });

    testWidgets('★ 对话框打开时提示依然可见（旧实现会被对话框盖住）',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: AppToast.navigatorKey,
        home: Builder(
          builder: (BuildContext ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: ctx,
                  builder: (_) => const AlertDialog(title: Text('确认删除')),
                ),
                child: const Text('打开对话框'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();
      expect(find.text('确认删除'), findsOneWidget);

      AppToast.show('已在最上层');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('已在最上层'), findsOneWidget,
          reason: '★ 对话框打开时提示也必须渲染');

      expect(
        find.ancestor(
            of: find.text('已在最上层'), matching: find.byType(AlertDialog)),
        findsNothing,
        reason: '★ 提示应该是压在对话框**之上**的独立浮层',
      );

      AppToast.resetForTest();
      await tester.pump();
    });

    testWidgets('★ 提示到点自动消失且不抛异常', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: AppToast.navigatorKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ));
      await tester.pump();
      AppToast.show('短提示');
      await tester.pump();
      expect(find.text('短提示'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();
      expect(find.text('短提示'), findsNothing, reason: '到点应自动消失');
    });
  });

  group('② refreshAllServers（需求 2 / 3）', () {
    test('★ 调用后**同一帧内**所有卡片一起进入「刷新中」；且请求是并发的',
        () async {
      final ServerData a = qbSrv('a', '10.0.0.1');
      final ServerData b = qbSrv('b', '10.0.0.2');
      final Completer<void> gate = Completer<void>();
      final List<String> reached = <String>[];

      final ServerController sc = Get.put(ServerController());

      sc.qbFactory = () => QbMethod(
            dio: fakeQbDio(
              ioJobsFor: (String h) => h == '10.0.0.1' ? 12 : 999,
              gate: gate,
              onMaindata: reached.add,
            ),
          );
      sc.servers.assignAll(<ServerData>[a, b]);

      final Future<void> run = sc.refreshAllServers(showProgress: true);

      expect(sc.manualRefreshing.containsAll(<String>['a', 'b']), isTrue,
          reason: '★ 需求 3：所有卡片必须**同步**进入刷新态，不能一张张先后点亮');
      expect(sc.manualRefreshing.length, 2);
      expect(sc.isManualRefreshing, isTrue);

      for (int i = 0; i < 40 && reached.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(reached.toSet(), <String>{'10.0.0.1', '10.0.0.2'},
          reason: '★ 需求 3：两台服务器的请求必须**并发**发出，'
              '而不是一台接一台串行（串行时这里只会有 1 个）');

      gate.complete();
      await run;

      expect(sc.manualRefreshing, isEmpty, reason: '刷新结束标记必须清干净');
      expect(sc.connStatus['a'], ConnStatus.ok);
      expect(sc.connStatus['b'], ConnStatus.ok);

      expect(sc.ioJobs['a'], 12);
      expect(sc.ioJobs['b'], 999);

      expect(sc.torrentsOf('a'), hasLength(1));
      expect(sc.torrentsOf('b'), hasLength(1));
      expect(sc.serverVersion['a'], '4.6.2');
      expect(sc.serverVersion['b'], '4.6.2');
    });

    test('★ Transmission 不写 ioJobs（TR 没有 queued_io_jobs 这个概念）',
        () async {
      final ServerController sc = Get.put(ServerController());
      final ServerData t = trSrv();
      sc.trFactory = () => TrMethod(dio: _fakeTrDio());
      sc.servers.assignAll(<ServerData>[t]);

      await sc.refreshAllServers();
      expect(sc.connStatus[t.id], ConnStatus.ok);
      expect(sc.ioJobs.containsKey(t.id), isFalse,
          reason: '★ 需求 4：TR 侧没有这个字段 → 卡片应隐藏该格，'
              '而不是编一个数字出来');
    });

    test('★ 单台失败不阻断其它服务器，且刷新标记不会残留', () async {
      final ServerData good = qbSrv('good', '10.0.0.7');
      final ServerData bad = qbSrv('bad', '10.0.0.8');
      final ServerController sc = Get.put(ServerController());
      int created = 0;

      sc.qbFactory = () {
        created++;
        return QbMethod(
          dio: created == 1
              ? fakeQbDio(ioJobsFor: (_) => 3)
              : _failingQbDio(),
        );
      };
      sc.servers.assignAll(<ServerData>[good, bad]);

      await sc.refreshAllServers(showProgress: true);

      expect(sc.connStatus['good'], ConnStatus.ok,
          reason: '★ 单台失败不得拖垮整批刷新');
      expect(sc.ioJobs['good'], 3);
      expect(sc.connStatus['bad'], ConnStatus.failed,
          reason: '失败的那台要如实上报「连接失败」，而不是静默');
      expect(sc.ioJobs.containsKey('bad'), isFalse,
          reason: '失败就没拿到数据 → 不该写一个假值进 ioJobs');
      expect(sc.manualRefreshing, isEmpty,
          reason: '★ 失败路径也必须把「刷新中」标记清干净，否则卡片永远转圈');
    });
  });

  group('③ mergeQbMaindata', () {
    test('全量：忽略旧快照（已删除的种子不得残留）', () {
      final List<Torrent> base = <Torrent>[tn('stale', '已被删掉的种子')];
      final List<Torrent> out = TorrentController.mergeQbMaindata(
        base,
        <String, dynamic>{
          'torrents': <String, dynamic>{
            'h1': <String, dynamic>{'name': 'T1', 'size': 100},
          },
        },
        full: true,
      );
      expect(out.map((Torrent t) => t.hash), <String>['h1']);
    });

    test('增量：逐字段合并，不支持整对象替换（否则每轮多一批空白卡片）', () {
      final List<Torrent> base = <Torrent>[tn('h1', 'T1', dlSpeed: 5)];
      final List<Torrent> out = TorrentController.mergeQbMaindata(
        base,
        <String, dynamic>{
          'torrents': <String, dynamic>{
            'h1': <String, dynamic>{'dlspeed': 999},
          },
        },
        full: false,
      );
      expect(out, hasLength(1));
      expect(out.first.name, 'T1', reason: '★ 增量里缺席的字段必须保留原值');
      expect(out.first.size, 100);
      expect(out.first.dlSpeed, 999, reason: '变动字段应被合并');
    });

    test('增量：缺 `name` 的残缺条目直接跳过（不生成空白卡片）', () {
      final List<Torrent> out = TorrentController.mergeQbMaindata(
        const <Torrent>[],
        <String, dynamic>{
          'torrents': <String, dynamic>{
            'h_broken': <String, dynamic>{'dlspeed': 1},
          },
        },
        full: false,
      );
      expect(out, isEmpty);
    });

    test('torrents_removed 里的种子必须被剔除', () {
      final List<Torrent> base = <Torrent>[
        tn('h1', 'T1'),
        tn('h2', 'T2'),
      ];
      final List<Torrent> out = TorrentController.mergeQbMaindata(
        base,
        <String, dynamic>{'torrents_removed': <dynamic>['h2']},
        full: false,
      );
      expect(out.map((Torrent t) => t.hash), <String>['h1']);
    });
  });

  group('④ 卡片刷新动画与 I/O 格', () {
    Future<void> pumpPage(WidgetTester tester) async {
      Get.put(ThemeController(), permanent: true);
      await tester.pumpWidget(GetMaterialApp(
        home: const ServerListPage(),
        initialBinding: AppBinding(),
      ));
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('★ 需求 3：刷新中的卡片清空数据改占位符；失败则维持占位符',
        (WidgetTester tester) async {
      await pumpPage(tester);
      final ServerController sc = Get.find<ServerController>();
      final ServerData a = qbSrv('a', '10.0.0.1');
      final ServerData b = qbSrv('b', '10.0.0.2');
      sc.servers.assignAll(<ServerData>[a, b]);

      sc.reportConnected('a');
      sc.cacheTorrents('a', <Torrent>[
        Torrent.fromJson(<String, dynamic>{
          'hash': 'h1', 'name': 'A', 'state': 'downloading', 'size': 100,
        }),
      ]);
      sc.torrentCache.refresh();
      sc.ioJobs['a'] = 42;
      sc.ioJobs.refresh();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('I/O: 42'), findsOneWidget);
      expect(find.byKey(const Key('serverStatsPlaceholder')), findsOneWidget,
          reason: '★ 第 53 轮：b 没有真实数据 → 骨架屏（与"是否在刷新"无关）');

      sc.manualRefreshing.addAll(<String>['a', 'b']);
      sc.manualRefreshing.refresh();
      await tester.pump();

      expect(find.byKey(const Key('serverStatsPlaceholder')), findsOneWidget,
          reason: '★ 第 41/53 轮：有真实数据就继续显示 —— 不能因为"在刷新"就清成骨架，'
              '用户抱怨的正是"每次进页面都空白两三秒"');

      expect(find.text('I/O: 42'), findsNothing,
          reason: '★ I/O 属于芯片行：刷新期间隐藏（与统计区是否保留无关）');

      expect(find.text('刷新中'), findsNWidgets(2));

      sc.manualRefreshing.clear();
      sc.manualRefreshing.refresh();
      sc.reportFailure('a', Exception('boom'));
      await tester.pump();
      expect(find.byKey(const Key('serverStatsPlaceholder')), findsNWidgets(2),
          reason: '★ a 失败占位 + b 骨架 = 2 块；失败时既不回填旧数据，也不编一排 0');
      expect(find.textContaining('刷新失败'), findsOneWidget,
          reason: '★ 刷新失败要给出明确的失败提示');

      sc.reportConnected('a');
      await tester.pump();
      expect(find.byKey(const Key('serverStatsPlaceholder')), findsOneWidget,
          reason: 'a 已恢复显示（种子数据还在），剩下 b 没有真实数据 → 骨架');
      expect(find.textContaining('刷新失败'), findsNothing);
      expect(find.text('I/O: 42'), findsOneWidget);
    });

    testWidgets('★ 第 41 轮：刷新中若有数据可显示则保留（不再清成骨架）',
        (WidgetTester tester) async {
      await pumpPage(tester);
      final ServerController sc = Get.find<ServerController>();
      final ServerData a = qbSrv('a', '10.0.0.1');
      sc.servers.assignAll(<ServerData>[a]);

      sc.cacheTorrents('a', <Torrent>[
        Torrent.fromJson(<String, dynamic>{
          'hash': 'h1', 'name': 'A', 'state': 'downloading', 'size': 100,
        }),
        Torrent.fromJson(<String, dynamic>{
          'hash': 'h2', 'name': 'B', 'state': 'uploading', 'size': 200,
        }),
        Torrent.fromJson(<String, dynamic>{
          'hash': 'h3', 'name': 'C', 'state': 'uploading', 'size': 300,
        }),
      ]);
      sc.torrentCache.refresh();
      sc.reportConnected('a');
      await tester.pump(const Duration(milliseconds: 50));

      sc.manualRefreshing.add('a');
      sc.manualRefreshing.refresh();
      await tester.pump();
      expect(find.byKey(const Key('serverStatsPlaceholder')), findsNothing,
          reason: '★ 第 41 轮：有数据就先显示，不能清成骨架让用户干等两三秒');
      expect(find.text('刷新中'), findsOneWidget,
          reason: '★ "正在刷新"仍要由芯片明确表达，避免旧数字被误读成实时值');

      sc.cacheTorrents('a', <Torrent>[]);
      sc.torrentCache.refresh();
      await tester.pump();
      expect(find.byKey(const Key('serverStatsPlaceholder')), findsOneWidget,
          reason: '★ 第 53 轮：没有真实数据就占位 —— 不再拿上次的数字冒充实时值');
    });

    testWidgets('★ 需求 3：刷新期间 AppBar 图标旋转，且按钮被禁用',
        (WidgetTester tester) async {
      await pumpPage(tester);
      final ServerController sc = Get.find<ServerController>();
      sc.servers.assignAll(<ServerData>[qbSrv('a', '10.0.0.1')]);
      await tester.pump(const Duration(milliseconds: 50));

      Finder spinIcon() => find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(RotationTransition),
          );
      IconButton refreshBtn() => tester.widget<IconButton>(
            find.ancestor(of: spinIcon(), matching: find.byType(IconButton)),
          );

      expect(spinIcon(), findsOneWidget, reason: '刷新按钮应常驻一个旋转包装');
      expect(refreshBtn().onPressed, isNotNull, reason: '未刷新 → 可点');

      sc.manualRefreshing.add('a');
      sc.manualRefreshing.refresh();
      await tester.pump();
      expect(refreshBtn().onPressed, isNull,
          reason: '★ 需求 2：刷新进行中按钮应禁用，避免重复触发');

      sc.manualRefreshing.clear();
      sc.manualRefreshing.refresh();
      await tester.pump();
      expect(refreshBtn().onPressed, isNotNull);
    });
  });
}

Dio _fakeTrDio() {
  final Dio dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      String method = '';
      final dynamic d = o.data;
      if (d is String) {
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
              : <String, dynamic>{'version': '4.0.5'},
        },
      ));
    },
  ));
  return dio;
}

Dio _failingQbDio() {
  final Dio dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      if (o.uri.path.contains('/auth/login')) {
        h.resolve(Response<dynamic>(
            requestOptions: o, statusCode: 200, data: 'Fails.'));
        return;
      }
      h.resolve(Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: <String, dynamic>{'unexpected': true},
      ));
    },
  ));
  return dio;
}
