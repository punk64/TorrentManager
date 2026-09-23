







import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  
  
  
  
  setUp(() {
    
    
    
    
    SecurePrefs.useMemoryBackendForTest();
  });


  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall call) async => null);
    Get.testMode = true;
    Get.reset();
  });

  ServerData httpsServer() => ServerData(
        id: 's1',
        name: 'NAS',
        type: 'qbittorrent',
        host: 'ddns.example.com',
        port: 443,
        lanHost: '192.168.1.5',
        lanPort: 8080,
        useHttps: true,
      );

  group('★ 局域网目标强制 http（HTTPS 握手失败的根因）', () {
    test('公网仍是 https，切局域网后降为 http', () {
      final ServerData s = httpsServer();
      expect(s.baseUrl, 'https://ddns.example.com');

      final ServerData lan = s.connectionTarget(viaLan: true);
      expect(lan.baseUrl, 'http://192.168.1.5:8080',
          reason: '内网 IP 不可能有合法证书，局域网必须走 http');
      
      expect(s.connectionTarget(viaLan: false).baseUrl,
          'https://ddns.example.com');
    });

    test('未配置局域网时不改动 scheme', () {
      final ServerData s = ServerData(
        id: 's2',
        name: 'only-public',
        type: 'transmission',
        host: 'example.com',
        port: 9091,
        useHttps: true,
      );
      expect(s.connectionTarget(viaLan: true).baseUrl,
          'https://example.com:9091');
    });

    test('局域网地址里误填了 https:// 也会被剥掉', () {
      final ServerData s = httpsServer().copyWith(lanHost: 'https://192.168.1.5');
      expect(s.connectionTarget(viaLan: true).baseUrl,
          'http://192.168.1.5:8080');
    });
  });

  group('连接状态流转（卡片徽章）', () {
    test('connecting → ok → failed 三态与失败原因', () {
      final ServerController c = Get.put(ServerController());

      c.reportConnecting('s1');
      expect(c.connStatus['s1'], ConnStatus.connecting);
      expect(c.connError['s1'], isNull);

      c.reportConnected('s1');
      expect(c.connStatus['s1'], ConnStatus.ok);
      expect(c.connError['s1'], isNull,
          reason: '成功后必须清掉上一次的失败原因');

      c.reportFailure('s1', DioException(
        type: DioExceptionType.badCertificate,
        requestOptions: RequestOptions(path: '/api/v2/auth/login'),
      ));
      expect(c.connStatus['s1'], ConnStatus.failed);
      expect(c.connError['s1'], contains('HTTPS 证书校验失败'));
    });

    test('未知状态视为 idle（不该凭空出现徽章）', () {
      final ServerController c = Get.put(ServerController());
      expect(c.connStatus['nope'], isNull);
    });
  });
}
