import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/prefs/server_prefs.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/utils/app_log.dart';

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
          'server_state': <String, dynamic>{
            'queued_io_jobs': 0,
            'use_alt_speed_limits': true,
          },
          'torrents': <String, dynamic>{},
        }));
        return;
      }
      if (path.endsWith('/app/preferences')) {
        h.resolve(ok(<String, dynamic>{'up_limit': 4096, 'save_path': '/dl'}));
        return;
      }
      if (path.endsWith('/torrents/tags')) {
        h.resolve(ok(<String>['t1']));
        return;
      }
      if (path.endsWith('/torrents/categories')) {
        h.resolve(ok(<String, dynamic>{'c1': <String, dynamic>{}}));
        return;
      }
      h.resolve(ok(<String, dynamic>{}));
    },
  ));
  return dio;
}

Future<void> _pump([int times = 8]) async {
  for (int i = 0; i < times; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
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
    AppLog.instance.clear();
    ServerController.prefsPrefetchEnabled = false;
  });

  tearDown(() {
    ServerController.prefsPrefetchEnabled = false;
  });

  ServerData mk(String id, String name) => ServerData(
        id: id,
        name: name,
        type: 'qbittorrent',
        host: '192.168.1.10',
        port: 8080,
        username: 'admin',
        password: 'adminadmin',
      );

  group('★ 服务器数量上限（50）', () {
    test('★ 满 50 后：addServer / updateServer 新增分支都被拒，长度不变', () async {
      final ServerController c = Get.put(ServerController());
      await c.loadLocal();

      c.servers.assignAll(
        List<ServerData>.generate(
            ServerController.kMaxServers, (int i) => mk('s$i', 'S$i')),
      );
      expect(c.servers.length, ServerController.kMaxServers);

      final bool rejectedAdd = await c.addServer(mk('x', 'X'));
      expect(rejectedAdd, isFalse, reason: '★ 达到上限后不得再新增');
      expect(c.servers.length, ServerController.kMaxServers);

      final bool rejectedUpdate = await c.updateServer(mk('y', 'Y'));
      expect(rejectedUpdate, isFalse, reason: '★ updateServer 新增分支同样被拦');
      expect(c.servers.length, ServerController.kMaxServers);
      expect(c.servers.any((ServerData e) => e.id == 'y'), isFalse);
    });

    test('★ 满 50 时编辑已有服务器不受上限影响', () async {
      final ServerController c = Get.put(ServerController());
      await c.loadLocal();

      c.servers.assignAll(
        List<ServerData>.generate(
            ServerController.kMaxServers, (int i) => mk('s$i', 'S$i')),
      );

      final bool ok = await c.updateServer(mk('s0', 'S0-edited'));
      expect(ok, isTrue, reason: '★ 编辑已有条目应放行');
      expect(c.servers.length, ServerController.kMaxServers);
      expect(
        c.servers.firstWhere((ServerData e) => e.id == 's0').name,
        'S0-edited',
      );
    });

    test('★ 未达上限时新增正常放行', () async {
      final ServerController c = Get.put(ServerController());
      await c.loadLocal();
      expect(await c.addServer(mk('a', 'A')), isTrue);
      expect(c.servers.length, 1);
    });
  });

  group('★ 设置页参数缓存（提前缓存）', () {
    test('★ put / get / drop 行为正确', () {
      final ServerController c = Get.put(ServerController());
      expect(c.prefsSnapOf('a'), isNull);

      c.putPrefsSnap(
        'a',
        ServerPrefsSnap(
          prefs: <String, dynamic>{'up_limit': 123},
          serverState: <String, dynamic>{'use_alt_speed_limits': true},
          categories: <String>['c1'],
          tags: <String>['t1'],
          at: DateTime.now(),
        ),
      );

      final ServerPrefsSnap? s = c.prefsSnapOf('a');
      expect(s, isNotNull);
      expect(s!.prefs['up_limit'], 123);
      expect(s.serverState['use_alt_speed_limits'], true);
      expect(s.categories, <String>['c1']);
      expect(s.tags, <String>['t1']);

      c.dropPrefsSnap('a');
      expect(c.prefsSnapOf('a'), isNull);
    });

    test('★ 删除服务器会连带清掉其参数缓存', () async {
      final ServerController c = Get.put(ServerController());
      await c.loadLocal();
      await c.addServer(mk('a', 'A'));
      c.putPrefsSnap('a', ServerPrefsSnap(at: DateTime.now()));
      expect(c.prefsSnapOf('a'), isNotNull);

      await c.deleteServer('a');
      expect(c.prefsSnapOf('a'), isNull,
          reason: '★ _clearRuntimeOf 应连带清掉参数缓存');
    });

    test('★ 默认快照为空集合（不返回 null 字段）', () {
      final ServerPrefsSnap s = ServerPrefsSnap(at: DateTime.now());
      expect(s.prefs, isEmpty);
      expect(s.serverState, isEmpty);
      expect(s.categories, isEmpty);
      expect(s.tags, isEmpty);
    });
  });

  group('★ 刷新时预取（开关控制）', () {
    test('★ 开关关闭时：刷新不产生预取缓存、也不额外请求', () async {
      final List<String> calls = <String>[];
      final ServerController c = ServerController();
      c.qbFactory = () => QbMethod(dio: _fakeQbDio(calls));
      c.servers.assignAll(<ServerData>[mk('a', 'A')]);

      await c.refreshAllServers();
      await _pump();

      expect(c.prefsSnapOf('a'), isNull);
      expect(calls.any((String e) => e.contains('/app/preferences')), isFalse,
          reason: '★ 开关关闭时不得发预取请求');
    });

    test('★ 开关打开时：刷新后填充参数缓存（含分类/标签/服务器状态）', () async {
      final List<String> calls = <String>[];
      final ServerController c = ServerController();
      c.qbFactory = () => QbMethod(dio: _fakeQbDio(calls));
      c.servers.assignAll(<ServerData>[mk('a', 'A')]);
      ServerController.prefsPrefetchEnabled = true;

      await c.refreshAllServers();
      await _pump();

      final ServerPrefsSnap? snap = c.prefsSnapOf('a');
      expect(snap, isNotNull, reason: '★ 刷新后应填充参数缓存');
      expect(snap!.prefs['up_limit'], 4096, reason: '★ 参数来自 /app/preferences');
      expect(snap.categories, <String>['c1']);
      expect(snap.tags, <String>['t1']);
      expect(snap.serverState[PrefKey.altSpeedEnabled], true,
          reason: '★ server_state 复用刷新已取的数据，不额外请求');
    });
  });
}
