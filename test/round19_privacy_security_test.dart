









import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/dio/redirect_interceptor.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/utils/crypto_box.dart';
import 'package:torrent_manager/utils/formatter.dart';


class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.script);

  final List<ResponseBody Function(RequestOptions)> script;
  final List<String> requested = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.uri.toString());
    final int i = requested.length - 1;
    return script[i < script.length ? i : script.length - 1](options);
  }

  @override
  void close({bool force = false}) {}
}





Dio _dioWithRedirect(HttpClientAdapter adapter) {
  final Dio dio = Dio(BaseOptions(
    baseUrl: 'http://nas.local:8080',
    followRedirects: false,
    validateStatus: (int? s) => s != null && s < 500,
  ));
  dio.interceptors.add(RedirectInterceptor(dio: dio));
  dio.httpClientAdapter = adapter;
  return dio;
}

ResponseBody _redirect(String location) => ResponseBody.fromString(
      '',
      302,
      headers: <String, List<String>>{
        
        
        'location': <String>[location],
      },
    );

ServerData _srv() => ServerData(
      id: 'a',
      name: 'NAS',
      type: 'qbittorrent',
      host: '192.168.1.5',
      port: 8080,
    );






Future<ServerController> _newServerController() async {
  final ServerController sc = Get.put(ServerController());
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return sc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall call) async => null);
    Get.testMode = true;
    Get.reset();
  });

  
  
  
  group('① 隐私开关默认打开（隐藏站点 / 地址 / 端口 / 日志 IP）', () {
    test('★ 新建服务器即默认隐藏地址与端口，卡片上不再是真实内容', () {
      final ServerData s = _srv();
      expect(s.hideAddress, isTrue,
          reason: '★ 用户要求「默认就是不显示真实内容」');
      expect(s.hidePort, isTrue);

      final String shown = s.displayAddress;
      expect(shown.contains('192.168.1.5'), isFalse,
          reason: '★ 卡片上不得出现真实 IP（$shown）');
      expect(shown.contains('8080'), isFalse,
          reason: '★ 卡片上不得出现真实端口（$shown）');
    });

    test('★ 老数据（落盘里没有这两个键）也按「隐藏」处理', () {
      final ServerData s = ServerData.fromJson(<String, dynamic>{
        'id': 'a',
        'name': 'NAS',
        'type': 'qbittorrent',
        'host': '10.0.0.2',
        'port': 9091,
      });
      expect(s.hideAddress, isTrue);
      expect(s.hidePort, isTrue);
      expect(s.displayAddress.contains('10.0.0.2'), isFalse);
    });

    test('★ 反向：用户关掉开关后必须能读回 false（否则永远关不掉）', () {
      final ServerData off = ServerData(
        id: 'a',
        name: 'NAS',
        type: 'qbittorrent',
        host: '192.168.1.5',
        port: 8080,
        hideAddress: false,
        hidePort: false,
      );
      final Map<String, dynamic> j = off.toJson();
      
      
      
      expect(j.containsKey('hideAddress'), isTrue,
          reason: '★ `hideAddress` 必须**总是**落盘');
      expect(j.containsKey('hidePort'), isTrue, reason: '★ `hidePort` 同上');

      final ServerData back = ServerData.fromJson(j);
      expect(back.hideAddress, isFalse);
      expect(back.hidePort, isFalse);
      
      expect(back.displayAddress.contains('192.168.1.5'), isTrue);
    });

    test('★ 站点打码默认开启（含落盘缺省值）', () async {
      
      Get.put(ServerController());
      final TorrentController tc = Get.put(TorrentController());
      expect(tc.siteMasked.value, isTrue, reason: '★ 默认不显示真实站点名');
      
      await tc.loadSiteMasked();
      expect(tc.siteMasked.value, isTrue,
          reason: '★ 缺省值必须也是「打码」——否则老用户升级后等于没开');
    });
  });

  
  
  
  group('② 备份恢复拒绝明文回落（防伪造备份注入）', () {
    test('★ 备份文件是明文 JSON 时必须拒绝，绝不能当配置导入', () async {
      final Directory dir =
          await Directory.systemTemp.createTemp('torrentmanager_r19_');
      addTearDown(() => dir.delete(recursive: true));

      final ServerController sc = await _newServerController();
      sc.backupDir.value = dir.path;
      
      await File(sc.backupFilePath!).writeAsString(
        '[{"id":"evil","name":"evil","type":"qbittorrent",'
        '"host":"evil.example","port":8080}]',
      );

      await expectLater(
        sc.restoreBackup(),
        throwsA(isA<CryptoBoxException>()),
        reason: '★ 此前 `tryDecrypt` 返回 null 时会回落成"按明文解析" —— '
            '任何能往备份目录写文件的东西都能借此注入伪造服务器',
      );
      expect(sc.servers.any((ServerData s) => s.host == 'evil.example'), isFalse,
          reason: '★ 被拒绝的文件不得产生任何服务器条目');
    });

    test('★ 真正的加密备份仍能正常恢复（修复没有把功能一起关掉）', () async {
      final Directory dir =
          await Directory.systemTemp.createTemp('torrentmanager_r19_ok_');
      addTearDown(() => dir.delete(recursive: true));

      final ServerController sc = await _newServerController();
      sc.backupDir.value = dir.path;
      sc.servers.assignAll(<ServerData>[_srv()]);

      await sc.saveBackup();
      
      sc.servers.clear();
      final int added = await sc.restoreBackup();
      expect(added, 1);
      expect(sc.servers.single.host, '192.168.1.5');
    });
  });

  
  
  
  group('③ qB 重定向：跨主机一律拒绝', () {
    test('★ 判定规则：同主机放行（换端口 / http→https），跨主机与降级拒绝', () {
      final Uri from = Uri.parse('http://nas.local:8080/api/v2/app/version');
      expect(RedirectInterceptor.isAllowed(
          from, Uri.parse('http://nas.local:8080/api/v2/app/version')), isTrue);
      expect(RedirectInterceptor.isAllowed(
          from, Uri.parse('http://nas.local:443/api')), isTrue,
          reason: '反代换端口是常见配置');
      expect(RedirectInterceptor.isAllowed(
          from, Uri.parse('https://nas.local/api')), isTrue,
          reason: 'http→https 是升级，允许');
      expect(RedirectInterceptor.isAllowed(
          from, Uri.parse('http://evil.example/api')), isFalse,
          reason: '★ 跨主机：登录 SID 跟着 302 走等于把会话送给第三方');
      expect(RedirectInterceptor.isAllowed(
          from, Uri.parse('https://evil.example/api')), isFalse);
      expect(
        RedirectInterceptor.isAllowed(
            Uri.parse('https://nas.local/a'), Uri.parse('http://nas.local/a')),
        isFalse,
        reason: '★ https→http 降级：等于把凭据换成明文再送一遍',
      );
    });

    test('★ 真的收到跨主机 302：请求失败，且**不会**向第三方再发一次', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter(
        <ResponseBody Function(RequestOptions)>[
          (RequestOptions o) => _redirect('http://evil.example/steal'),
          (RequestOptions o) => ResponseBody.fromString('{}', 200),
        ],
      );
      final Dio dio = _dioWithRedirect(adapter);

      await expectLater(
        dio.get<dynamic>('/api/v2/app/version'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requested.length, 1,
          reason: '★ 拦截器必须直接拒绝 —— 若这里变成 2，说明凭据已经被送到 evil.example');
    });

    test('★ 同主机 302：正常跟随（反代场景不能坏）', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter(
        <ResponseBody Function(RequestOptions)>[
          (RequestOptions o) =>
              _redirect('http://nas.local:8080/api/v2/app/version'),
          (RequestOptions o) => ResponseBody.fromString('"ok"', 200),
        ],
      );
      final Dio dio = _dioWithRedirect(adapter);

      final Response<dynamic> r = await dio.get<dynamic>('/api/v2/app/version');
      expect(r.statusCode, 200);
      expect(adapter.requested.length, 2,
          reason: '同主机跳转要继续跟随（否则反向代理下的服务器全都连不上）');
    });
  });

  
  
  
  group('④ tracker 复制到剪贴板时 passkey 已打码', () {
    test('★ passkey 不得出现在复制内容里，主机仍可辨识', () {
      const String url =
          'https://tracker.example.com/announce?passkey=abcdef1234567890';
      final String masked = Formatter.maskUrl(url);
      expect(masked.contains('abcdef1234567890'), isFalse,
          reason: '★ passkey 是该站的私密下载凭证，剪贴板全系统可读');
      expect(masked.contains('tracker.example.com'), isTrue,
          reason: '主机保留可辨识度（打码只针对凭据）');
    });
  });
}
