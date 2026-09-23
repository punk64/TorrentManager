import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/utils/formatter.dart';

ServerData _srv(String id) => ServerData(
      id: id,
      name: '服务器$id',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'u',
      password: 'p',
    );

List<Torrent> _many(String prefix, int n) => List<Torrent>.generate(
      n,
      (int i) => Torrent(
        hash: '$prefix$i',
        name: '种子$i',
        size: 1,
        progress: 0,
        state: 'downloading',
        dlSpeed: 0,
        upSpeed: 0,
        numSeeds: 0,
        numLeechs: 0,
        ratio: 0,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.reset();
  });

  tearDown(() => Get.reset());

  group('第 58 轮 E · M1 缓存总条数阀', () {
    test('E1 常量口径：单台 2 万、总量 4 万（最坏值从 10 万压到 4 万）', () {
      expect(ServerController.kCacheMaxTorrents, 20000);
      expect(ServerController.kCacheMaxTotalTorrents, 40000);
      expect(
        ServerController.kCacheMaxTotalTorrents <
            ServerController.kCacheMaxServers *
                ServerController.kCacheMaxTorrents,
        isTrue,
        reason: '★ 总量阀必须**小于**「台数 × 单台」的最坏值，否则形同虚设 —— '
            '5 台 × 2 万 = 10 万条 ≈ 50~100MB，对手机偏高',
      );
    });

    test('E2 ★ 总量超限 → 按整台淘汰，且当前服务器豁免', () {
      final ServerController sc = ServerController();
      sc.servers.assignAll(<ServerData>[_srv('a'), _srv('b'), _srv('c')]);
      sc.current.value = _srv('a'); 

      sc.cacheTorrents('a', _many('a', 20000));
      sc.cacheTorrents('b', _many('b', 20000));

      expect(sc.hasAnyCache('a'), isTrue);
      expect(sc.hasAnyCache('b'), isTrue);

      sc.cacheTorrents('c', _many('c', 20000)); 
      expect(sc.hasAnyCache('a'), isTrue,
          reason: '★ 当前正在看的服务器**豁免淘汰** —— 否则用户眼前的数据被抽走');
      expect(sc.hasAnyCache('b'), isFalse,
          reason: '★ b 是最久未用的 → 被**整台**淘汰（不是把某一台截断）');
    });

    test('E3 台数阀仍然生效（5 台以内不动，第 6 台进来淘汰最久未用）', () {
      final ServerController sc = ServerController();
      final List<ServerData> all = <ServerData>[
        for (int i = 0; i < 7; i++) _srv('s$i'),
      ];
      sc.servers.assignAll(all);
      sc.current.value = all.first; 

      for (int i = 0; i < 7; i++) {
        sc.cacheTorrents('s$i', _many('s$i-', 10));
      }

      expect(sc.hasAnyCache('s0'), isTrue, reason: '当前服务器豁免');
      expect(sc.hasAnyCache('s6'), isTrue, reason: '最近写入的必须留着');
      final int alive = <int>[for (int i = 0; i < 7; i++) i]
          .where((int i) => sc.hasAnyCache('s$i'))
          .length;
      expect(alive, lessThanOrEqualTo(ServerController.kCacheMaxServers),
          reason: '★ 台数阀：最多留 ${ServerController.kCacheMaxServers} 台');
    });
  });

  group('第 58 轮 F · M3 trackerHost 提为 static final 后结果不变', () {
    test('F1 带 scheme 的完整 URL', () {
      expect(Formatter.trackerHost('https://tracker.example.com:6969/announce'),
          'tracker.example.com');
      expect(Formatter.trackerHost('http://www.pt.example.org/announce'),
          'pt.example.org', reason: '`www.` 前缀要被剥掉');
      expect(Formatter.trackerHost('udp://tracker.openbittorrent.com:80'),
          'tracker.openbittorrent.com');
    });

    test('F2 磁力链里 `&tr=` 的百分号编码值', () {
      expect(
        Formatter.trackerHost(
            'magnet:?xt=urn:btih:abc&tr=http%3A%2F%2Ftracker.example.com%3A6969%2Fannounce'),
        'tracker.example.com',
        reason: '先整体解码再截取 —— 否则会截出一串 %3A%2F%2F 乱码',
      );
    });

    test('F3 `&tr=` 的裸值（不带 scheme）', () {
      expect(
        Formatter.trackerHost('&tr=tracker.example.com:6969/announce'),
        'tracker.example.com',
      );
    });

    test('F4 取不到时返回 null（不抛）', () {
      expect(Formatter.trackerHost(null), isNull);
      expect(Formatter.trackerHost(''), isNull);
      expect(Formatter.trackerHost('   '), isNull);
      expect(Formatter.trackerHost('没有链接的纯文本'), isNull);
    });
  });
}
