






















import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/utils/crypto_box.dart';



ServerData qbSrv(
  String id,
  String host, {
  int port = 8080,
  String? lanHost,
  int? lanPort,
  String? user = 'u',
  String? pass = 'p',
}) =>
    ServerData(
      id: id,
      name: 'NAS-$id',
      type: 'qbittorrent',
      host: host,
      port: port,
      lanHost: lanHost,
      lanPort: lanPort,
      username: user,
      password: pass,
    );






class _FakeQbServer implements HttpClientAdapter {
  _FakeQbServer(this.log);

  
  final List<String> log;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = o.uri.path;
    final String cookie = '${o.headers['cookie'] ?? ''}';
    int code = 200;
    String body = '[]';
    String? setCookie;

    if (path.contains('/auth/login')) {
      body = 'Ok.';
      
      setCookie = 'SID=${o.uri.host}; path=/';
    } else if (path.contains('/app/webapiVersion')) {
      body = '2.11.2';
    } else if (path.contains('/app/version')) {
      final bool authed = cookie.contains('SID=');
      code = authed ? 200 : 403;
      body = authed ? '4.6.2' : 'Forbidden';
    } else if (path.contains('maindata')) {
      body = jsonEncode(<String, dynamic>{
        'rid': 1,
        'server_state': <String, dynamic>{'queued_io_jobs': 1},
        'torrents': <String, dynamic>{},
      });
      log.add('$code ${o.method} ${o.uri.host}$path');
      return ResponseBody.fromString(
        body,
        code,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );
    }

    log.add('$code ${o.method} ${o.uri.host}$path');
    return ResponseBody.fromString(
      body,
      code,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/plain'],
        
        if (setCookie != null) 'set-cookie': <String>[setCookie],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}



QbMethod Function() _factory(_FakeQbServer server) => () {
      final Dio dio = Dio(BaseOptions(
        validateStatus: (int? s) => s != null && s < 500,
      ));
      dio.httpClientAdapter = server;
      return QbMethod(dio: dio);
    };

int _logins(List<String> log) =>
    log.where((String e) => e.contains('/auth/login')).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
    Get.reset();
    
    
    CryptoBox.testIterationsOverride = CryptoBox.minIterations;
  });

  tearDown(() {
    CryptoBox.testIterationsOverride = null;
  });

  

  group('★ 客户端实例复用：不再每 3 秒重登一次', () {
    test('首次连接登录一次；第二轮轮询**不再登录**（cookie 保住了）', () async {
      final List<String> log = <String>[];
      final ServerController sc = ServerController();
      sc.qbFactory = _factory(_FakeQbServer(log));
      sc.servers.assignAll(<ServerData>[qbSrv('a', '10.0.0.1')]);

      
      await sc.refreshAllServers();
      expect(_logins(log), 1, reason: '首次连接总要建立一次会话');
      expect(
        log.any((String e) => e.startsWith('403 GET 10.0.0.1/api/v2/app/version')),
        isTrue,
        reason: '★ 复现原现象：新建客户端的首次探测是 403',
      );
      expect(
        log.any((String e) => e.startsWith('200 GET 10.0.0.1/api/v2/sync/maindata')),
        isTrue,
        reason: '登录成功后卡片数据要正常取到',
      );
      expect(sc.connStatus['a'], ConnStatus.ok);

      
      log.clear();
      await sc.refreshAllServers();
      expect(_logins(log), 0,
          reason: '★ 这正是用户报的「每 3 秒重新登录一次」，修复后必须为 0');
      expect(
        log.any((String e) => e.startsWith('200 GET 10.0.0.1/api/v2/app/version')),
        isTrue,
        reason: '复用实例后探测应恢复正常（200）',
      );
      expect(sc.connStatus['a'], ConnStatus.ok);
    });

    test('多台服务器各自独立会话，互不串台（也不互相顶掉 cookie）', () async {
      final List<String> log = <String>[];
      final ServerController sc = ServerController();
      sc.qbFactory = _factory(_FakeQbServer(log));
      sc.servers.assignAll(<ServerData>[
        qbSrv('a', '10.0.0.1'),
        qbSrv('b', '10.0.0.2'),
      ]);

      await sc.refreshAllServers();
      expect(_logins(log), 2, reason: '两台各自建立一次会话');

      log.clear();
      await sc.refreshAllServers();
      expect(_logins(log), 0, reason: '★ 两台的会话都该保住（此前是两台各重登一次）');
      expect(sc.connStatus['a'], ConnStatus.ok);
      expect(sc.connStatus['b'], ConnStatus.ok);
    });

    test('★ 编辑保存会丢弃缓存 → 重新握手一次（换配置必须换会话）', () async {
      final List<String> log = <String>[];
      final ServerController sc = ServerController();
      sc.qbFactory = _factory(_FakeQbServer(log));
      sc.servers.assignAll(<ServerData>[qbSrv('a', '10.0.0.1')]);

      await sc.refreshAllServers();
      log.clear();
      await sc.refreshAllServers();
      expect(_logins(log), 0, reason: '缓存生效');

      
      
      
      
      
      
      
      
      
      log.clear();
      await sc.updateServer(qbSrv('a', '10.0.0.1', port: 8081));
      
      
      
      
      await sc.refreshAllServers();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(_logins(log), 1,
          reason: '★ 改过配置后必须重新建立会话，而不是继续用旧实例的 cookie');
      expect(log.any((String e) => e.contains('10.0.0.1/api/v2/app/version')),
          isTrue);
    });

    test('删除服务器会一并丢弃其缓存实例（再添加时不残留旧会话）', () async {
      final List<String> log = <String>[];
      final ServerController sc = ServerController();
      sc.qbFactory = _factory(_FakeQbServer(log));
      sc.servers.assignAll(<ServerData>[qbSrv('a', '10.0.0.1')]);

      await sc.refreshAllServers();
      await sc.deleteServer('a');
      sc.servers.assignAll(<ServerData>[qbSrv('a', '10.0.0.1')]);
      log.clear();
      await sc.refreshAllServers();
      expect(_logins(log), 1,
          reason: '★ 删除后再添加属于「新的一台」，应当重新握手');
    });
  });

  

  group('★ 轮询选路：局域网可达就该打内网地址', () {
    test('lanUsing 为真 → 请求打到局域网地址；为假 → 打公网', () async {
      final List<String> log = <String>[];
      final ServerController sc = ServerController();
      sc.qbFactory = _factory(_FakeQbServer(log));
      sc.servers.assignAll(<ServerData>[
        qbSrv('a', 'nas.example.com',
            port: 443, lanHost: '192.168.1.50', lanPort: 8080),
      ]);

      await sc.refreshAllServers();
      expect(log.any((String e) => e.contains('nas.example.com')), isTrue);
      expect(log.any((String e) => e.contains('192.168.1.50')), isFalse,
          reason: '未标记局域网时维持公网（与改动前行为一致）');

      
      sc.lanUsing['a'] = true;
      log.clear();
      await sc.refreshAllServers();
      expect(log.any((String e) => e.contains('192.168.1.50')), isTrue,
          reason: '★ 这正是日志里「已切局域网却仍打公网」的修复');
      expect(log.any((String e) => e.contains('nas.example.com')), isFalse,
          reason: '切到局域网后不该再走公网');
    });
  });

  

  group('★ 默认端口 443：baseUrl 的规范化', () {
    ServerData s({required int port, required bool https}) => ServerData(
          id: 'x',
          name: 'n',
          type: 'qbittorrent',
          host: 'nas.example.com',
          port: port,
          useHttps: https,
        );

    test('443 + https → 省略端口，得到干净的 https://域名', () {
      expect(s(port: 443, https: true).baseUrl, 'https://nas.example.com');
    });

    test('443 + http → 端口不会被省略（故新建必须默认开启 HTTPS）', () {
      expect(s(port: 443, https: false).baseUrl, 'http://nas.example.com:443');
    });

    test('非默认端口照常保留', () {
      expect(s(port: 8443, https: true).baseUrl, 'https://nas.example.com:8443');
      expect(s(port: 8080, https: false).baseUrl, 'http://nas.example.com:8080');
    });
  });
}
