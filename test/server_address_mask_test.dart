import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/utils/formatter.dart';

ServerData _server({
  required String host,
  required bool hideAddress,
  int port = 8080,
  bool useHttps = false,
  bool hidePort = false,
}) =>
    ServerData(
      id: 's1',
      name: '测试服务器',
      type: 'qbittorrent',
      host: host,
      port: port,
      useHttps: useHttps,
      hideAddress: hideAddress,
      hidePort: hidePort,
    );

void main() {
  group('Formatter.maskHost', () {
    test('IPv4 保留首段，其余打码', () {
      expect(Formatter.maskHost('192.168.1.5'), '192.*.*.*');
    });

    test('域名只留顶级域', () {
      expect(Formatter.maskHost('bbb.dynv6.net'), '***.net');
      expect(Formatter.maskHost('example.com'), '***.com');
    });

    test('IPv6 与单段名整体打码', () {
      expect(Formatter.maskHost('[2001:db8::1]'), '[***]');
      expect(Formatter.maskHost('localhost'), '***');
      expect(Formatter.maskHost(''), '***');
    });
  });

  group('ServerData.displayAddress', () {
    test('未开启隐藏 → 显示完整地址', () {
      final ServerData s = _server(host: '192.168.1.5', hideAddress: false);
      expect(s.displayAddress, 'http://192.168.1.5:8080');
    });

    test('开启隐藏 → 地址必须真的变了（修复前两者完全相同）', () {
      final ServerData shown = _server(host: '192.168.1.5', hideAddress: false);
      final ServerData hidden = _server(host: '192.168.1.5', hideAddress: true);

      expect(hidden.displayAddress, isNot(shown.displayAddress),
          reason: '隐藏开关必须改变显示文本，否则等于没实现');
      expect(hidden.displayAddress, 'http://192.*.*.*:8080');

      expect(hidden.displayAddress, isNot(contains('192.168.1.5')));
    });

    test('域名地址隐藏后不泄漏主机名', () {
      final ServerData s = _server(
        host: 'bbb.dynv6.net',
        hideAddress: true,
        port: 55908,
        useHttps: true,
      );
      expect(s.displayAddress, 'https://***.net:55908');
      expect(s.displayAddress, isNot(contains('bbb.dynv6.net')));
    });

    test('隐藏只影响显示，不影响真实连接地址', () {
      final ServerData s = _server(host: '192.168.1.5', hideAddress: true);
      expect(s.baseUrl, 'http://192.168.1.5:8080');
    });
  });

  group('屏蔽端口（2026-09-17 新增，与隐藏域名相互独立）', () {
    test('只开屏蔽端口 → 主机原样、端口打码', () {
      final ServerData s = _server(host: '192.168.1.5', hideAddress: false,
          hidePort: true);
      expect(s.displayAddress, 'http://192.168.1.5:***');
    });

    test('两个开关都开 → 主机与端口都打码', () {
      final ServerData s = _server(host: 'bbb.dynv6.net', hideAddress: true,
          hidePort: true, port: 55908, useHttps: true);
      expect(s.displayAddress, 'https://***.net:***');
      expect(s.displayAddress, isNot(contains('55908')));
    });

    test('关闭屏蔽端口 → 端口照常显示', () {
      final ServerData s = _server(host: '192.168.1.5', hideAddress: true,
          hidePort: false);
      expect(s.displayAddress, 'http://192.*.*.*:8080');
    });

    test('屏蔽端口不影响真实连接地址', () {
      final ServerData s = _server(host: '192.168.1.5', hideAddress: true,
          hidePort: true);
      expect(s.baseUrl, 'http://192.168.1.5:8080');
    });

    test('hidePort 往返序列化不丢失', () {
      final ServerData s = _server(host: '192.168.1.5', hideAddress: true,
          hidePort: true);
      final ServerData back = ServerData.fromJson(s.toJson());
      expect(back.hidePort, true);
      expect(back.hideAddress, true);
    });
  });
}
