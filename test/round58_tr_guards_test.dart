import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/data/prefs/server_prefs.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';

Dio _fakeTrDio(List<String> calls) {
  final Dio dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.1.10:9091',
    validateStatus: (int? s) => s != null && s < 500,
    followRedirects: false,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      String method = '';
      final Object? body = o.data;
      if (body is String) {
        try {
          method = ((jsonDecode(body) as Map<String, dynamic>)['method'])
                  ?.toString() ??
              '';
        } catch (_) {
          method = '<unparsable>';
        }
      }
      calls.add('${o.method} ${o.uri.path} :: $method');

      h.resolve(Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: <String, dynamic>{
          'result': 'success',
          'arguments': <String, dynamic>{},
        },
      ));
    },
  ));
  return dio;
}

Torrent _t(String hash, {int? trId}) => Torrent(
      hash: hash,
      name: '种子$hash',
      size: 100,
      progress: 0.5,
      state: 'downloading',
      dlSpeed: 0,
      upSpeed: 0,
      numSeeds: 0,
      numLeechs: 0,
      ratio: 0,
      trId: trId,
    );

bool _has(List<String> calls, String action) =>
    calls.any((String c) => c.endsWith(':: $action'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() => Get.reset());

  group('第 58 轮 C · P1-3 TR 改订阅地址必须触发 blocklist-update', () {
    test('C1 ★ 写入 blocklistUrl → 必须补一次 blocklist-update', () async {
      final List<String> calls = <String>[];
      final TrPrefsApi api = TrPrefsApi(
        client: TrMethod(dio: _fakeTrDio(calls)),
        resolve: (ServerData s) => s,
      );

      await api.write(<String, dynamic>{
        PrefKey.blocklistUrl: 'https://example.com/list.txt',
      });

      expect(_has(calls, 'session-set'), isTrue,
          reason: '前置：地址确实写进去了');
      expect(_has(calls, 'blocklist-update'), isTrue,
          reason: '★ TR 只写 `blocklist-url` **不会自动去拉取解析** —— '
              '必须显式调 `blocklist-update`，否则「当前屏蔽」恒为 0 条：'
              '弹了「已更新」，实际一条都没生效');
    });

    test('C2 写别的键 → 不该无谓地重拉黑名单', () async {
      final List<String> calls = <String>[];
      final TrPrefsApi api = TrPrefsApi(
        client: TrMethod(dio: _fakeTrDio(calls)),
        resolve: (ServerData s) => s,
      );

      await api.write(<String, dynamic>{PrefKey.dlLimit: 1048576});

      expect(_has(calls, 'session-set'), isTrue);
      expect(_has(calls, 'blocklist-update'), isFalse,
          reason: '只有改「订阅地址」才需要重拉 —— 改限速也去下载一遍'
              '黑名单（可能几 MB）纯属浪费');
    });
  });

  group('第 58 轮 D · P1-1 TR 空 id 不得照发', () {
    test('D1 ★ 选中项全缺 trId → 不发请求，且明确报错', () async {
      final List<String> calls = <String>[];
      final ServerController sc = Get.put(ServerController());
      final ServerData tr = ServerData(
        id: 'tr-1',
        name: '家里的 TR',
        type: 'transmission',
        host: '192.168.1.10',
        port: 9091,
        username: 'u',
        password: 'p',
      );
      sc.servers.assignAll(<ServerData>[tr]);
      sc.current.value = tr;
      sc.trFactory = () => TrMethod(dio: _fakeTrDio(calls));

      final TorrentController c = TorrentController();
      c.items.assignAll(<Torrent>[_t('h1', trId: null)]);
      c.selected.add('h1');

      await c.pauseSelected();

      expect(calls, isEmpty,
          reason: '★ TR 的 `"ids": []` 是**空操作**（libtransmission 只在 '
              '`ids` 键**不存在**时才返回全部种子）—— 发出去服务端什么都不做，'
              '而界面会按 selected.length 记成"已暂停 1 个" ⇒ 假成功');
      expect(c.error.value, contains('Transmission 任务 ID'),
          reason: '★ 必须**明确报错**，而不是"点了没反应" —— '
              '与 deleteSelected / queueMoveSelected 的口径一致');
    });

    test('D2 对照：有 trId 时照常发出 torrent-stop', () async {
      final List<String> calls = <String>[];
      final ServerController sc = Get.put(ServerController());
      final ServerData tr = ServerData(
        id: 'tr-1',
        name: '家里的 TR',
        type: 'transmission',
        host: '192.168.1.10',
        port: 9091,
        username: 'u',
        password: 'p',
      );
      sc.servers.assignAll(<ServerData>[tr]);
      sc.current.value = tr;
      sc.trFactory = () => TrMethod(dio: _fakeTrDio(calls));

      final TorrentController c = TorrentController();
      c.items.assignAll(<Torrent>[_t('h1', trId: 7)]);
      c.selected.add('h1');

      await c.pauseSelected();

      expect(_has(calls, 'torrent-stop'), isTrue,
          reason: '有合法 trId 时不能因为新加的守卫反而拦住了');
    });
  });
}
