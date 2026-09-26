import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/pages/server_list_page.dart';

ServerData qbSrv() => ServerData(
      id: 'qb-1',
      name: '家庭 NAS',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'admin',
      password: 'adminadmin',
    );

const String kTransferBody =
    '{"dl_info_speed":2048,"up_info_speed":1024,"dl_info_data":123456}';

const String kMaindataBody =
    '{"rid":1,"full_update":true,"server_state":{"dl_info_speed":777,'
        '"up_info_speed":888},"torrents":{"h0":{"hash":"h0","name":"种子 h0",'
        '"size":10000000,"progress":0.5,"state":"downloading","dlspeed":1024,'
        '"upspeed":512,"save_path":"/downloads"}}}';

class PendingAdapter implements HttpClientAdapter {
  final List<String> calls = <String>[];

  final Map<String, Completer<void>> gates = <String, Completer<void>>{};

  final Map<String, String> bodies = <String, String>{
    '/api/v2/transfer/info': kTransferBody,
    '/api/v2/sync/maindata': kMaindataBody,
  };

  Completer<void>? maindataEntered;

  bool failMaindata = false;

  Dio dio() => Dio(BaseOptions(
        baseUrl: 'http://192.168.1.10:8080',
        validateStatus: (int? s) => s != null && s < 500,
        followRedirects: false,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
      ))
        ..httpClientAdapter = this;

  int countOf(String path) =>
      calls.where((String c) => c.contains(path)).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String p = options.uri.path;
    calls.add('${options.method} $p');

    if (p.endsWith('/sync/maindata')) {
      final Completer<void>? entered = maindataEntered;
      maindataEntered = null;
      if (entered != null && !entered.isCompleted) entered.complete();
    }

    final Completer<void>? gate = gates[p];
    if (gate != null) await gate.future;

    if (failMaindata && p.endsWith('/sync/maindata')) {
      return ResponseBody.fromString(
        'boom',
        500,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );
    }

    final String body;
    final bool plain;
    if (p.endsWith('/auth/login')) {
      body = 'Ok.';
      plain = true;
    } else if (p.endsWith('/app/webapiVersion')) {
      body = '2.11.2';
      plain = true;
    } else if (p.endsWith('/app/version')) {
      body = 'v5.0.5';
      plain = true;
    } else {
      body = bodies[p] ?? '{}';
      plain = false;
    }
    return ResponseBody.fromString(
      body,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[
          plain ? 'text/plain' : 'application/json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> pump([int ms = 120]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

Future<ServerController> boot(PendingAdapter ad) async {
  final ServerController sc = Get.put(ServerController());
  sc.qbFactory = () => QbMethod(dio: ad.dio());
  await pump(60);
  ad.calls.clear();
  final ServerData s = qbSrv();
  sc.servers.assignAll(<ServerData>[s]);
  sc.current.value = s;
  return sc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.reset();
  });

  tearDown(Get.reset);

  test('第 89 轮 A · 取数失败后 rid 被另一条通道推进，卡片不得永久卡"统计中"', () async {
    final PendingAdapter ad = PendingAdapter();
    final ServerController sc = await boot(ad);

    sc.setRid('qb-1', 0);

    ad.failMaindata = true;
    await sc.refreshAllServers(force: true);

    expect(ad.countOf('/sync/maindata'), greaterThanOrEqualTo(1),
        reason: '前置：这一轮真的打到 maindata 才失败');
    expect(sc.connStatus['qb-1'], ConnStatus.failed,
        reason: '前置：这一轮确实失败了，否则下面这条断言是空的');
    expect(sc.torrentStatsPending['qb-1'], isNot(true),
        reason: '★ 失败轮结束后必须撤掉"统计中"，否则卡片会顶着一排 -- 配着错误提示');

    sc.setRid('qb-1', 7);

    ad.failMaindata = false;
    await sc.refreshAllServers(force: true);

    expect(sc.torrentsOf('qb-1'), isNotEmpty,
        reason: '前置：这一轮真的取到数了');
    expect(sc.connStatus['qb-1'], ConnStatus.ok);
    expect(sc.torrentStatsPending['qb-1'], isNot(true),
        reason: '★★ 共享 rid 已被列表页那条通道推进 ⇒ 清除不能再依赖 firstLoad 快照，'
            '否则卡片永久停在"数据加载中"且参数全是 --');
  });

  test('第 89 轮 B · 已有完整快照时重进，不得清成"统计中 / --"', () async {
    final PendingAdapter ad = PendingAdapter();
    final ServerController sc = await boot(ad);

    await sc.refreshAllServers(force: true);
    expect(sc.torrentsOf('qb-1'), isNotEmpty,
        reason: '前置：第一次已经拿到完整快照');

    sc.setRid('qb-1', 0);

    ad.gates['/api/v2/sync/maindata'] = Completer<void>();
    ad.maindataEntered = Completer<void>();
    final Future<void> round = sc.refreshAllServers(force: true);
    await ad.maindataEntered!.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => throw StateError(
          '这一轮没走到 maindata：calls=${ad.calls} '
          'servers=${sc.servers.length} cache=${sc.torrentsOf('qb-1').length} '
          'rid=${sc.ridOf('qb-1')}'),
    );
    await pump(40);

    expect(sc.torrentStatsPending['qb-1'], isNot(true),
        reason: '★ 有快照就该继续显示上次数据（第 41 轮铁律），不许清成 -- 让用户干等');
    expect(sc.torrentsOf('qb-1'), isNotEmpty,
        reason: '★ 快照还在，卡片有数可显示');

    ad.gates['/api/v2/sync/maindata']!.complete();
    await round;
    expect(sc.torrentStatsPending['qb-1'], isNot(true));
  });

  test('第 89 轮 C · select() 必须清掉残留的"统计中"', () async {
    final PendingAdapter ad = PendingAdapter();
    final ServerController sc = await boot(ad);

    sc.torrentStatsPending['qb-1'] = true;
    sc.torrentStatsPending.refresh();

    sc.select(sc.servers.first);

    expect(sc.torrentStatsPending['qb-1'], isNot(true),
        reason: '★ 与 _connStage 同一条纪律：切换 / 重进服务器时必须清残留状态');
  });

  test('第 89 轮 D · 无快照的首轮仍要显示"统计中"（第 83 轮语义不回归）', () async {
    final PendingAdapter ad = PendingAdapter();
    final ServerController sc = await boot(ad);

    ad.gates['/api/v2/sync/maindata'] = Completer<void>();
    ad.maindataEntered = Completer<void>();
    final Future<void> round = sc.refreshAllServers(force: true);
    await ad.maindataEntered!.future.timeout(const Duration(seconds: 3));
    await pump(40);

    expect(sc.torrentStatsPending['qb-1'], isTrue,
        reason: '★ 首轮没有任何数据可显示 ⇒ 必须标"统计中"，不能显示一排 0（假数据）');
    expect(sc.torrentsOf('qb-1'), isEmpty);

    ad.gates['/api/v2/sync/maindata']!.complete();
    await round;

    expect(sc.torrentStatsPending['qb-1'], isNot(true),
        reason: '真实数据到位后必须撤掉"统计中"');
    expect(sc.torrentsOf('qb-1'), isNotEmpty);
  });

  testWidgets('第 89 轮 E · 卡片上不得出现"数据加载中"与 "--"（有快照时）',
      (WidgetTester tester) async {
    final PendingAdapter ad = PendingAdapter();
    Get.put(ThemeController(), permanent: true);
    final ServerController sc = Get.put(ServerController());
    sc.qbFactory = () => QbMethod(dio: ad.dio());
    Get.put(TorrentController());
    await tester.pump(const Duration(milliseconds: 60));
    sc.servers.assignAll(<ServerData>[qbSrv()]);
    sc.current.value = sc.servers.first;

    await tester.pumpWidget(const GetMaterialApp(home: ServerListPage()));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 80));

    expect(sc.torrentsOf('qb-1'), isNotEmpty,
        reason: '前置：首帧轮询已经取到数据');
    expect(find.textContaining('数据加载中'), findsNothing,
        reason: '★ 有数据时卡片不得顶"数据加载中"徽章');
    expect(find.textContaining('--'), findsNothing,
        reason: '★ 有数据时参数不得变 -- 占位');

    sc.torrentStatsPending['qb-1'] = true;
    sc.torrentStatsPending.refresh();
    await tester.pump();

    expect(find.textContaining('数据加载中'), findsOneWidget,
        reason: '断言有效性：这个标志位就是"数据加载中"徽章与 -- 的唯一开关');
    expect(find.textContaining('--'), findsWidgets);
  });
}
