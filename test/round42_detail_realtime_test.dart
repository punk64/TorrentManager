import 'dart:async';

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

ServerData qbSrv() => ServerData(
      id: 'qb-1',
      name: '家庭 NAS',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'admin',
      password: 'adminadmin',
    );

Map<String, dynamic> qbTorrentJson({
  String hash = 'h1',
  String state = 'downloading',
  int dlSpeed = 0,
  int upSpeed = 0,
  double progress = 0.5,
}) =>
    <String, dynamic>{
      'hash': hash,
      'name': '示例种子',
      'size': 10000000,
      'progress': progress,
      'state': state,
      'dlspeed': dlSpeed,
      'upspeed': upSpeed,
      'num_seeds': 12,
      'num_leechs': 3,
      'ratio': 2.31,
      'downloaded': 300000000,
      'uploaded': 120000000,
      'num_complete': 88,
      'num_incomplete': 7,
      'save_path': '/downloads',
    };

Dio fakeQbDio(
  List<String> calls, {
  List<Map<String, dynamic>> Function()? torrents,
  bool writeOk = true,
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
        h.resolve(ok('v5.0.5'));
        return;
      }
      if (path.endsWith('/app/webapiVersion')) {
        h.resolve(ok('2.11.2'));
        return;
      }

      if (path.endsWith('/torrents/files')) {
        h.resolve(ok(<dynamic>[]));
        return;
      }
      if (path.endsWith('/torrents/peers')) {
        h.resolve(ok(<String, dynamic>{'peers': <String, dynamic>{}}));
        return;
      }

      if (path.endsWith('/sync/torrentPeers')) {
        h.resolve(ok(<String, dynamic>{'peers': <String, dynamic>{}}));
        return;
      }
      if (path.endsWith('/torrents/trackers')) {
        h.resolve(ok(<dynamic>[]));
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
      if (path.endsWith('/torrents/stop') ||
          path.endsWith('/torrents/start') ||
          path.endsWith('/torrents/pause') ||
          path.endsWith('/torrents/resume')) {
        h.resolve(writeOk ? ok('') : no(400));
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

  Future<void> drive(
    WidgetTester tester,
    Future<void> Function() action,
  ) async {
    unawaited(action());
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<TorrentController> pumpDetail(
    WidgetTester tester, {
    required List<String> calls,
    List<Torrent>? items,
    Torrent? current,
    List<Map<String, dynamic>> Function()? torrents,
    bool writeOk = true,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ServerController sc = Get.put(ServerController(
      qb: QbMethod(
        dio: fakeQbDio(calls, torrents: torrents, writeOk: writeOk),
      ),
    ));
    Get.put(ThemeController(), permanent: true);
    final ServerData srv = qbSrv();
    sc.servers.assignAll(<ServerData>[srv]);

    await tester.pumpWidget(GetMaterialApp(
      home: const Scaffold(body: TorrentInfoOverviewPage()),
      initialBinding: AppBinding(),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    sc.select(srv);
    await tester.pump(const Duration(milliseconds: 50));

    final TorrentController ctrl = Get.find<TorrentController>();

    final List<Map<String, dynamic>> seed =
        torrents?.call() ?? <Map<String, dynamic>>[];
    final Torrent t = current ??
        Torrent.fromJson(
            seed.isNotEmpty ? seed.first : qbTorrentJson(dlSpeed: 0));
    ctrl.items.assignAll(items ?? <Torrent>[t]);
    ctrl.current.value = t;
    await tester.pump(const Duration(milliseconds: 50));
    return ctrl;
  }

  bool enabled(WidgetTester tester, String label) {
    final Finder f = find.widgetWithText(FilledButton, label);
    expect(f, findsOneWidget, reason: '按钮「$label」应当存在');
    return tester.widget<FilledButton>(f).onPressed != null;
  }

  group('A 暂停 / 继续的乐观更新', () {
    testWidgets('★ 调用后**同步**就能看到暂停态，不必等服务器返回',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];
      final TorrentController ctrl =
          await pumpDetail(tester, calls: calls, torrents: () => <Map<String, dynamic>>[qbTorrentJson()]);

      final Torrent before = ctrl.items.first;
      expect(before.isPause, isFalse, reason: '前置：一开始是运行中');

      ctrl.clearSelection();
      ctrl.toggleSelect(before.hash);

      unawaited(ctrl.pauseSelected());

      expect(ctrl.items.first.isPause, isTrue,
          reason: '★ 第 42 轮：不等服务器，本地状态立刻翻成暂停');

      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(ctrl.items.first.isPause, isTrue, reason: '请求完成后仍是暂停态');
    });

    testWidgets('★ 暂停时速度一并归零（否则卡片还挂着 8 MB/s，看着像没停）',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];
      final TorrentController ctrl = await pumpDetail(
        tester,
        calls: calls,
        items: <Torrent>[
          Torrent.fromJson(qbTorrentJson(dlSpeed: 8912896, upSpeed: 1258291)),
        ],
        torrents: () => <Map<String, dynamic>>[qbTorrentJson()],
      );

      final String hash = ctrl.items.first.hash;
      ctrl.clearSelection();
      ctrl.toggleSelect(hash);
      await drive(tester, ctrl.pauseSelected);

      expect(ctrl.items.first.dlSpeed, 0, reason: '★ 暂停后下载速度归零');
      expect(ctrl.items.first.upSpeed, 0, reason: '★ 暂停后上传速度归零');
    });

    testWidgets('★ 写请求失败 → 本地状态**回滚**（不能停在服务器没接受的状态上）',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];
      final TorrentController ctrl = await pumpDetail(
        tester,
        calls: calls,
        writeOk: false,
        torrents: () => <Map<String, dynamic>>[qbTorrentJson()],
      );

      expect(ctrl.items.first.isPause, isFalse);
      final String hash = ctrl.items.first.hash;
      ctrl.clearSelection();
      ctrl.toggleSelect(hash);
      await drive(tester, ctrl.pauseSelected);

      expect(ctrl.items.first.isPause, isFalse,
          reason: '★ 请求失败后必须回滚成运行中，否则界面会撒谎');
      expect(ctrl.lastActionOk.value, isFalse,
          reason: '★ 失败要让详情页能弹出错误提示（独立于 error 位）');
    });
  });

  group('B 详情页自己做数据源', () {
    testWidgets('★ loadDetailData 后 current 取到服务端新值 —— 不依赖 items',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];

      final Torrent stale = Torrent.fromJson(qbTorrentJson(dlSpeed: 0));
      final TorrentController ctrl = await pumpDetail(
        tester,
        calls: calls,
        items: <Torrent>[stale],
        current: stale,
        torrents: () => <Map<String, dynamic>>[qbTorrentJson(dlSpeed: 9876543)],
      );

      expect(ctrl.current.value!.dlSpeed, 0, reason: '前置：打开详情时是旧值');

      await drive(tester, ctrl.loadDetailData);

      expect(ctrl.current.value!.dlSpeed, 9876543,
          reason: '★ 第 42 轮：详情页必须**自己按 hash 拉**（updateSelect），'
              '不能靠 items 回写 —— 详情页压栈时列表轮询是跳过的');
      expect(calls.any((String c) => c.contains('/torrents/info')), isTrue,
          reason: '★ 定点刷新确实打到了 torrents/info');
    });

    testWidgets('★ 每次成功刷新都会记一点速度采样（供迷你曲线）',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];
      final TorrentController ctrl = await pumpDetail(
        tester,
        calls: calls,
        torrents: () => <Map<String, dynamic>>[qbTorrentJson(dlSpeed: 1024)],
      );

      expect(ctrl.dlSamples, isEmpty, reason: '前置：还没刷过');
      await drive(tester, ctrl.loadDetailData);

      expect(ctrl.dlSamples.length, 1);
      expect(ctrl.dlSamples.first, 1024);
      expect(ctrl.detailSyncedAt.value, isNotNull,
          reason: '★ 「刚刚更新」文案依赖这个时间戳');
    });

    testWidgets('★ 换种子时清空采样（否则新种子会画出上一颗的曲线）',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];
      final TorrentController ctrl = await pumpDetail(
        tester,
        calls: calls,
        torrents: () => <Map<String, dynamic>>[qbTorrentJson(dlSpeed: 2048)],
      );
      await drive(tester, ctrl.loadDetailData);
      expect(ctrl.dlSamples, isNotEmpty);

      ctrl.openDetail(Torrent.fromJson(qbTorrentJson(hash: 'h2')));
      expect(ctrl.dlSamples, isEmpty, reason: '★ 换种子必须清空采样');
      expect(ctrl.ulSamples, isEmpty);

      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    });
  });

  group('C 详情页状态区分与校验进度', () {
    testWidgets('★ 运行中：「继续」禁用、「暂停」可点',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];
      await pumpDetail(tester, calls: calls, torrents: () => <Map<String, dynamic>>[qbTorrentJson()]);

      expect(enabled(tester, '继续'), isFalse,
          reason: '★ 已经在跑，不该还能点"继续"');
      expect(enabled(tester, '暂停'), isTrue,
          reason: '★ 运行中"暂停"必须可点');
    });

    testWidgets('★ 暂停态：「暂停」禁用、「继续」可点',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];
      await pumpDetail(
        tester,
        calls: calls,
        torrents: () =>
            <Map<String, dynamic>>[qbTorrentJson(state: 'stoppedDL')],
      );

      expect(enabled(tester, '暂停'), isFalse,
          reason: '★ 已经暂停，不该还能点"暂停"');
      expect(enabled(tester, '继续'), isTrue,
          reason: '★ 暂停态"继续"必须可点');
    });

    testWidgets('★ 校验中：显示「校验中 xx%」，且两个启停按钮都锁',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];
      await pumpDetail(
        tester,
        calls: calls,
        torrents: () => <Map<String, dynamic>>[
          qbTorrentJson(state: 'checkingDL', progress: 0.62),
        ],
      );

      expect(find.textContaining('校验中 62'), findsWidgets,
          reason: '★ 第 42 轮：校验中要把**进度**显出来（用户专门提到这条）');
      expect(enabled(tester, '暂停'), isFalse, reason: '★ 校验中不能暂停');
      expect(enabled(tester, '继续'), isFalse, reason: '★ 校验中不能继续');
    });

    testWidgets('★ 字段区：有「校验进度」，且旧名「校验状态」已不再出现',
        (WidgetTester tester) async {
      final List<String> calls = <String>[];
      await pumpDetail(tester, calls: calls, torrents: () => <Map<String, dynamic>>[qbTorrentJson()]);

      expect(find.text('校验进度'), findsOneWidget);
      expect(find.text('最近活动'), findsOneWidget,
          reason: '★ 原来这行取的是 last_activity，却叫「校验状态」，名实不符');
      expect(find.text('校验状态'), findsNothing);
    });
  });
}
