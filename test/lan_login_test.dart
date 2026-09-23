import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/utils/lan_detector.dart';

ServerData _publicOnly() => ServerData(
      id: 's1',
      name: '家里 NAS',
      type: 'qbittorrent',
      host: 'nas.example.com',
      port: 8080,
    );

ServerData _withLan() => ServerData(
      id: 's2',
      name: '家里 NAS',
      type: 'qbittorrent',
      host: 'nas.example.com',
      port: 8080,
      lanHost: '192.168.1.5',
      lanPort: 8080,
    );

void main() {
  tearDown(() {
    LanDetector.overrideProbe = null;
    LanDetector.overrideTcp = null;
  });

  group('ServerData 局域网字段', () {
    test('未填局域网时 hasLan 为 false', () {
      expect(_publicOnly().hasLan, isFalse);
    });

    test('只填地址不填端口时 hasLan 为 false（必须成对）', () {
      final s = _publicOnly().copyWith(lanHost: '192.168.1.5');
      expect(s.hasLan, isFalse);
    });

    test('地址+端口都填时 hasLan 为 true', () {
      expect(_withLan().hasLan, isTrue);
    });

    test('connectionTarget(viaLan:false) 原样返回', () {
      final s = _withLan();
      final t = s.connectionTarget(viaLan: false);
      expect(t.host, 'nas.example.com');
      expect(t.port, 8080);
      expect(t, same(s)); 
    });

    test('connectionTarget(viaLan:true) 把 host/port 换成局域网', () {
      final s = _withLan();
      final t = s.connectionTarget(viaLan: true);
      expect(t.host, '192.168.1.5');
      expect(t.port, 8080);

      expect(t.lanHost, '192.168.1.5');
      expect(t.lanPort, 8080);

      expect(t.baseUrl, 'http://192.168.1.5:8080');
    });

    test('未配置局域网时 connectionTarget(viaLan:true) 仍走公网', () {
      final s = _publicOnly();
      final t = s.connectionTarget(viaLan: true);
      expect(t.host, 'nas.example.com');
    });
  });

  group('JSON 序列化往返', () {
    test('lanHost / lanPort 写进 toJson 且能从 fromJson 还原', () {
      final s = _withLan();
      final Map<String, dynamic> json = s.toJson();
      expect(json['lanHost'], '192.168.1.5');
      expect(json['lanPort'], 8080);
      final back = ServerData.fromJson(json);
      expect(back.lanHost, '192.168.1.5');
      expect(back.lanPort, 8080);
      expect(back.hasLan, isTrue);
    });

    test('未填局域网时不写 lan 字段', () {
      final json = _publicOnly().toJson();
      expect(json.containsKey('lanHost'), isFalse);
      expect(json.containsKey('lanPort'), isFalse);
    });

    test('旧数据（无 lan 字段）fromJson 后 hasLan 为 false 且不崩溃', () {
      final back = ServerData.fromJson(<String, dynamic>{
        'id': 'x',
        'name': 'n',
        'type': 'qbittorrent',
        'host': 'h',
        'port': 8080,
      });
      expect(back.lanHost, isNull);
      expect(back.lanPort, isNull);
      expect(back.hasLan, isFalse);
    });
  });

  group('LanDetector 探测入口', () {
    test('overrideProbe 返回 true → isOnLan 为 true（仅当已配置局域网）', () async {
      LanDetector.overrideProbe = (_) async => true;
      expect(await LanDetector.isOnLan(_withLan()), isTrue);
    });

    test('overrideProbe 返回 false → isOnLan 为 false', () async {
      LanDetector.overrideProbe = (_) async => false;
      expect(await LanDetector.isOnLan(_withLan()), isFalse);
    });

    test('未配置局域网时，无论探测结果如何都返回 false', () async {
      LanDetector.overrideProbe = (_) async => true;
      expect(await LanDetector.isOnLan(_publicOnly()), isFalse,
          reason: '没填局域网地址就不该切局域网');
    });
  });

  group('★ 回归：网段快判不得否决连接尝试', () {
    Future<bool> probeWith(bool tcpResult, void Function(String, int) onCall) async {
      LanDetector.overrideTcp = (String h, int p) async {
        onCall(h, p);
        return tcpResult;
      };
      return LanDetector.isOnLan(_withLan())
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
    }

    test('即便快判不在同网段，也必须真的发起一次连接尝试', () async {
      int calls = 0;
      String? gotHost;
      int? gotPort;
      final bool onLan = await probeWith(true, (String h, int p) {
        calls++;
        gotHost = h;
        gotPort = p;
      });
      expect(calls, 1, reason: '必须发起且只发起一次连接尝试（不能被快判短路）');
      expect(gotHost, '192.168.1.5');
      expect(gotPort, 8080);
      expect(onLan, isTrue);
    });

    test('连接尝试失败 → 回落公网（isOnLan 为 false）', () async {
      final bool onLan = await probeWith(false, (String h, int p) {});
      expect(onLan, isFalse);
    });

    test('未配置局域网时不发起任何连接尝试', () async {
      int calls = 0;
      LanDetector.overrideTcp = (String h, int p) async {
        calls++;
        return true;
      };
      expect(await LanDetector.isOnLan(_publicOnly()), isFalse);
      expect(calls, 0);
    });
  });
}
