import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/server_state.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';

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

class StatsGateAdapter implements HttpClientAdapter {
  final List<String> calls = <String>[];

  final Map<String, Completer<void>> gates = <String, Completer<void>>{};

  final Map<String, String> bodies = <String, String>{
    '/api/v2/transfer/info': kTransferBody,
    '/api/v2/sync/maindata': kMaindataBody,
  };

  Dio dio() => Dio(BaseOptions(
        baseUrl: 'http://192.168.1.10:8080',
        validateStatus: (int? s) => s != null && s < 500,
        followRedirects: false,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
      ))
        ..httpClientAdapter = this;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String p = options.uri.path;
    calls.add('${options.method} $p');
    final Completer<void>? gate = gates[p];
    if (gate != null) await gate.future;

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

  int countOf(String path) =>
      calls.where((String c) => c.contains(path)).length;
}

Future<void> pump([int ms = 120]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

ServerController build(StatsGateAdapter ad) {
  final ServerController sc = ServerController(qb: QbMethod(dio: ad.dio()));
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

  test('第 83 轮 A · 全局速率一到就点亮，种子统计仍挂"统计中"', () async {
    final StatsGateAdapter ad = StatsGateAdapter();
    final ServerController sc = build(ad);
    ad.gates['/api/v2/sync/maindata'] = Completer<void>();

    unawaited(sc.refreshAllServers());
    await pump();

    expect(ad.countOf('/api/v2/transfer/info'), 1,
        reason: '★ 首轮必须先发轻量的 transfer/info，别让用户干等 maindata');
    expect(sc.connStatus['qb-1'], ConnStatus.ok,
        reason: '★ 连上就有速率可看、能点进列表 —— 这是本轮要解决的首屏 4.9s 空白');

    final ServerState st = sc.stateOf('qb-1');
    expect(st.dlInfoSpeed, 2048);
    expect(st.upInfoSpeed, 1024);

    expect(sc.torrentStatsPending['qb-1'], true,
        reason: '★ 种子还没数完，卡片必须标"统计中"，不能显示 0（假数据）');
    expect(sc.torrentsOf('qb-1'), isEmpty);

    ad.gates['/api/v2/sync/maindata']!.complete();
    await pump(200);

    expect(sc.torrentStatsPending['qb-1'], false,
        reason: '真实数据到位后必须撤掉"统计中"');
    expect(sc.torrentsOf('qb-1').length, 1);
    expect(sc.connStatus['qb-1'], ConnStatus.ok);
  });

  test('第 83 轮 B · transfer/info 空或不是 JSON 时不点亮', () async {
    final StatsGateAdapter ad = StatsGateAdapter();
    ad.bodies['/api/v2/transfer/info'] = '{}';
    final ServerController sc = build(ad);
    ad.gates['/api/v2/sync/maindata'] = Completer<void>();

    unawaited(sc.refreshAllServers());
    await pump();

    expect(sc.connStatus['qb-1'], ConnStatus.connecting,
        reason: '★ 没拿到真数据就不能点亮，否则又是一排 0（第 53 轮铁律）');

    ad.gates['/api/v2/sync/maindata']!.complete();
    await pump(200);
    expect(sc.connStatus['qb-1'], ConnStatus.ok);
  });

  test('第 83 轮 C · transfer/info 抛错不拖垮整轮刷新', () async {
    final StatsGateAdapter ad = StatsGateAdapter();
    ad.bodies['/api/v2/transfer/info'] = 'not json at all';
    final ServerController sc = build(ad);

    unawaited(sc.refreshAllServers());
    await pump(200);

    expect(sc.connStatus['qb-1'], ConnStatus.ok,
        reason: 'transfer/info 只是加速器，失败必须静默降级到"等 maindata"');
    expect(sc.torrentsOf('qb-1').length, 1);
  });

  test('第 83 轮 D · 只有首轮发 transfer/info，后续走增量', () async {
    final StatsGateAdapter ad = StatsGateAdapter();
    final ServerController sc = build(ad);

    unawaited(sc.refreshAllServers());
    await pump(400);

    expect(ad.countOf('/api/v2/transfer/info'), 1);
    expect(ad.countOf('/api/v2/sync/maindata'), 1);

    unawaited(sc.refreshAllServers());
    await pump(400);

    expect(ad.countOf('/api/v2/sync/maindata'), greaterThanOrEqualTo(2),
        reason: '前置：第二轮确实又跑了一轮，否则下面这条断言是空的');
    expect(ad.countOf('/api/v2/transfer/info'), 1,
        reason: '★ 已有 rid 就是增量同步，再发一笔 transfer/info 纯属浪费请求');
  });
}
