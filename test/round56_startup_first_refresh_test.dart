import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/local/local_store.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/utils/lan_detector.dart';

ServerData _srv() => ServerData(
      id: 'qb-1',
      name: '家庭 NAS',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'admin',
      password: 'adminadmin',
    );

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

Dio _fakeQbDio(List<String> calls) {
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
        h.resolve(ok('v4.6.2'));
        return;
      }
      if (path.endsWith('/sync/maindata')) {
        h.resolve(ok(<String, dynamic>{
          'rid': 1,
          'server_state': <String, dynamic>{'queued_io_jobs': 0},
          'torrents': <String, dynamic>{},
        }));
        return;
      }
      h.resolve(ok(<String, dynamic>{}));
    },
  ));
  return dio;
}

Future<void> _pump([int times = 6]) async {
  for (int i = 0; i < times; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

int _countOf(List<String> calls, String path) =>
    calls.where((String c) => c.contains(path)).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
    Get.reset();

    LanDetector.overrideProbe = (_) async => false;
  });

  tearDown(() {
    LanDetector.overrideProbe = null;
    Get.reset();
  });

  test('第 56 轮 A · loadLocal 装进服务器后立刻补刷，不等 3 秒轮询', () async {
    await LocalStore.saveServers(<ServerData>[_srv()]);

    final List<String> calls = <String>[];
    final ServerController c = ServerController();
    c.qbFactory = () => QbMethod(dio: _fakeQbDio(calls));

    await c.loadLocal();
    expect(c.servers.length, 1, reason: '前置：本地确实读回了 1 台');
    await _pump();

    expect(_countOf(calls, '/sync/maindata'), 1,
        reason: '★ 补刷必须在 loadLocal 落定的那一刻就发出去 —— 否则首笔请求'
            '要干等 AutoRefresh 的第一个 3 秒周期（实测白等 2 秒，'
            '连第 55 轮刚压到 0.6 秒的探测结论都跟着浪费掉）');
  });

  test('第 56 轮 B · servers 为空时零请求（不破坏既有用例的时序前提）', () async {
    final List<String> calls = <String>[];
    final ServerController c = ServerController();
    c.qbFactory = () => QbMethod(dio: _fakeQbDio(calls));

    await c.loadLocal();
    await _pump();

    expect(c.servers, isEmpty, reason: '前置：本地没有服务器');
    expect(calls, isEmpty,
        reason: '★ 补刷走的是 `refreshAllServers()` 的**同步**早退分支'
            '（`if (servers.isEmpty) return;`）。这也是既有 '
            '`round14/18/43/47` 能安然无恙的原因 —— 那些用例里 LocalStore '
            '走内存后端、装进来的是空列表，补刷同步早退、零请求');
  });

  test('第 56 轮 C · 补刷不得抢在探测落地之前发请求', () async {
    await LocalStore.saveServers(<ServerData>[_lanSrv()]);

    final Completer<void> gate = Completer<void>();
    int probes = 0;
    LanDetector.overrideProbe = (_) async {
      probes++;
      await gate.future; 
      return false; 
    };

    final List<String> calls = <String>[];
    final ServerController c = ServerController();
    c.qbFactory = () => QbMethod(dio: _fakeQbDio(calls));

    await c.loadLocal();
    await _pump();
    expect(probes, 1, reason: '前置：loadLocal 末尾的 select() 起了探测');
    expect(calls, isEmpty,
        reason: '★ 探测还没落地 → **不许**发首笔请求。补刷是"提前那一拍"，'
            '不是"绕过第 55 轮的首笔等探测" —— 否则路由又变回猜，'
            '猜错的那次要等满 8 秒 connectTimeout');

    gate.complete();
    await _pump();
    expect(_countOf(calls, '/sync/maindata'), 1,
        reason: '探测一落地就立刻放行（这正是省下那 2 秒的机制）');
  });

  test('第 56 轮 D · 补刷与随后的手动刷新并发 → 同一台仍只有一笔', () async {
    await LocalStore.saveServers(<ServerData>[_srv()]);

    final List<String> calls = <String>[];
    final ServerController c = ServerController();
    c.qbFactory = () => QbMethod(dio: _fakeQbDio(calls));

    await c.loadLocal(); 
    await c.refreshAllServers(); 
    await _pump();

    expect(_countOf(calls, '/sync/maindata'), 1,
        reason: '★ `_serverInFlight` 守卫：同一台同时只有一笔。'
            '补刷只是把原定 3 秒那一拍**提前**，不是"多刷一遍"');
  });
}
