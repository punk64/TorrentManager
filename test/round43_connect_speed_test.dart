





















import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/utils/lan_detector.dart';



ServerData qbSrv() => ServerData(
      id: 'qb-1',
      name: '家庭 NAS',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'admin',
      password: 'adminadmin',
    );


ServerData lanSrv() => ServerData(
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

Map<String, dynamic> qbTorrentJson(String hash) => <String, dynamic>{
      'hash': hash,
      'name': '种子 $hash',
      'size': 10000000,
      'progress': 0.5,
      'state': 'downloading',
      'dlspeed': 1024,
      'upspeed': 512,
      'num_seeds': 3,
      'num_leechs': 1,
      'ratio': 1.5,
      'downloaded': 1000,
      'uploaded': 500,
      'num_complete': 9,
      'num_incomplete': 2,
      'save_path': '/downloads',
    };







Dio fakeQbDio(
  List<String> calls, {
  int total = 45,
  void Function(RequestOptions o)? onVersion,
}) {
  final Dio dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.1.10:8080',
    validateStatus: (int? s) => s != null && s < 500,
    followRedirects: false,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      final String path = o.uri.path;
      calls.add('${o.method} ${o.uri}');

      Response<dynamic> ok(Object? data) =>
          Response<dynamic>(requestOptions: o, statusCode: 200, data: data);

      if (path.endsWith('/auth/login')) {
        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: 'Ok.',
          headers: Headers.fromMap(<String, List<String>>{
            'set-cookie': <String>['SID=abc; path=/'],
          }),
        ));
        return;
      }
      if (path.endsWith('/app/version')) {
        onVersion?.call(o);
        h.resolve(ok('v5.0.5'));
        return;
      }
      if (path.endsWith('/app/webapiVersion')) {
        h.resolve(ok('2.11.2'));
        return;
      }
      if (path.endsWith('/sync/maindata')) {
        h.resolve(ok(<String, dynamic>{
          'rid': 1,
          'full_update': true,
          'server_state': <String, dynamic>{
            'dl_info_speed': 1024,
            'up_info_speed': 512,
          },
        }));
        return;
      }
      if (path.endsWith('/torrents/info')) {
        
        
        h.resolve(ok(List<Map<String, dynamic>>.generate(
          total,
          (int i) => qbTorrentJson('h$i'),
        )));
        return;
      }
      h.resolve(ok(<String, dynamic>{}));
    },
  ));
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.reset();
  });

  tearDown(() {
    LanDetector.overrideProbe = null;
    Get.reset();
  });

  

  test('第 43 轮 A · 列表页与 3 秒轮询共用同一客户端实例', () {
    final ServerController sc = ServerController();
    final ServerData s = qbSrv();
    sc.servers.assignAll(<ServerData>[s]);
    sc.current.value = s;

    
    
    expect(identical(sc.qb, sc.clientForQb(s.id)), isTrue,
        reason: '★ 会话池必须统一，否则登录态互不可见');
    
    expect(identical(sc.clientForQb(s.id), sc.clientForQb(s.id)), isTrue);
    
    final ServerData other = ServerData(
      id: 'qb-2',
      name: '另一台',
      type: 'qbittorrent',
      host: '10.0.0.9',
      port: 8080,
      username: 'u',
      password: 'p',
    );
    expect(identical(sc.clientForQb(s.id), sc.clientForQb(other.id)), isFalse);
  });

  test('第 43 轮 A2 · 换服务器后各自仍是自己的实例（不串台）', () {
    final ServerController sc = ServerController();
    final ServerData a = qbSrv();
    sc.servers.assignAll(<ServerData>[a]);
    sc.current.value = a;
    final QbMethod first = sc.qb;

    final ServerData b = ServerData(
      id: 'qb-2',
      name: '另一台',
      type: 'qbittorrent',
      host: '10.0.0.9',
      port: 8080,
      username: 'u',
      password: 'p',
    );
    sc.current.value = b;
    expect(identical(sc.qb, first), isFalse,
        reason: '换服务器后必须换到那台专属的实例');
    sc.current.value = a;
    expect(identical(sc.qb, first), isTrue, reason: '切回来还是原来那个');
  });

  

  test('第 43 轮 B · 探测请求用独立短超时，不再陪业务请求等 8 秒', () async {
    final List<String> calls = <String>[];
    int? probeConnectMs;
    int? probeReceiveMs;
    final QbMethod qb = QbMethod(
      dio: fakeQbDio(calls, onVersion: (RequestOptions o) {
        probeConnectMs = o.connectTimeout?.inMilliseconds;
        probeReceiveMs = o.receiveTimeout?.inMilliseconds;
      }),
    );
    final ServerData s = qbSrv();
    qb.setServer(s);
    await qb.checkQbServerCookie(s);

    expect(calls.any((String c) => c.contains('/app/version')), isTrue,
        reason: '前置：确实发了探测');
    
    
    expect(probeConnectMs, 600,
        reason: '★ 探测的连接超时必须是 0.6 秒'
            '（第 55 轮：原 1.5 秒实测在"打错路由"时纯属白等，与 LanDetector 同档压到 600ms）');
    expect(probeReceiveMs, 2500, reason: '★ 探测的接收超时必须是 2.5 秒');
  });

  

  test('第 43 轮 C · 记住局域网可达 → select 起步就走局域网', () {
    LanDetector.overrideProbe = (_) async => true;

    final ServerController sc = ServerController();
    final ServerData s = lanSrv();
    sc.servers.assignAll(<ServerData>[s]);
    sc.primeLanMemory(<String, bool>{s.id: true});
    sc.select(s);

    
    
    expect(sc.lanUsing[s.id], isTrue,
        reason: '★ 有记忆时必须立刻点亮局域网，不等探测回来');

    
    final ServerController fresh = ServerController();
    fresh.servers.assignAll(<ServerData>[s]);
    fresh.select(s);
    expect(fresh.lanUsing[s.id], isNull,
        reason: '无记忆时不该假装可达');
  });

  test('第 43 轮 C2 · 本机 IP 没变化就不重探局域网', () async {
    int probes = 0;
    LanDetector.overrideProbe = (_) async {
      probes++;
      return true;
    };
    final ServerController sc = ServerController();
    final ServerData s = lanSrv();
    sc.servers.assignAll(<ServerData>[s]);
    sc.current.value = s;

    await sc.runNetworkPollForTest();
    expect(probes, 0,
        reason: '★ IP 没变就一个请求都不该发（此前每 5 秒比一次，抖动即误报）');
  });

  

  
  
  
  
  
  

  test('★ 取消首屏分页 · 只发一笔全量，不带 limit', () async {
    final List<String> calls = <String>[];
    String? stageWhenListFetched;
    final ServerController sc = Get.put(ServerController(
      qb: QbMethod(dio: fakeQbDio(calls)),
    ));
    final TorrentController ctrl = Get.put(TorrentController());
    final ServerData s = qbSrv();
    
    
    
    
    await Future<void>.delayed(const Duration(milliseconds: 100));
    sc.servers.assignAll(<ServerData>[s]);
    
    
    sc.select(s);
    
    
    
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await ctrl.refresh();
    stageWhenListFetched = sc.stageTextOf(s.id);

    
    final List<String> infos = calls
        .where((String c) => c.contains('/torrents/info'))
        .toList(growable: false);

    expect(infos.length, 1,
        reason: '★ 取消分页后只该有一笔列表请求（原先是「首屏一页 + 全量」两笔）');
    expect(infos.single.contains('limit='), isFalse,
        reason: '★ 不再分页 ⇒ 请求里不该出现 limit 参数');
    expect(ctrl.items.length, 45, reason: '一次性拿回全量');
    expect(ctrl.isLoading.value, isFalse, reason: '刷新结束不该还挂着转圈');
    
    expect(stageWhenListFetched, isNull,
        reason: '★ 拉取完成后必须清掉阶段标记');
  });

  test('★ 取消首屏分页 · 后续刷新同样只有一笔全量（不再有分页请求）', () async {
    final List<String> calls = <String>[];
    final ServerController sc = Get.put(ServerController(
      qb: QbMethod(dio: fakeQbDio(calls)),
    ));
    final TorrentController ctrl = Get.put(TorrentController());
    final ServerData s = qbSrv();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    sc.servers.assignAll(<ServerData>[s]);
    sc.select(s);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await ctrl.refresh();
    expect(
        calls
            .where((String c) => c.contains('/torrents/info'))
            .length,
        1,
        reason: '★ 取消分页后，首次刷新就只发一笔');

    calls.clear();
    await ctrl.refresh();
    expect(
        calls
            .where((String c) => c.contains('/torrents/info'))
            .length,
        1,
        reason: '★ 第二笔刷新同样只是一笔全量');
    expect(calls.any((String c) => c.contains('limit=')), isFalse,
        reason: '★ 任何一轮都不该再出现 limit 参数');
  });

  

  test('第 43 轮 E · 连接进度分级：握手 → 拉列表', () {
    final ServerController sc = ServerController();
    final ServerData s = qbSrv();
    sc.servers.assignAll(<ServerData>[s]);

    sc.reportConnecting(s.id);
    expect(sc.stageTextOf(s.id), '正在连接服务器…');

    sc.reportStage(s.id, ConnStage.loading);
    expect(sc.stageTextOf(s.id), '正在获取种子列表…',
        reason: '★ 登录过了就该说「拉列表」，别让用户一直看「连接中」');

    sc.reportConnected(s.id);
    expect(sc.stageTextOf(s.id), isNull, reason: '连上后不该还挂着进度文案');
  });
}
