import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/pages/server_list_page.dart';

ServerData trSrv() => ServerData(
      id: 'tr-1',
      name: '家里的 TR',
      type: 'transmission',
      host: '192.168.1.10',
      port: 9091,
      username: 'u',
      password: 'p',
    );

Map<String, dynamic> trTorrent() => <String, dynamic>{
      'id': 7,
      'hashString': 'h1',
      'name': '种子 h1',
      'totalSize': 1000000,
      'sizeWhenDone': 1000000,
      'percentDone': 0.5,
      'status': 4,
      'rateDownload': 1024,
      'rateUpload': 512,
      'downloadDir': '/downloads',
    };

class TrFake {
  final List<String> calls = <String>[];

  List<Map<String, dynamic>> torrents = <Map<String, dynamic>>[];

  Completer<void>? gate;

  Completer<void>? entered;

  bool failTorrentGet = false;

  Dio dio() {
    final Dio d = Dio(BaseOptions(
      baseUrl: 'http://192.168.1.10:9091',
      validateStatus: (int? s) => s != null && s < 500,
      followRedirects: false,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) async {
        String method = '';
        final Object? body = o.data;
        if (body is String) {
          try {
            method =
                ((jsonDecode(body) as Map<String, dynamic>)['method'] ?? '')
                    .toString();
          } catch (_) {
            method = '<unparsable>';
          }
        }
        calls.add(method);

        if (method == 'torrent-get') {
          final Completer<void>? e = entered;
          entered = null;
          if (e != null && !e.isCompleted) e.complete();
          final Completer<void>? g = gate;
          if (g != null) await g.future;
          if (failTorrentGet) {
            h.reject(DioException(requestOptions: o, error: 'boom'), true);
            return;
          }
        }

        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: <String, dynamic>{
            'result': 'success',
            'arguments': method == 'torrent-get'
                ? <String, dynamic>{'torrents': torrents}
                : <String, dynamic>{},
          },
        ));
      },
    ));
    return d;
  }
}

Future<void> pump([int ms = 120]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

Future<ServerController> boot(TrFake fake) async {
  final ServerController sc = Get.put(ServerController());
  sc.trFactory = () => TrMethod(dio: fake.dio());
  await pump(60);
  sc.servers.assignAll(<ServerData>[trSrv()]);
  sc.current.value = sc.servers.first;
  return sc;
}

Future<void> holdTorrentGet(TrFake fake) async {
  fake.gate = Completer<void>();
  fake.entered = Completer<void>();
  await fake.entered!.future.timeout(
    const Duration(seconds: 3),
    onTimeout: () => throw StateError('这一轮没走到 torrent-get：calls=${fake.calls}'),
  );
  await pump(40);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.reset();
  });

  tearDown(Get.reset);

  test('第 90 轮 A · TR 首轮无缓存必须置位"统计中"，取数到位后立即撤掉', () async {
    final TrFake fake = TrFake();
    final ServerController sc = await boot(fake);

    fake.torrents = <Map<String, dynamic>>[trTorrent()];
    final Future<void> round = sc.refreshAllServers(force: true);
    await holdTorrentGet(fake);

    expect(sc.torrentStatsPending['tr-1'], isTrue,
        reason: '★ TR 分支过去完全没有这段逻辑 ⇒ 首轮只能落到旧骨架屏，'
            '与 QB 的新结构 / -- 占位不一致');
    expect(sc.torrentsOf('tr-1'), isEmpty);

    fake.gate!.complete();
    await round;

    expect(sc.torrentStatsPending['tr-1'], isNot(true),
        reason: '★ 取数到位必须当场撤掉占位，晚了真实数据会被 -- 盖住');
    expect(sc.torrentsOf('tr-1'), isNotEmpty);
  });

  test('第 90 轮 B · TR 取数抛错后必须撤掉"统计中"（不得永久卡死）', () async {
    final TrFake fake = TrFake();
    final ServerController sc = await boot(fake);

    fake.failTorrentGet = true;
    await sc.refreshAllServers(force: true);

    expect(fake.calls.contains('torrent-get'), isTrue,
        reason: '前置：这一轮真的打到了取数');
    expect(sc.connStatus['tr-1'], ConnStatus.failed,
        reason: '前置：这一轮确实失败了，否则下面的断言是空的');
    expect(sc.torrentStatsPending['tr-1'], isNot(true),
        reason: '★ 第 89 轮的教训：只置位不复位 ⇒ 卡片顶着"数据加载中 + 一排 --"永久卡死');
  });

  test('第 90 轮 C · 已有 TR 快照时再刷新不得被清成"统计中"', () async {
    final TrFake fake = TrFake();
    final ServerController sc = await boot(fake);

    fake.torrents = <Map<String, dynamic>>[trTorrent()];
    await sc.refreshAllServers(force: true);
    expect(sc.torrentsOf('tr-1'), isNotEmpty, reason: '前置：已经有完整快照');

    final Future<void> round = sc.refreshAllServers(force: true);
    await holdTorrentGet(fake);

    expect(sc.torrentStatsPending['tr-1'], isNot(true),
        reason: '★ 有快照就必须继续显示上次数据（第 41 轮铁律），'
            '不许把 0 当无数据闪成 --');

    fake.gate!.complete();
    await round;
    expect(sc.torrentStatsPending['tr-1'], isNot(true));
  });

  testWidgets('第 90 轮 D · TR 服务器一个种子都没有时不得停在旧骨架屏',
      (WidgetTester tester) async {
    final TrFake fake = TrFake();
    Get.put(ThemeController(), permanent: true);
    final ServerController sc = Get.put(ServerController());
    sc.trFactory = () => TrMethod(dio: fake.dio());
    Get.put(TorrentController());
    await tester.pump(const Duration(milliseconds: 60));
    sc.servers.assignAll(<ServerData>[trSrv()]);
    sc.current.value = sc.servers.first;

    await tester.pumpWidget(const GetMaterialApp(home: ServerListPage()));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(sc.torrentsOf('tr-1'), isEmpty);
    expect(sc.torrentStatsPending['tr-1'], isNot(true),
        reason: '前置：这一轮已经成功取过数（空列表也算）');
    expect(find.byKey(const Key('serverStatsPlaceholder')), findsNothing,
        reason: '★ 成功取过一次数就说明服务器上确实没种子，不能再假装还在加载');
  });

  testWidgets('第 90 轮 E · TR 首轮 pending 期间渲染新结构且全用 -- 占位',
      (WidgetTester tester) async {
    final TrFake fake = TrFake();
    Get.put(ThemeController(), permanent: true);
    final ServerController sc = Get.put(ServerController());
    sc.trFactory = () => TrMethod(dio: fake.dio());
    Get.put(TorrentController());
    await tester.pump(const Duration(milliseconds: 60));
    sc.servers.assignAll(<ServerData>[trSrv()]);
    sc.current.value = sc.servers.first;

    fake.torrents = <Map<String, dynamic>>[trTorrent()];
    fake.gate = Completer<void>();
    fake.entered = Completer<void>();

    await tester.pumpWidget(const GetMaterialApp(home: ServerListPage()));
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(sc.torrentStatsPending['tr-1'], isTrue,
        reason: '前置：首轮取数还没回来');
    expect(find.byKey(const Key('serverStatsPlaceholder')), findsNothing,
        reason: '★★ 本次要修的症状：TR 首轮必须直接渲染新卡片结构，而不是旧骨架屏');
    expect(find.textContaining('数据加载中'), findsOneWidget);
    expect(find.textContaining('--'), findsWidgets,
        reason: '★ 数据未到位时用 -- 占位，不许显示 0 这类假数据');

    fake.gate!.complete();
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(sc.torrentsOf('tr-1'), isNotEmpty);
    expect(sc.torrentStatsPending['tr-1'], isNot(true));
    expect(find.textContaining('数据加载中'), findsNothing);
    expect(find.textContaining('--'), findsNothing,
        reason: '★ 真实数据到位后 -- 必须全部消失');
  });
}
