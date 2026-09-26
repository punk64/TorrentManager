import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/utils/ip_geo.dart';

ServerData qbSrv() => ServerData(
      id: 'qb-1',
      name: '家庭 NAS',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'admin',
      password: 'adminadmin',
    );

class QbGate {
  final List<String> calls = <String>[];

  bool loggedIn = false;

  int infoCalls = 0;

  bool holdFirstInfo = false;

  final Completer<void> release = Completer<void>();

  int countOf(String path) =>
      calls.where((String c) => c.endsWith(path)).length;

  Dio dio() {
    final Dio d = Dio(
      BaseOptions(validateStatus: (int? s) => s != null && s < 500),
    );
    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions o, RequestInterceptorHandler h) async {
          final String p = o.uri.path.replaceFirst('/api/v2', '');
          calls.add(p);

          if (p.endsWith('/auth/login')) {
            loggedIn = true;
            h.resolve(Response<dynamic>(
                requestOptions: o, statusCode: 200, data: 'Ok.'));
            return;
          }
          if (!loggedIn) {
            h.resolve(Response<dynamic>(
                requestOptions: o, statusCode: 403, data: 'Forbidden'));
            return;
          }
          if (p.endsWith('/app/version')) {
            h.resolve(Response<dynamic>(
                requestOptions: o, statusCode: 200, data: 'v5.0.5'));
            return;
          }
          if (p.endsWith('/app/webapiVersion')) {
            h.resolve(Response<dynamic>(
                requestOptions: o, statusCode: 200, data: '2.11.2'));
            return;
          }
          if (p.endsWith('/torrents/info')) {
            infoCalls++;
            if (holdFirstInfo && infoCalls == 1) await release.future;
            h.resolve(Response<dynamic>(
                requestOptions: o, statusCode: 200, data: <dynamic>[
              <String, dynamic>{
                'hash': 'h1',
                'name': 'A',
                'size': 1024,
                'progress': 0.5,
                'state': 'downloading',
                'dlspeed': 100,
              },
              <String, dynamic>{
                'hash': 'h2',
                'name': 'B',
                'size': 2048,
                'progress': 1.0,
                'state': 'uploading',
                'upspeed': 200,
              },
            ]));
            return;
          }
          if (p.endsWith('/sync/maindata')) {
            h.resolve(Response<dynamic>(
                requestOptions: o,
                statusCode: 200,
                data: <String, dynamic>{
                  'rid': 1,
                  'full_update': true,
                  'server_state': <String, dynamic>{
                    'dl_rate_limit': 0,
                    'up_rate_limit': 0,
                    'use_alt_speed_limits': false,
                  },
                  'torrents': <String, dynamic>{},
                }));
            return;
          }
          h.resolve(Response<dynamic>(
              requestOptions: o, statusCode: 200, data: <String, dynamic>{}));
        },
      ),
    );
    return d;
  }
}

Future<TorrentController> boot(QbGate f, {bool hold = false}) async {
  f.holdFirstInfo = hold;
  final ServerController sc = ServerController(qb: QbMethod(dio: f.dio()));
  Get.put<ServerController>(sc);
  final ServerData s = qbSrv();
  sc.servers.assignAll(<ServerData>[s]);
  sc.current.value = s;
  return Get.put<TorrentController>(TorrentController());
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 40));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    IpGeo.offline = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() {
    IpGeo.offline = false;
    Get.reset();
  });

  test('第 86 轮 R1 · ★ 返回后再次进入同一服务器，必须重新发起加载', () async {
    final QbGate f = QbGate();
    final TorrentController tc = await boot(f, hold: true);

    tc.resetForServerSwitch();
    final Future<void> first = tc.refresh();
    await settle();
    expect(f.infoCalls, 1, reason: '前置：第一次进入列表必须发出列表请求');

    tc.resetForServerSwitch();
    final Future<void> second = tc.refresh();
    await settle();

    expect(f.infoCalls, 2,
        reason: '★ 用户报的 bug：第二次进入被上一代的「在途」标记挡住 ⇒ 界面一直显示加载中');

    f.release.complete();
    await first;
    await second;

    expect(tc.isLoading.value, isFalse, reason: '加载态必须收尾，不能永久转圈');
    expect(tc.items.length, 2, reason: '数据最终必须落到列表上');
  });

  test('第 86 轮 R2 · ★ 再次进入时先把缓存铺上，界面不空转', () async {
    final QbGate f = QbGate();
    final TorrentController tc = await boot(f);
    final ServerController sc = Get.find<ServerController>();

    sc.cacheTorrents('qb-1', <Torrent>[
      const Torrent(
          hash: 'h1',
          name: 'A',
          size: 1024,
          progress: 0.5,
          state: 'downloading',
          dlSpeed: 100,
          upSpeed: 0,
          numSeeds: 1,
          numLeechs: 0,
          ratio: 0,
          rawState: 'downloading'),
      const Torrent(
          hash: 'h2',
          name: 'B',
          size: 2048,
          progress: 1.0,
          state: 'uploading',
          dlSpeed: 0,
          upSpeed: 200,
          numSeeds: 1,
          numLeechs: 0,
          ratio: 1,
          rawState: 'uploading'),
    ]);

    tc.resetForServerSwitch();
    expect(tc.items, isEmpty, reason: '前置：切服务器会清空视图');

    final Future<void> job = tc.refresh();
    expect(tc.items.length, 2,
        reason: '★ 进列表必须先用缓存铺满（同步段完成），否则用户看到的是空转圈');
    await job;
  });

  test('第 86 轮 R3 · 护栏：同一代内的重复刷新仍应防重入', () async {
    final QbGate f = QbGate();
    final TorrentController tc = await boot(f, hold: true);

    tc.resetForServerSwitch();
    final Future<void> first = tc.refresh();
    await settle();

    final Future<void> again = tc.refresh();
    await settle();

    expect(f.infoCalls, 1,
        reason: '★ 没切服务器、上一代请求还在途时，重复刷新仍应跳过（别把省请求的优化拆掉）');

    f.release.complete();
    await first;
    await again;
  });
}
