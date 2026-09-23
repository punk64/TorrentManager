import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/data/models/server_data.dart';

ServerData _srv({
  required String host,
  int port = 8080,
  bool https = false,
  bool hideAddress = false,

  bool hidePort = false,
}) =>
    ServerData(
      id: 's1',
      name: 'n',
      type: 'qbittorrent',
      host: host,
      port: port,
      useHttps: https,
      hideAddress: hideAddress,
      hidePort: hidePort,
    );

void main() {
  group('http + IPv4', () {
    test('明文 http + IPv4 + 端口', () {
      expect(_srv(host: '192.168.1.5', port: 8080).baseUrl,
          'http://192.168.1.5:8080');
    });

    test('明文 http + IPv4 + 非默认端口', () {
      expect(_srv(host: '10.0.0.7', port: 55908).baseUrl,
          'http://10.0.0.7:55908');
    });

    test('https + IPv4', () {
      expect(_srv(host: '192.168.1.5', port: 8443, https: true).baseUrl,
          'https://192.168.1.5:8443');
      expect(_srv(host: '192.168.1.5', port: 443, https: true).baseUrl,
          'https://192.168.1.5');
    });

    test('主机里即便写成了 host:port，也要能剥出纯 IP', () {
      expect(_srv(host: '192.168.1.5:8080', port: 8080).normalizedHost,
          '192.168.1.5');
    });
  });

  group('IPv6', () {
    test('方括号形态的 IPv6 原样保留', () {
      expect(_srv(host: '[2001:db8::1]').normalizedHost, '[2001:db8::1]');
      expect(_srv(host: '[2001:db8::1]', port: 9091).baseUrl,
          'http://[2001:db8::1]:9091');
    });

    test('IPv6 隐藏地址后不泄漏原文', () {
      expect(_srv(host: '[2001:db8::1]', hideAddress: true).displayAddress,
          'http://[***]:8080');
    });
  });

  group('域名仍照常工作（不能被 IP 分支带偏）', () {
    test('http 域名', () {
      expect(_srv(host: 'bbb.dynv6.net', port: 55908).baseUrl,
          'http://bbb.dynv6.net:55908');
    });

    test('主机名恰好叫 https 时不能被当成 scheme', () {
      expect(_srv(host: 'https', port: 55908).normalizedHost, 'https');
      expect(_srv(host: 'https', port: 55908).baseUrl, 'http://https:55908',
          reason: '这是**主机名**就叫 https，语义上确实如此，仅固定当前行为');
    });
  });

  group('隐藏地址对 IP 生效', () {
    test('IPv4 隐藏后只留首段', () {
      expect(_srv(host: '192.168.1.5', hideAddress: true).displayAddress,
          'http://192.*.*.*:8080');
    });

    test('隐藏不影响真实连接地址', () {
      expect(_srv(host: '192.168.1.5', hideAddress: true).baseUrl,
          'http://192.168.1.5:8080');
    });

    test('★ 两个开关都用默认值时，地址与端口**都**打码（2026-09-20 起默认开启）',
        () {
      final ServerData s = ServerData(
        id: 's1',
        name: 'n',
        type: 'qbittorrent',
        host: '192.168.1.5',
        port: 8080,
      );
      expect(s.displayAddress, 'http://192.*.*.*:***',
          reason: '默认就是「不显示真实内容」：主机只留首段、端口整体打码');

      expect(s.baseUrl, 'http://192.168.1.5:8080');
    });
  });
}
