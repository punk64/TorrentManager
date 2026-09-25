import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/pages/torrent_info_peers_page.dart';
import 'package:torrent_manager/utils/formatter.dart';
import 'package:torrent_manager/utils/ip_geo.dart';

ServerData qbSrv() => ServerData(
      id: 'qb-1',
      name: 'qb',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
    );

ServerData trSrv() => ServerData(
      id: 'tr-1',
      name: 'tr',
      type: 'transmission',
      host: '192.168.1.9',
      port: 9091,
    );

const String kIpv6 = '2409:8a00:6b10:1c30:1a2b:3c4d:5e6f:7a8b';

Map<String, dynamic> peer(String ip, {int port = 51413}) => <String, dynamic>{
      'ip': ip,
      'address': ip,
      'port': port,
      'client': 'Client-$ip',
      'clientName': 'Client-$ip',
      'progress': 0.42,
      'dl_speed': 1024,
      'rateToClient': 1024,
      'up_speed': 2048,
      'rateToPeer': 2048,
      'uploaded': 3221225472,
      'downloaded': 107374182400,
    };

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

    IpGeo.offline = true;
  });

  Dio fakeDio() {
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) {
        h.reject(DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
          error: 'test offline',
        ));
      },
    ));
    return dio;
  }

  Future<void> pumpPeers(WidgetTester tester, ServerData srv) async {
    final ServerController sc = Get.put(ServerController(
      qb: QbMethod(dio: fakeDio()),
      tr: TrMethod(dio: fakeDio()),
    ));
    Get.put(TorrentController());
    await tester.pumpWidget(const GetMaterialApp(
      home: Scaffold(
          body: SizedBox(height: 700, child: TorrentInfoPeersPage())),
    ));

    sc.current.value = srv;

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  void setPeers(List<String> ips) {
    Get.find<TorrentController>()
        .peers
        .assignAll(ips.map(peer).toList(growable: false));
  }

  group('① 归属地：公网才查，内网本地判定', () {
    testWidgets('★ 内网 IP 不发起查询（无转圈），直接出本地判定的文案',
        (WidgetTester tester) async {
      await pumpPeers(tester, qbSrv());
      setPeers(<String>['192.168.1.23']);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: '★ 内网段没有归属地可查，不应发出任何请求');
      expect(find.text(Formatter.getIpInfo('192.168.1.23')), findsOneWidget,
          reason: '★ 第二行右侧应显示本地判定结果');
    });

    testWidgets('★ 公网 IP 查询期间，第二行右侧显示转圈',
        (WidgetTester tester) async {
      await pumpPeers(tester, qbSrv());
      setPeers(<String>['223.5.5.5']);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget,
          reason: '★ 结果回来前应显示转圈（测试环境网络不落地，故停在查询中）');
    });

    testWidgets('★ 公网与内网混排时，只有公网那一行转圈',
        (WidgetTester tester) async {
      await pumpPeers(tester, qbSrv());
      setPeers(<String>['223.6.6.6', '10.0.0.5', '127.0.0.1']);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(Formatter.getIpInfo('10.0.0.5')), findsOneWidget);
      expect(find.text(Formatter.getIpInfo('127.0.0.1')), findsOneWidget);
    });
  });

  group('② IP 完整显示与协议徽章', () {
    testWidgets('★ 39 字符的 IPv6 完整显示，并标 IPv6',
        (WidgetTester tester) async {
      await pumpPeers(tester, qbSrv());
      setPeers(<String>[kIpv6]);
      await tester.pump();

      expect(find.text(kIpv6), findsOneWidget,
          reason: '★ IP 不得再被省略号截断');
      expect(find.text('IPv6'), findsOneWidget);
      expect(find.text('IPv4'), findsNothing);
    });

    testWidgets('★ IPv4 标 IPv4', (WidgetTester tester) async {
      await pumpPeers(tester, qbSrv());
      setPeers(<String>['10.0.0.9']);
      await tester.pump();

      expect(find.text('IPv4'), findsOneWidget);
      expect(find.text('IPv6'), findsNothing);
    });
  });

  group('③ 第三行的累计总量', () {
    testWidgets('★ qBittorrent：显示与该 Peer 的累计上传 / 下载',
        (WidgetTester tester) async {
      await pumpPeers(tester, qbSrv());
      setPeers(<String>['10.0.0.11']);
      await tester.pump();

      expect(find.textContaining('3.0G'), findsOneWidget,
          reason: '★ uploaded = 3.0G');
      expect(find.textContaining('100.0G'), findsOneWidget,
          reason: '★ downloaded = 100.0G');
    });

    testWidgets('★ Transmission：peer 无累计字段，整段隐藏',
        (WidgetTester tester) async {
      await pumpPeers(tester, trSrv());
      setPeers(<String>['10.0.0.12']);
      await tester.pump();

      expect(find.textContaining('3.0G'), findsNothing,
          reason: '★ TR 的 peer 没有 uploaded / downloaded，不显示');
      expect(find.textContaining('100.0G'), findsNothing);
    });
  });

  group('④ 行最右侧的操作按钮', () {
    testWidgets('★ qB：复制 IP / 复制 IP:端口 / 封禁 三个都在',
        (WidgetTester tester) async {
      await pumpPeers(tester, qbSrv());
      setPeers(<String>['10.0.0.21']);
      await tester.pump();

      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.copy_all), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    testWidgets('★ TR：只有两个复制按钮，没有封禁',
        (WidgetTester tester) async {
      await pumpPeers(tester, trSrv());
      setPeers(<String>['10.0.0.22']);
      await tester.pump();

      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.copy_all), findsOneWidget);
      expect(find.byIcon(Icons.block), findsNothing,
          reason: '★ 封禁是 qBittorrent 专有接口，TR 服务器不显示');
    });
  });

  testWidgets('★ 点「复制 IP」把 IP 写进系统剪贴板',
      (WidgetTester tester) async {
    final List<dynamic> copied = <dynamic>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall call) async {
      if (call.method == 'Clipboard.setData') copied.add(call.arguments);
      return null;
    });

    await pumpPeers(tester, qbSrv());
    setPeers(<String>['10.0.0.31']);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.copy).first);
    await tester.pump();

    expect(copied.isNotEmpty, isTrue, reason: '★ 应发生一次剪贴板写入');
    expect(copied.last['text'], '10.0.0.31');

    await tester.tap(find.byIcon(Icons.copy_all).first);
    await tester.pump();
    expect(copied.last['text'], '10.0.0.31:51413');
  });

  test('★ 封禁走 /transfer/banPeers，且参数是 ip:port', () async {
    final List<RequestOptions> reqs = <RequestOptions>[];
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://192.168.1.10:8080'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) {
        reqs.add(o);
        h.resolve(Response<dynamic>(requestOptions: o, data: 'Ok.'));
      },
    ));

    await QbMethod(dio: dio).showBanPeers('1.2.3.4:51413');

    expect(reqs, hasLength(1));
    expect(reqs.single.path, '/api/v2/transfer/banPeers',
        reason: '★ 旧代码写成 /torrents/banPeers，端点不存在 → 点了没效果');

    expect(
      (reqs.single.data as Map<String, dynamic>?)?['peers'],
      '1.2.3.4:51413',
      reason: '★ 传裸 IP 会被服务端静默忽略（响应仍是 200）',
    );
    expect(reqs.single.contentType, contains('x-www-form-urlencoded'),
        reason: '★ 参数必须放在 form body 里（qB 5.x 只认这里）');
    expect(reqs.single.queryParameters, isEmpty,
        reason: '★ 不该再拼在 URL query 上（那正是 400 的原因）');
  });
}
