import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/prefs/server_prefs.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';

ServerData srvA() => ServerData(
      id: 'srv-a',
      name: 'qB 主',
      type: 'qbittorrent',
      host: '192.168.1.5',
      port: 8080,
      username: 'admin',
      password: 'secret',
    );

ServerData srvB() => ServerData(
      id: 'srv-b',
      name: 'qB 备',
      type: 'qbittorrent',
      host: '192.168.1.5', 
      port: 8081, 
      username: 'admin',
      password: 'secret',
    );

Map<String, dynamic> qbTorrentJson(String hash, String name) =>
    <String, dynamic>{
      'hash': hash,
      'name': name,
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

class _FakeTwoQb {
  static const int aCount = 2;
  static const int bCount = 3;

  final List<String> hits = <String>[];

  final Map<int, List<Map<String, dynamic>>> written =
      <int, List<Map<String, dynamic>>>{};

  final Set<int> loggedIn = <int>{};

  int countForPort(int port) =>
      hits.where((String h) => h.endsWith(':$port')).length;

  Dio dio() {
    final Dio d = Dio(BaseOptions(
      validateStatus: (int? s) => s != null && s < 500,
      followRedirects: false,
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) {
        final int port = o.uri.port;
        hits.add('${o.uri.host}:$port');
        final String p = o.uri.path.replaceFirst('/api/v2', '');

        Response<dynamic> res(Object? data, {int code = 200}) =>
            Response<dynamic>(
                requestOptions: o, statusCode: code, data: data);

        if (p.endsWith('/auth/login')) {
          loggedIn.add(port);
          h.resolve(res('Ok.'));
          return;
        }

        if (!loggedIn.contains(port)) {
          h.resolve(res('Forbidden', code: 403));
          return;
        }
        if (p.endsWith('/app/version')) {
          h.resolve(res('v5.0.5'));
          return;
        }
        if (p.endsWith('/app/webapiVersion')) {
          h.resolve(res('2.11.2'));
          return;
        }
        if (p.endsWith('/sync/maindata')) {
          final bool isA = port == 8080;
          final int n = isA ? aCount : bCount;
          h.resolve(res(<String, dynamic>{
            'rid': 1,
            'full_update': true,
            'server_state': <String, dynamic>{
              'up_info_speed': isA ? 111111 : 999999,
              'dl_info_speed': isA ? 222222 : 888888,
            },
            'torrents': <String, dynamic>{
              for (int i = 0; i < n; i++)
                '${isA ? 'a' : 'b'}$i': qbTorrentJson(
                  '${isA ? 'a' : 'b'}$i',
                  '${isA ? 'A' : 'B'} 种子$i',
                ),
            },
          }));
          return;
        }
        if (p.endsWith('/app/setPreferences')) {
          final dynamic body = o.data;
          final String raw = body is FormData
              ? body.fields
                  .where((MapEntry<String, String> e) => e.key == 'json')
                  .map((MapEntry<String, String> e) => e.value)
                  .join()
              : '$body';
          try {
            written
                .putIfAbsent(port, () => <Map<String, dynamic>>[])
                .add(Map<String, dynamic>.from(jsonDecode(raw) as Map));
          } catch (_) {
            written
                .putIfAbsent(port, () => <Map<String, dynamic>>[])
                .add(<String, dynamic>{'RAW': raw});
          }
          h.resolve(res(''));
          return;
        }
        if (p.endsWith('/app/preferences')) {
          h.resolve(res(<String, dynamic>{
            'save_path': '/downloads',
            'up_limit': port == 8080 ? 1048576 : 2097152,
            'dl_limit': port == 8080 ? 2097152 : 4194304,
          }));
          return;
        }
        h.resolve(res(<String, dynamic>{}));
      },
    ));
    return d;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  test('① 同 host 不同端口 → 两个独立实例（CookieJar 不区分端口，绝不能共用）',
      () {
    final ServerController sc = ServerController();
    final ServerData a = srvA();
    final ServerData b = srvB();
    sc.servers.assignAll(<ServerData>[a, b]);

    final QbMethod ca = sc.clientForQb(a.id);
    final QbMethod cb = sc.clientForQb(b.id);

    expect(identical(ca, cb), isFalse,
        reason: '★ CookieJar 只按 domain 存、不区分端口 —— '
            '两台共用实例会让后登录的那台顶掉前一台的 SID');

    expect(identical(ca, sc.clientForQb(a.id)), isTrue);
    expect(identical(cb, sc.clientForQb(b.id)), isTrue);
  });

  test('② 并发刷新两台：各自 torrentsOf 只含自己的种子，互不污染', () async {
    final _FakeTwoQb fake = _FakeTwoQb();
    final ServerController sc = ServerController();
    final ServerData a = srvA();
    final ServerData b = srvB();
    sc.servers.assignAll(<ServerData>[a, b]);
    sc.current.value = a;
    sc.qbFactory = () => QbMethod(dio: fake.dio());

    await sc.refreshAllServers();

    final List<String> namesA = sc
        .torrentsOf(a.id)
        .map((t) => t.name)
        .toList()
      ..sort();
    final List<String> namesB = sc
        .torrentsOf(b.id)
        .map((t) => t.name)
        .toList()
      ..sort();

    expect(namesA, <String>['A 种子0', 'A 种子1']);
    expect(namesB, <String>['B 种子0', 'B 种子1', 'B 种子2']);

    expect(fake.countForPort(8080), greaterThan(0));
    expect(fake.countForPort(8081), greaterThan(0));

    expect(fake.loggedIn, containsAll(<int>[8080, 8081]));
  });

  test('③ 全局 state 只写当前服务器，不被另一台的后台刷新覆盖', () async {
    final _FakeTwoQb fake = _FakeTwoQb();
    final ServerController sc = ServerController();
    final ServerData a = srvA();
    final ServerData b = srvB();
    sc.servers.assignAll(<ServerData>[a, b]);
    sc.current.value = a; 
    sc.qbFactory = () => QbMethod(dio: fake.dio());

    await sc.refreshAllServers();

    expect(sc.state.value.upInfoSpeed, 111111,
        reason: '全局 state 属于**当前**服务器，B 的轮询不该动它');
    expect(sc.state.value.dlInfoSpeed, 222222);

    expect(sc.torrentsOf(a.id).length, 2);
  });

  test('④ lanUsing 按 id 隔离：一台走局域网，不会把另一台也拽过去', () {
    final ServerController sc = ServerController();
    final ServerData a = ServerData(
      id: 'srv-a',
      name: 'NAS',
      type: 'qbittorrent',
      host: 'nas.example.com',
      port: 8080,
      lanHost: '192.168.1.5',
      lanPort: 8080,
      username: 'admin',
      password: 'secret',
    );
    final ServerData b = ServerData(
      id: 'srv-b',
      name: 'VPS',
      type: 'qbittorrent',
      host: 'vps.example.com',
      port: 8080,
      lanHost: '192.168.1.9',
      lanPort: 8080,
      username: 'admin',
      password: 'secret',
    );

    sc.lanUsing[a.id] = true;

    expect(sc.targetFor(a).baseUrl, 'http://192.168.1.5:8080');
    expect(sc.targetFor(b).baseUrl, 'http://vps.example.com:8080',
        reason: 'B 没被探测过 → 必须维持公网，不能被 A 的结论带跑');
  });

  test('⑤ 两台服务器的偏好读回各自的值，写只落到自己那个端口', () async {
    final _FakeTwoQb fake = _FakeTwoQb();
    final ServerData a = srvA();
    final ServerData b = srvB();

    final ServerController sc = ServerController();
    sc.servers.assignAll(<ServerData>[a, b]);
    sc.qbFactory = () => QbMethod(dio: fake.dio());
    final QbPrefsApi apiA = QbPrefsApi(
        client: sc.clientForQb(a.id), resolve: sc.targetFor);
    final QbPrefsApi apiB = QbPrefsApi(
        client: sc.clientForQb(b.id), resolve: sc.targetFor);

    apiA.attach(a);
    apiB.attach(b);
    await apiA.ensureSession();
    await apiB.ensureSession();

    expect((await apiA.read())[PrefKey.upLimit], 1048576,
        reason: 'A（8080）的上传限速');
    expect((await apiB.read())[PrefKey.upLimit], 2097152,
        reason: 'B（8081）的上传限速 —— 与 A 不同，串台会立刻暴露');

    await apiA.write(<String, dynamic>{PrefKey.dlLimit: 512 * 1024});

    expect(fake.written[8081], isNull,
        reason: '★ 改 A 的偏好绝不能打到 B 的端口上');
    expect(fake.written[8080], isNotNull);
    expect(fake.written[8080]!.last, <String, dynamic>{'dl_limit': 524288});
  });
}
