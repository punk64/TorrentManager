import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/utils/app_log.dart';
import 'package:torrent_manager/utils/net_error.dart';

ServerData qbSrv() => ServerData(
      id: 'qb-1',
      name: '家庭 NAS',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'admin',
      password: 'adminadmin',
    );

Map<String, dynamic> qbTorrentJson(String hash) => <String, dynamic>{
      'hash': hash,
      'name': '种子 $hash',
      'size': 10000000,
      'progress': 0.5,
      'state': 'downloading',
      'dlspeed': 1024,
      'upspeed': 512,
      'save_path': '/downloads',
    };

class GateAdapter implements HttpClientAdapter {
  final List<String> calls = <String>[];

  final List<RequestOptions> seen = <RequestOptions>[];

  final Map<String, Completer<void>> gates = <String, Completer<void>>{};

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
    seen.add(options);
    final Completer<void>? gate = gates[p];
    if (gate != null) await gate.future;

    final String body;
    final String type;
    if (p.endsWith('/auth/login')) {
      body = 'Ok.';
      type = 'text/plain';
    } else if (p.endsWith('/app/webapiVersion')) {
      body = '2.11.2';
      type = 'text/plain';
    } else if (p.endsWith('/app/version')) {
      body = 'v5.0.5';
      type = 'text/plain';
    } else if (p.endsWith('/sync/maindata')) {
      body = jsonEncode(<String, dynamic>{
        'rid': 1,
        'full_update': true,
        'server_state': <String, dynamic>{
          'dl_info_speed': 1024,
          'up_info_speed': 512,
        },
        'torrents': <String, dynamic>{'h0': qbTorrentJson('h0')},
      });
      type = 'application/json';
    } else {
      body = '{}';
      type = 'application/json';
    }
    return ResponseBody.fromString(
      body,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[type],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

List<String> viewLines() => AppLog.instance.entries
    .where((LogEntry e) => e.source == AppLog.srcView)
    .map((LogEntry e) => e.message)
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.reset();
    AppLog.instance.clear();
    AppLog.resetViewThrottle();
  });

  tearDown(() {
    AppLog.instance.clear();
    AppLog.resetViewThrottle();
    Get.reset();
  });

  test('第 44 轮 A · VIEW 日志：来源正确，同 key 在窗口内只记一条', () {
    AppLog.instance.view('服务器卡片[甲] 连接中…', key: 'k1');
    AppLog.instance.view('服务器卡片[甲] 连接中…', key: 'k1');
    AppLog.instance.view('服务器卡片[甲] 连接中…', key: 'k1');
    expect(viewLines().length, 1,
        reason: '★ 同一 key 必须节流：卡片是 3 秒一轮，不节流几分钟就刷光 500 条上限');
    expect(AppLog.instance.entries.first.source, AppLog.srcView,
        reason: '组件状态必须单独一个来源，才能和 OP / NET / UI 区分开');

    AppLog.instance.view('服务器卡片[乙] 连接中…', key: 'k2');
    expect(viewLines().length, 2);

    AppLog.resetViewThrottle();
    DateTime fake = DateTime(2026, 9, 22, 8, 0, 0);
    AppLog.viewNow = () => fake;
    AppLog.instance.view('窗口测试', key: 'k3');
    fake = fake.add(const Duration(seconds: 61));
    AppLog.instance.view('窗口测试', key: 'k3');
    expect(viewLines().where((String m) => m == '窗口测试').length, 2,
        reason: '超过 viewLogWindow（60 秒）后应重新记录');
    AppLog.viewNow = DateTime.now;
  });

  test('第 44 轮 B · 卡片「连接中」只在状态真的变化时记', () {
    final ServerController sc = ServerController();
    const String id = 'qb-1';

    for (int i = 0; i < 10; i++) {
      AppLog.resetViewThrottle();
      sc.reportConnecting(id);
    }
    expect(viewLines().length, 1,
        reason: '★ 状态没变（一直是 connecting）就不该重复记 —— 3 秒轮询下会刷屏');

    sc.reportFailureKind(id, ConnErrorKind.unreachable, '连不上服务器');
    AppLog.resetViewThrottle();
    sc.reportConnecting(id);
    expect(viewLines().where((String m) => m.contains('连接中')).length, 2,
        reason: '失败之后重新连接是一次新的状态变化，必须留痕');
  });

  test('第 44 轮 C · 卡片"数据已获取"与"信息已刷新"都留痕且能区分', () {
    final ServerController sc = ServerController();
    const String id = 'qb-1';
    sc.reportConnected(id, took: const Duration(milliseconds: 1900));
    sc.reportRefreshed(id, detail: '种子 128 个 ｜ 合计 3.2s');

    final List<String> vs = viewLines();
    expect(
      vs.any((String m) => m.contains('数据已获取') && m.contains('1.9s')),
      isTrue,
      reason: '用户要求日志里能看到"服务器卡片数据成功获取"',
    );
    expect(
      vs.any((String m) => m.contains('信息已刷新') && m.contains('种子 128')),
      isTrue,
      reason: '用户要求日志里能看到"服务器卡片信息已刷新"',
    );

    expect(vs.length, 2);
  });

  test('第 53 轮 D · 手上有缓存也**不**提前点亮（卡片不再显示假数字）', () async {
    final GateAdapter ad = GateAdapter();
    final ServerController sc = ServerController(qb: QbMethod(dio: ad.dio()));
    final ServerData s = qbSrv();
    sc.servers.assignAll(<ServerData>[s]);
    sc.current.value = s;

    sc.cacheTorrents(s.id, <Torrent>[
      Torrent.fromJson(<String, dynamic>{
        'hash': 'h1',
        'name': 'old',
        'size': 1,
      }),
    ]);

    ad.gates['/api/v2/sync/maindata'] = Completer<void>();

    unawaited(sc.refreshAllServers());
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(ad.calls.any((String c) => c.contains('/app/version')), isTrue,
        reason: '前置：确实走到了会话探测');
    expect(ad.calls.any((String c) => c.contains('/sync/maindata')), isTrue,
        reason: '前置：maindata 已经发出（正挂在半空）');
    expect(sc.connStatus[s.id], ConnStatus.connecting,
        reason: '★ 第 53 轮：有缓存也不提前点亮 —— 点亮时点回到"数据真的到位"。'
            '否则卡片会在种子还没取到时显示一排 0（假数据，比多等两秒更糟）');

    ad.gates['/api/v2/sync/maindata']!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(sc.connStatus[s.id], ConnStatus.ok);
    expect(sc.torrentsOf(s.id).isNotEmpty, isTrue, reason: '真实数据最终还是要写进来');
  });

  test('第 44 轮 D2 · 没有快照时不提前点亮（不显示"0 个种子"的假数据）', () async {
    final GateAdapter ad = GateAdapter();
    final ServerController sc = ServerController(qb: QbMethod(dio: ad.dio()));
    final ServerData s = qbSrv();
    sc.servers.assignAll(<ServerData>[s]);
    sc.current.value = s;

    ad.gates['/api/v2/sync/maindata'] = Completer<void>();
    unawaited(sc.refreshAllServers());
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(sc.connStatus[s.id], ConnStatus.connecting,
        reason: '没有快照就只能等真实数据：提前点亮会让卡片显示"0 个种子"，'
            '那是假数据，比多等两秒更糟');

    ad.gates['/api/v2/sync/maindata']!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(sc.connStatus[s.id], ConnStatus.ok);
  });

  test('第 44 轮 E · setServer 只在路由真的变了才推进世代号', () {
    final QbMethod qb = QbMethod(dio: GateAdapter().dio());
    final ServerData s = qbSrv();
    qb.setServer(s);
    final int g1 = qb.routeGen;

    qb.setServer(qbSrv());
    expect(qb.routeGen, g1,
        reason: '★ 同一个 baseUrl 再设一次**不算**路由变更。'
            '此前无条件 ++ 会把在飞的那笔探测判成过期作废 → '
            '`checkQbServerCookie` 走"改用新路由重新建立会话"→ '
            '白多一次探测 + 一次登录（约 2.5 秒，用户日志里那 8 秒的组成部分）');

    qb.setServer(ServerData(
      id: 'qb-1',
      name: '家庭 NAS',
      type: 'qbittorrent',
      host: '10.0.0.9',
      port: 8080,
      username: 'admin',
      password: 'adminadmin',
    ));
    expect(qb.routeGen, greaterThan(g1));
  });

  test('第 44 轮 F · 版本号两笔并行发起，且用探测级短超时', () async {
    final GateAdapter ad = GateAdapter();
    final QbMethod qb = QbMethod(dio: ad.dio());
    qb.setServer(qbSrv());

    ad.gates['/api/v2/app/webapiVersion'] = Completer<void>();
    final Future<Map<String, String>> f = qb.updateQbInfo();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(ad.calls.where((String c) => c.endsWith('/app/version')).length, 1,
        reason: '★ 第一笔必须已经发出');
    expect(
        ad.calls.where((String c) => c.contains('/app/webapiVersion')).length, 1,
        reason: '★ 第二笔必须与第一笔**同帧发出**，而不是等第一笔回来才发');

    final RequestOptions vo = ad.seen.lastWhere(
        (RequestOptions o) => o.uri.path.endsWith('/app/version'));
    expect(vo.connectTimeout?.inMilliseconds, 600,
        reason: '★ 版本号属探测类请求：此前用默认 8 秒超时，'
            '而它被 `_refreshBackground` 末尾 await —— 一个可选字段就能把整轮刷新拖到 8 秒'
            '（第 55 轮：1.5 秒 → 0.6 秒，与 `LanDetector.kProbeTimeout` 同档）');

    ad.gates['/api/v2/app/webapiVersion']!.complete();
    final Map<String, String> r = await f;
    expect(r['version'], 'v5.0.5');
    expect(r['webapiVersion'], '2.11.2');
  });
}
