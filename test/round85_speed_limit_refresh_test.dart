import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/prefs/server_prefs.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/pages/server_setting_page.dart';
import 'package:torrent_manager/utils/ip_geo.dart';
import 'package:torrent_manager/utils/strings.dart';

ServerData qbSrv() => ServerData(
      id: 'qb-1',
      name: '家庭 NAS',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'admin',
      password: 'adminadmin',
    );

class QbFake {
  final List<String> calls = <String>[];

  bool loggedIn = false;

  int dlRate = 512000;

  int upRate = 102400;

  bool alt = false;

  int altDl = 51200;

  int altUp = 20480;

  int countOf(String path) =>
      calls.where((String c) => c.endsWith(path)).length;

  Map<String, dynamic> get serverState => <String, dynamic>{
        'dl_rate_limit': dlRate,
        'up_rate_limit': upRate,
        'use_alt_speed_limits': alt,
      };

  Map<String, dynamic> get preferences => <String, dynamic>{
        'save_path': '/downloads',
        'dl_limit': dlRate,
        'up_limit': upRate,
        'alt_dl_limit': altDl,
        'alt_up_limit': altUp,
      };

  Dio dio() {
    final Dio d = Dio(
      BaseOptions(validateStatus: (int? s) => s != null && s < 500),
    );
    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions o, RequestInterceptorHandler h) {
          final String p = o.uri.path.replaceFirst('/api/v2', '');
          calls.add('${o.method} $p');

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
          if (p.endsWith('/app/setPreferences')) {
            final dynamic body = o.data;
            if (body is Map) {
              final dynamic dl = body['dl_limit'];
              final dynamic up = body['up_limit'];
              final dynamic adl = body['alt_dl_limit'];
              final dynamic aup = body['alt_up_limit'];
              if (dl is num) dlRate = dl.toInt();
              if (up is num) upRate = up.toInt();
              if (adl is num) altDl = adl.toInt();
              if (aup is num) altUp = aup.toInt();
            }
            h.resolve(Response<dynamic>(
                requestOptions: o, statusCode: 200, data: ''));
            return;
          }
          if (p.endsWith('/app/preferences')) {
            h.resolve(Response<dynamic>(
                requestOptions: o, statusCode: 200, data: preferences));
            return;
          }
          if (p.endsWith('/transfer/toggleSpeedLimitsMode')) {
            alt = !alt;
            h.resolve(Response<dynamic>(
                requestOptions: o, statusCode: 200, data: ''));
            return;
          }
          if (p.endsWith('/transfer/info')) {
            h.resolve(Response<dynamic>(
                requestOptions: o,
                statusCode: 200,
                data: <String, dynamic>{
                  'dl_info_speed': 2048,
                  'up_info_speed': 1024,
                }));
            return;
          }
          if (p.endsWith('/sync/maindata')) {
            h.resolve(Response<dynamic>(
                requestOptions: o,
                statusCode: 200,
                data: <String, dynamic>{
                  'rid': 1,
                  'full_update': true,
                  'server_state': serverState,
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

ServerController build(QbFake f) {
  final ServerController sc = ServerController(qb: QbMethod(dio: f.dio()));
  final ServerData s = qbSrv();
  sc.servers.assignAll(<ServerData>[s]);
  sc.current.value = s;
  return sc;
}

ServerData trSrv() => ServerData(
      id: 'tr-1',
      name: 'TR',
      type: 'transmission',
      host: '192.168.1.11',
      port: 9091,
      username: 'admin',
      password: 'secret',
    );

class TrFake {
  final List<String> calls = <String>[];

  int sessionGets = 0;

  bool alt = false;

  int altDown = 50;

  int altUp = 20;

  int dlLimit = 500;

  Map<String, dynamic> get session => <String, dynamic>{
        'version': '4.0.6',
        'alt-speed-enabled': alt,
        'alt-speed-down': altDown,
        'alt-speed-up': altUp,
        'speed-limit-down-enabled': true,
        'speed-limit-down': dlLimit,
        'speed-limit-up-enabled': false,
        'speed-limit-up': 100,
      };

  Dio dio() {
    final Dio d = Dio(
      BaseOptions(validateStatus: (int? s) => s != null && s < 500),
    );
    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions o, RequestInterceptorHandler h) {
          calls.add('${o.method} ${o.uri.path}');
          String method = '';
          final dynamic body = o.data;
          if (body is String) {
            try {
              final dynamic j = jsonDecode(body);
              if (j is Map) method = (j['method'] ?? '').toString();
            } catch (_) {}
          }
          Map<String, dynamic> args = <String, dynamic>{};
          if (method == 'session-get') {
            sessionGets++;
            args = session;
          } else if (method == 'torrent-get') {
            args = <String, dynamic>{'torrents': <dynamic>[]};
          }
          h.resolve(Response<dynamic>(
            requestOptions: o,
            statusCode: 200,
            data: <String, dynamic>{'arguments': args, 'result': 'success'},
          ));
        },
      ),
    );
    return d;
  }
}

ServerController buildTr(TrFake f) {
  final ServerController sc = ServerController(tr: TrMethod(dio: f.dio()));
  final ServerData s = trSrv();
  sc.servers.assignAll(<ServerData>[s]);
  sc.current.value = s;
  return sc;
}

Future<void> refreshNow(ServerController sc) async {
  await sc.refreshAllServers();
  await Future<void>.delayed(const Duration(milliseconds: 60));
}

void seedPrefs(ServerController sc, {required int altDl, required int altUp}) {
  sc.putPrefsSnap(
    'qb-1',
    ServerPrefsSnap(
      prefs: <String, dynamic>{
        'alt_dl_limit': altDl,
        'alt_up_limit': altUp,
      },
      serverState: <String, dynamic>{},
      at: DateTime.now(),
    ),
  );
}

class SpyCtrl extends ServerController {
  SpyCtrl({super.qb, super.tr});

  final List<String> invalidated = <String>[];

  @override
  Future<void> invalidateSpeedLimit(String id) async {
    invalidated.add(id);
    await super.invalidateSpeedLimit(id);
  }
}

Future<SpyCtrl> pumpSetting(WidgetTester tester, QbFake f) async {
  tester.view.physicalSize = const Size(1335, 3600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  ServerSettingPage.debugPrefsOverride = QbPrefsApi(
    client: QbMethod(dio: f.dio()),
    resolve: (ServerData s) => s,
  );

  Get.testMode = true;
  Get.reset();
  Get.put(ThemeController(), permanent: true);
  final SpyCtrl sc = SpyCtrl();
  Get.put<ServerController>(sc);
  await tester.pump(const Duration(milliseconds: 50));

  final ServerData s = qbSrv();
  sc.servers.assignAll(<ServerData>[s]);
  sc.current.value = s;

  await tester.pumpWidget(GetMaterialApp(
    home: const ServerSettingPage(),
    initialBinding: AppBinding(),
  ));
  await tester.pump(const Duration(milliseconds: 600));
  return sc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    IpGeo.offline = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.reset();
  });

  tearDown(() {
    ServerSettingPage.debugPrefsOverride = null;
    IpGeo.offline = false;
    Get.reset();
  });

  test('第 85 轮 A1 · 卡片限速初值取自主数据的全局限速', () async {
    final QbFake f = QbFake();
    final ServerController sc = build(f);

    await refreshNow(sc);

    expect(sc.limitOf('qb-1').dl, 512000);
    expect(sc.limitOf('qb-1').up, 102400);
  });

  test('第 85 轮 A2 · ★ 改全局限速数值，下一轮刷新必须跟上', () async {
    final QbFake f = QbFake();
    final ServerController sc = build(f);

    await refreshNow(sc);
    expect(sc.limitOf('qb-1').dl, 512000, reason: '前置：基线必须成立，否则下面断言是空的');

    f.dlRate = 819200;
    f.upRate = 204800;
    await refreshNow(sc);

    expect(sc.limitOf('qb-1').dl, 819200,
        reason: '★ 用户报的 bug：改完限速卡片纹丝不动，要重启 App 才刷新');
    expect(sc.limitOf('qb-1').up, 204800,
        reason: '★ 上传限速同理，不能只刷新一个方向');
  });

  test('第 85 轮 A3 · ★ 切换备用模式，下一轮刷新必须切到备用值', () async {
    final QbFake f = QbFake();
    final ServerController sc = build(f);
    seedPrefs(sc, altDl: 51200, altUp: 20480);

    await refreshNow(sc);
    expect(sc.limitOf('qb-1').dl, 512000, reason: '前置：备用未开启时显示全局限速');

    f.alt = true;
    await refreshNow(sc);

    expect(sc.limitOf('qb-1').dl, 51200,
        reason: '★ 切备用后卡片必须换成备用限速，否则显示的限速与实际生效值不符');
    expect(sc.limitOf('qb-1').up, 20480,
        reason: '★ 上传方向同理');
  });

  test('第 85 轮 A4 · ★ 改备用限速数值（值只在偏好里）也必须跟上', () async {
    final QbFake f = QbFake();
    final ServerController sc = build(f);
    f.alt = true;
    seedPrefs(sc, altDl: 51200, altUp: 20480);

    await refreshNow(sc);
    expect(sc.limitOf('qb-1').dl, 51200, reason: '前置：基线备用值');

    f.altDl = 81920;
    seedPrefs(sc, altDl: 81920, altUp: 20480);
    await refreshNow(sc);

    expect(sc.limitOf('qb-1').dl, 81920,
        reason: '★ 备用限速数值不在主数据里，只靠偏好缓存 —— 这块最容易漏刷新');
  });

  test('第 85 轮 A5 · 源没变化时不重算（护栏：别把缓存整个拆掉）', () async {
    final QbFake f = QbFake();
    final ServerController sc = build(f);

    await refreshNow(sc);
    final ServerSpeedLimit first = sc.limitOf('qb-1');

    await refreshNow(sc);

    expect(identical(sc.limitOf('qb-1'), first), isTrue,
        reason: '★ 限速没变就不该重算，否则每 3 秒轮询都会无谓刷新 UI / 触发 TR 的额外请求');
  });

  testWidgets('第 85 轮 B1 · ★ 设置页改全局限速必须通知控制器重算限速',
      (WidgetTester tester) async {
    final QbFake f = QbFake();
    final SpyCtrl sc = await pumpSetting(tester, f);

    expect(sc.invalidated, isEmpty, reason: '前置：还没点按钮，不该有失效动作');

    await tester.tap(find.text('限速设置'));
    await tester.pump(const Duration(milliseconds: 400));

    final ElevatedButton btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, S.change).first);
    btn.onPressed!();
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(sc.invalidated, contains('qb-1'),
        reason: '★ 改完限速必须让卡片重算，否则用户看到的还是旧值（本 bug 的原症状）');
  });

  testWidgets('第 85 轮 B2 · ★ 设置页切备用模式必须通知控制器重算限速',
      (WidgetTester tester) async {
    final QbFake f = QbFake();
    final SpyCtrl sc = await pumpSetting(tester, f);

    await tester.tap(find.text('限速设置'));
    await tester.pump(const Duration(milliseconds: 400));

    final CupertinoSwitch sw =
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch).first);
    sw.onChanged!(true);
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(sc.invalidated, contains('qb-1'),
        reason: '★ 切备用会换掉卡片显示的限速值，同样必须立即重算');
  });

  test('第 85 轮 C1 · TR 卡片限速初值取自主数据', () async {
    final TrFake f = TrFake();
    final ServerController sc = buildTr(f);

    await refreshNow(sc);

    expect(sc.limitOf('tr-1').dl, 512000, reason: 'speed-limit-down=500 KB/s');
    expect(sc.limitOf('tr-1').up, 0, reason: '上传方向未启用限速 ⇒ 0');
  });

  test('第 85 轮 C2 · ★ TR 外部切备用模式，下一轮刷新必须跟上', () async {
    final TrFake f = TrFake();
    final ServerController sc = buildTr(f);

    await refreshNow(sc);
    expect(sc.limitOf('tr-1').dl, 512000, reason: '前置：备用未开启时显示全局限速');

    f.alt = true;
    await refreshNow(sc);

    expect(sc.limitOf('tr-1').dl, 51200,
        reason: '★ alt-speed-down=50 KB/s，切备用后卡片必须换成备用值，不能停 5 分钟');
  });

  test('第 85 轮 C3 · ★ TR 外部改备用数值，下一轮刷新必须跟上', () async {
    final TrFake f = TrFake();
    final ServerController sc = buildTr(f);
    f.alt = true;

    await refreshNow(sc);
    expect(sc.limitOf('tr-1').dl, 51200, reason: '前置：备用值 50 KB/s');

    f.altDown = 80;
    await refreshNow(sc);

    expect(sc.limitOf('tr-1').dl, 81920,
        reason: '★ 备用数值变化同样必须跟上（与 qB 侧 alt_dl_limit 是同一类漏点）');
  });

  test('第 85 轮 C4 · 护栏：TR 源未变时不该重算', () async {
    final TrFake f = TrFake();
    final ServerController sc = buildTr(f);

    await refreshNow(sc);
    final int after1 = f.sessionGets;

    await refreshNow(sc);

    expect(f.sessionGets - after1, 1,
        reason: '★ 第二轮只剩连接探测那一次；限速没变就不该再多打一次 session-get');
  });

  test('第 85 轮 C5 · ★ 首轮不该为取限速多发一次 session-get', () async {
    final TrFake f = TrFake();
    final ServerController sc = buildTr(f);

    await refreshNow(sc);

    expect(f.sessionGets, 2,
        reason: '★ 首轮 = 连接探测 1 次 + 取版本号 1 次；限速必须复用探测拿到的 session，'
            '再单独多发一次（=3）纯属白打');
  });
}
