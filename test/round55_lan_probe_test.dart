import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/utils/lan_detector.dart';
import 'package:torrent_manager/utils/net_error.dart';

ServerData _lanSrv() => ServerData(
      id: 'qb-1',
      name: '家庭 NAS',
      type: 'qbittorrent',
      host: 'nas.example.com',
      port: 443,
      useHttps: true,
      lanHost: '192.168.1.10',
      lanPort: 8080,
      username: 'admin',
      password: 'adminadmin',
    );

Future<void> _pump() =>
    Future<void>.delayed(const Duration(milliseconds: 1));

void main() {
  tearDown(() {
    LanDetector.overrideProbe = null;
    LanDetector.overrideTcp = null;
  });

  test('第 55 轮 A · 冷启动没有记忆 → select 必定先探测', () async {
    int probes = 0;
    LanDetector.overrideProbe = (_) async {
      probes++;
      return false;
    };

    final ServerController sc = ServerController();
    final ServerData s = _lanSrv();
    sc.servers.assignAll(<ServerData>[s]);
    sc.select(s);
    await _pump();

    expect(probes, 1,
        reason: '★ 内存表冷启动为空 → 必须先探一次才决定路由'
            '（第 45 轮"结论新鲜就跳过探测"的捷径已撤销）');
    expect(sc.lanUsing[s.id], isFalse, reason: '探到不可达 → 走公网');
  });

  test('第 55 轮 A2 · 同一会话内已有结论且网络没变 → 不重复付那 0.6 秒',
      () async {
    int probes = 0;
    LanDetector.overrideProbe = (_) async {
      probes++;
      return true;
    };
    final ServerController sc = ServerController();
    final ServerData s = _lanSrv();
    sc.servers.assignAll(<ServerData>[s]);

    sc.select(s);
    await _pump();
    expect(probes, 1, reason: '前置：第一次切过去探了一次');

    sc.select(s); 
    await _pump();
    expect(probes, 1,
        reason: '★ 结论只在**本次会话内**复用 —— 撤销的是"落盘记忆"，'
            '不是"每次都重探"（后者会让 3 秒轮询每拍多付 0.6 秒）');
  });

  test('第 55 轮 B · 探测超时统一 600ms（不再有 800 / 1500 两档）', () {
    expect(LanDetector.kProbeTimeout.inMilliseconds, 600,
        reason: '★ 两档的实测效果相反：人在外面连家里的私有地址会把'
            '「非同网段」那档 1500ms 等满 —— 最需要快的场景反而最慢');
  });

  test('第 55 轮 B2 · 探测不可达地址时不超过 600ms 量级（真实 Socket）',
      () async {
    final ServerData s = ServerData(
      id: 'dead',
      name: '不可能连上的',
      type: 'qbittorrent',
      host: '192.0.2.1',
      port: 65530,
      lanHost: '192.0.2.1',
      lanPort: 65530,
      username: 'u',
      password: 'p',
    );
    final Stopwatch sw = Stopwatch()..start();
    final bool onLan = await LanDetector.isOnLan(s);
    sw.stop();

    expect(onLan, isFalse, reason: '前置：这个地址连不上');
    expect(sw.elapsed.inMilliseconds, lessThan(2000),
        reason: '★ 探测必须有硬上限：原先「预解析 800ms + TCP 1500ms」'
            '是**串行**的，最坏 2.3 秒，而这段等待毫无收益（结论必然是不可达）');
  });

  test('第 55 轮 C · 走局域网时首次网络失败 → 立刻重探并把路由改回公网',
      () async {
    int probes = 0;
    bool reachable = true;
    LanDetector.overrideProbe = (_) async {
      probes++;
      return reachable;
    };
    final ServerController sc = ServerController();
    final ServerData s = _lanSrv();
    sc.servers.assignAll(<ServerData>[s]);

    sc.select(s);
    await _pump();
    expect(probes, 1, reason: '前置：开局探测到局域网可达');
    expect(sc.lanUsing[s.id], isTrue, reason: '前置：当前走局域网');

    reachable = false;
    sc.reportFailureKind(s.id, ConnErrorKind.unreachable, '连接超时');
    await _pump();

    expect(probes, 2,
        reason: '★ 走错路的失败必须**立刻**触发一次重探（0.6 秒），'
            '而不是盲等退避 / 等网络监听反应过来');
    expect(sc.lanUsing[s.id], isFalse,
        reason: '★ 重探发现不可达 → 路由改回公网，下一拍直接打对地方');
  });

  test('第 55 轮 D · 同一串失败里不重复重探；非网络类失败不重探', () async {
    int probes = 0;
    LanDetector.overrideProbe = (_) async {
      probes++;
      return true; 
    };
    final ServerController sc = ServerController();
    final ServerData s = _lanSrv();
    sc.servers.assignAll(<ServerData>[s]);
    sc.select(s);
    await _pump();
    expect(probes, 1, reason: '前置');

    sc.reportFailureKind(s.id, ConnErrorKind.unreachable, '连接超时');
    await _pump();
    expect(probes, 2, reason: '前置：第一次失败重探了一次');

    sc.reportFailureKind(s.id, ConnErrorKind.unreachable, '连接超时');
    await _pump();
    expect(probes, 2,
        reason: '★ 服务器真关机时它每 3 秒失败一次 —— 每拍都重探等于'
            '把 0.6 秒加到每一拍上。第一次就足够纠正"走错路"');
  });

  test('第 55 轮 D2 · 非网络类失败（密码错）不重探', () async {
    int probes = 0;
    LanDetector.overrideProbe = (_) async {
      probes++;
      return true;
    };
    final ServerController sc = ServerController();
    final ServerData s = _lanSrv();
    sc.servers.assignAll(<ServerData>[s]);
    sc.select(s);
    await _pump();
    expect(probes, 1, reason: '前置');

    sc.reportAuthFailure(s.id, '账号或密码错误');
    await _pump();
    expect(probes, 1, reason: '★ 密码错与"走哪条路"无关，重探没有意义');
  });

  test('第 55 轮 G · 首笔请求之前必须等探测落地（不再赌路由）', () async {
    final Completer<void> gate = Completer<void>();
    int probes = 0;
    LanDetector.overrideProbe = (_) async {
      probes++;
      await gate.future; 
      return true;
    };
    final ServerController sc = ServerController();
    final ServerData s = _lanSrv();
    sc.servers.assignAll(<ServerData>[s]);
    sc.select(s);
    await _pump();
    expect(probes, 1, reason: '前置：探测已在飞');

    final Future<void>? flying = sc.lanProbeOf(s.id);
    expect(flying, isNotNull, reason: '前置：探测在飞，首笔请求必须等它');

    bool waited = false;
    final Future<void> f = flying!.then((_) => waited = true);
    await _pump();
    expect(waited, isFalse,
        reason: '★ 探测没回来之前不许发首笔请求 —— 否则路由只能靠猜，'
            '猜错的那次要等满 8 秒 connectTimeout');

    gate.complete();
    await f;
    expect(waited, isTrue, reason: '探测一落地就立刻放行');
    await _pump();
    expect(sc.lanProbeOf(s.id), isNull,
        reason: '探测结束后不该再挡住后续刷新（否则每拍都多等一轮）');
  });

  test('第 55 轮 G2 · 探测不在飞时 lanProbeOf 返回 null（不产生 await）', () {
    final ServerController sc = ServerController();
    final ServerData s = _lanSrv();
    sc.servers.assignAll(<ServerData>[s]);
    expect(sc.lanProbeOf(s.id), isNull,
        reason: '★ 没在探测 → 立即返回，刷新链路的同步语义不变');
  });

  test('第 55 轮 E · 本来就在走公网 → 失败不重探', () async {
    int probes = 0;
    LanDetector.overrideProbe = (_) async {
      probes++;
      return false; 
    };
    final ServerController sc = ServerController();
    final ServerData s = _lanSrv();
    sc.servers.assignAll(<ServerData>[s]);
    sc.select(s);
    await _pump();
    expect(probes, 1, reason: '前置');
    expect(sc.lanUsing[s.id], isFalse, reason: '前置：走公网');

    sc.reportFailureKind(s.id, ConnErrorKind.unreachable, '连接超时');
    await _pump();
    expect(probes, 1, reason: '★ 与路由无关，重探没有意义');
  });
}
