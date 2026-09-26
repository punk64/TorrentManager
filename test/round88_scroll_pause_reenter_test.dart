import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/pages/torrent_list_page.dart';
import 'package:torrent_manager/utils/ip_geo.dart';
import 'package:torrent_manager/widgets/list_loading_placeholder.dart';

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

  int countOf(String path) =>
      calls.where((String c) => c.endsWith(path)).length;

  List<Map<String, dynamic>> torrents() {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    for (int i = 1; i <= 20; i++) {
      out.add(<String, dynamic>{
        'hash': 'h$i',
        'name': '种子 $i',
        'size': 1024 * i,
        'progress': i / 20,
        'state': i.isEven ? 'downloading' : 'uploading',
        'dlspeed': 100 * i,
        'upspeed': 10 * i,
      });
    }
    return out;
  }

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
            h.resolve(Response<dynamic>(
                requestOptions: o, statusCode: 200, data: torrents()));
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

ServerController boot(QbGate f) {
  final ServerController sc = ServerController(qb: QbMethod(dio: f.dio()));
  Get.put<ServerController>(sc);
  final ServerData s = qbSrv();
  sc.servers.assignAll(<ServerData>[s]);
  sc.current.value = s;
  Get.put<TorrentController>(TorrentController());
  return sc;
}

Future<void> settle([int ms = 60]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

Future<void> settleUi(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1800, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const GetMaterialApp(home: TorrentListPage()));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 400));
}

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

  test('第 88 轮 S1 · ★ 列表滚动留下的「暂停」标记，切服务器后必须被清掉', () async {
    final QbGate f = QbGate();
    boot(f);
    final TorrentController tc = Get.find<TorrentController>();

    tc.setScrollPaused(true);
    tc.resetForServerSwitch();
    expect(tc.scrollPaused, isFalse,
        reason: '★ 用户报的 bug 根因：滚动标志没被复位 ⇒ 自动取数通道被永久堵死');

    await tc.refreshAuto();
    await settle();

    expect(f.infoCalls, 1,
        reason: '★ 切服务器后自动取数必须真的发出列表请求，否则界面永远停在骨架屏');
  });

  testWidgets('第 88 轮 S2 · ★ 端到端：滚动后离开页面，再进入必须能加载出来',
      (WidgetTester tester) async {
    final QbGate f = QbGate();
    Get.put(ThemeController(), permanent: true);
    final ServerController sc = boot(f);
    final TorrentController tc = Get.find<TorrentController>();

    await pumpPage(tester);
    await settleUi(tester);
    expect(f.infoCalls, 1, reason: '前置：首次进入应加载出列表');

    expect(find.byType(ListLoadingPlaceholder), findsNothing,
        reason: '前置：首屏数据已到，骨架屏应撤下');

    tc.setScrollPaused(true);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tc.scrollPaused, isFalse,
        reason: '★ 页面销毁时必须复原滚动标志，否则它会把下一次进入的取数堵死');

    sc.select(qbSrv());
    await pumpPage(tester);
    await settleUi(tester);

    expect(f.infoCalls, 2, reason: '★ 再次进入必须重新发起列表请求（一次好一次坏的根因）');
    expect(tc.isLoading.value, isFalse, reason: '加载态必须收尾，不能永久转圈');
    expect(tc.items.length, 20, reason: '数据必须真正落到列表上');
    expect(find.byType(ListLoadingPlaceholder), findsNothing,
        reason: '★ 不许再停在「正在获取种子列表…」的骨架屏上');
  });

  test('第 88 轮 S3 · ★ 切服务器要清掉上一轮残留的阶段文案', () async {
    final QbGate f = QbGate();
    final ServerController sc = boot(f);

    sc.reportStage('qb-1', ConnStage.loading);
    expect(sc.stageTextOf('qb-1'), isNotNull, reason: '前置：先制造一段残留文案');

    sc.select(qbSrv());
    expect(sc.stageTextOf('qb-1'), isNull,
        reason: '★ 切服务器必须清残留，否则骨架屏会显示上一次的「正在获取种子列表…」');
  });

  test('第 88 轮 S4 · 护栏：滚动防抖期间仍应跳过自动取数（别把节流拆掉）', () async {
    final QbGate f = QbGate();
    boot(f);
    final TorrentController tc = Get.find<TorrentController>();

    tc.setScrollPaused(true);
    await tc.refreshAuto();
    await settle();
    expect(f.infoCalls, 0, reason: '★ 滚动中就该省掉请求，这是原有的节流设计');

    tc.setScrollPaused(false);
    await tc.refreshAuto();
    await settle();
    expect(f.infoCalls, 1, reason: '滚动停下后必须恢复取数');
  });
}
