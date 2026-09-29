import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/data/prefs/server_prefs.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/pages/torrent_info_trackers_page.dart';
import 'package:torrent_manager/utils/ip_geo.dart';

ServerData qbSrv() => ServerData(
      id: 'srv-1',
      name: 'NAS',
      type: 'qbittorrent',
      host: 'nas.example.com',
      port: 8080,
      username: 'admin',
      password: 'secret',
    );

ServerData trSrv() => ServerData(
      id: 'srv-tr',
      name: 'TR',
      type: 'transmission',
      host: 'tr.example.com',
      port: 9091,
      username: 'admin',
      password: 'secret',
    );

Torrent privTorrent({bool priv = true, int? trId}) => Torrent(
      hash: 'hash-1',
      name: '测试种子',
      size: 1024,
      progress: 1,
      state: 'seeding',
      dlSpeed: 0,
      upSpeed: 0,
      numSeeds: 3,
      numLeechs: 1,
      ratio: 2,
      isPrivate: priv,
      trId: trId,
    );

/// qB 粘性条目：status 才是真实状态（2=working 0=disabled）
List<Map<String, dynamic>> qbTrackers() => <Map<String, dynamic>>[
      <String, dynamic>{
        'url': '** [DHT] **',
        'status': 0,
        'num_peers': 0,
        'msg': 'This torrent is private',
      },
      <String, dynamic>{
        'url': '** [PeX] **',
        'status': 2,
        'num_peers': 7,
        'msg': '',
      },
      <String, dynamic>{
        'url': 'udp://tracker.example.com:6969/announce',
        'status': 2,
        'num_seeds': 5,
        'num_leeches': 2,
        'num_downloaded': 9,
        'tier': 0,
        'msg': '',
      },
    ];

List<Map<String, dynamic>> trTrackers() => <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'announce': 'udp://tracker.example.com:6969/announce',
        'announceState': 3,
        'seederCount': 5,
        'leecherCount': 2,
        'downloadCount': 9,
        'tier': 0,
        'isBackup': false,
      },
    ];

class _TrFake {
  final List<String> methods = <String>[];

  final Map<String, dynamic> session = <String, dynamic>{
    'speed-limit-up': 512,
    'speed-limit-down': 1024,
    'alt-speed-enabled': false,
    'download-dir': '/tr/downloads',
    'dht-enabled': true,
    'pex-enabled': true,
    'lpd-enabled': false,
    'encryption': 'preferred',
  };

  Dio dio() {
    final Dio d = Dio(BaseOptions(
      validateStatus: (int? s) => s != null && s < 500,
      followRedirects: false,
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) {
        final String? sid =
            o.headers['X-Transmission-Session-Id'] as String?;
        if (sid == null) {
          h.resolve(Response<dynamic>(
            requestOptions: o,
            statusCode: 409,
            headers: Headers.fromMap(<String, List<String>>{
              'x-transmission-session-id': <String>['tr-sid-1'],
            }),
            data: '',
          ));
          return;
        }
        final dynamic body = o.data;
        final Map<String, dynamic> m = body is Map
            ? Map<String, dynamic>.from(body)
            : (jsonDecode('$body') as Map<String, dynamic>);
        final String method = '${m['method']}';
        methods.add(method);
        final Map<String, dynamic> a = Map<String, dynamic>.from(
            m['arguments'] as Map? ?? <String, dynamic>{});
        Map<String, dynamic> args = const <String, dynamic>{};
        if (method == 'torrent-get') {
          final List<dynamic> fields = (a['fields'] as List?) ?? <dynamic>[];
          if (fields.contains('trackerStats')) {
            args = <String, dynamic>{
              'torrents': <Map<String, dynamic>>[
                <String, dynamic>{'id': 1, 'trackerStats': trTrackers()},
              ],
            };
          }
        }
        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: <String, dynamic>{
            'result': 'success',
            'arguments': method == 'session-get' ? session : args,
          },
        ));
      },
    ));
    return d;
  }
}

Future<void> _pump(WidgetTester tester, {TrMethod? trClient}) async {
  tester.view.physicalSize = const Size(1500, 9000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  Get.testMode = true;
  Get.reset();
  Get.put(ThemeController(), permanent: true);
  Get.put(ServerController(tr: trClient));
  Get.put(TorrentController());
  await tester.pump(const Duration(milliseconds: 50));

  await tester.pumpWidget(GetMaterialApp(
    home: const Scaffold(body: TorrentInfoTrackersPage()),
    initialBinding: AppBinding(),
  ));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    IpGeo.offline = true;
  });
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall call) async => null);
  });

  test('① 纯函数：qB 粘性条目 status → 开关状态', () {
    expect(qbStickyState(null), DiscovState.unknown);
    expect(qbStickyState(<String, dynamic>{'status': 2}), DiscovState.on);
    expect(qbStickyState(<String, dynamic>{'status': 0}), DiscovState.off);
    expect(qbStickyState(<String, dynamic>{'status': 1}), DiscovState.off,
        reason: '非 working 一律视为关（qB 粘性条目只有 0/2 两态）');
  });

  test('② 纯函数：TR session prefs → 开关状态', () {
    expect(trDiscovState(<String, dynamic>{}, PrefKey.dht),
        DiscovState.unknown);
    expect(trDiscovState(<String, dynamic>{PrefKey.dht: true}, PrefKey.dht),
        DiscovState.on);
    expect(trDiscovState(<String, dynamic>{PrefKey.dht: false}, PrefKey.dht),
        DiscovState.off);
    expect(trDiscovState(<String, dynamic>{PrefKey.pex: 1}, PrefKey.pex),
        DiscovState.on);
    expect(trDiscovState(<String, dynamic>{PrefKey.lsd: 0}, PrefKey.lsd),
        DiscovState.off);
  });

  testWidgets('③ qB 私有种子：关=「已关闭（符合私有要求）」开=「应立即关闭」缺失=「建议关闭」',
      (WidgetTester tester) async {
    await _pump(tester);
    final ServerController sc = Get.find<ServerController>();
    final TorrentController tc = Get.find<TorrentController>();
    sc.current.value = qbSrv();
    tc.current.value = privTorrent();
    tc.trackers.value = qbTrackers();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('DHT · 已关闭（符合私有要求）'), findsOneWidget,
        reason: 'status=0 + 私有 → 绿色已关闭');
    expect(find.text('PEX · 应立即关闭'), findsOneWidget,
        reason: 'status=2 + 私有 → 红色应立即关闭');
    expect(find.text('LSD · 建议关闭'), findsOneWidget,
        reason: 'qB 老版本可能不返回 LSD 条目 → 未知态');
    expect(find.textContaining('Private Torrent'), findsOneWidget,
        reason: '私有种子横幅保留');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('④ qB 非私有：开=「已开启 N 节点」关=「已关闭」，说明卡命名 LSD + TR 别名',
      (WidgetTester tester) async {
    await _pump(tester);
    final ServerController sc = Get.find<ServerController>();
    final TorrentController tc = Get.find<TorrentController>();
    sc.current.value = qbSrv();
    tc.current.value = privTorrent(priv: false);
    tc.trackers.value = qbTrackers();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('DHT · 已关闭'), findsOneWidget);
    expect(find.text('PEX · 已开启 7 节点'), findsOneWidget,
        reason: 'qB working 时带节点数');
    expect(find.text('LSD · 建议关闭'), findsNothing);
    expect(find.text('DHT / PEX / LSD 说明'), findsOneWidget);
    expect(find.text('TR 中称 LPD'), findsOneWidget);
    expect(find.textContaining('Private Torrent'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('⑤ TR：读 session 开关渲染徽章，命名对齐官方（LPD/用户交换）',
      (WidgetTester tester) async {
    await _pump(tester);
    final ServerController sc = Get.find<ServerController>();
    final TorrentController tc = Get.find<TorrentController>();
    sc.current.value = trSrv();
    tc.current.value = privTorrent(priv: false, trId: 1);
    tc.trackers.value = trTrackers();
    sc.putPrefsSnap(
      'srv-tr',
      ServerPrefsSnap(
        prefs: <String, dynamic>{
          PrefKey.dht: true,
          PrefKey.pex: true,
          PrefKey.lsd: false,
        },
        at: DateTime.now(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('DHT · 已开启'), findsOneWidget);
    expect(find.text('PEX · 已开启'), findsOneWidget);
    expect(find.text('LPD · 已关闭'), findsOneWidget, reason: 'TR 官方叫 LPD');
    expect(find.text('DHT / PEX / LPD 说明'), findsOneWidget);
    expect(find.text('qB 中称 LSD'), findsOneWidget);
    expect(find.text('LPD · 本地用户发现'), findsOneWidget);
    expect(find.text('PEX · 用户交换'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('⑥ TR 私有 + 无缓存：徽章未知态「建议关闭」',
      (WidgetTester tester) async {
    await _pump(tester);
    final ServerController sc = Get.find<ServerController>();
    final TorrentController tc = Get.find<TorrentController>();
    sc.current.value = trSrv();
    tc.current.value = privTorrent(trId: 1);
    tc.trackers.value = trTrackers();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('DHT · 建议关闭'), findsOneWidget);
    expect(find.text('PEX · 建议关闭'), findsOneWidget);
    expect(find.text('LPD · 建议关闭'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  test('⑦ TR 详情加载后：session 开关写入 prefs 缓存供徽章使用', () async {
    final _TrFake fake = _TrFake();
    Get.testMode = true;
    Get.reset();
    Get.put(ThemeController(), permanent: true);
    // TR 客户端注入 fake，loadDetailData 全链路走假 RPC
    final ServerController sc =
        Get.put(ServerController(tr: TrMethod(dio: fake.dio())));
    final TorrentController tc = Get.put(TorrentController());
    sc.current.value = trSrv();
    tc.current.value = privTorrent(priv: false, trId: 1);

    await tc.loadDetailData();

    final ServerPrefsSnap? snap = sc.prefsSnapOf('srv-tr');
    expect(snap, isNotNull, reason: '详情加载后应有 TR prefs 快照缓存');
    expect(snap!.prefs[PrefKey.dht], true);
    expect(snap.prefs[PrefKey.pex], true);
    expect(snap.prefs[PrefKey.lsd], false);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
