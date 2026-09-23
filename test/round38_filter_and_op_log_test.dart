











import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/pages/server_dialog.dart';
import 'package:torrent_manager/utils/app_log.dart';
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

Torrent mk({
  required String hash,
  String name = '示例种子',
  String state = 'downloading',
}) =>
    Torrent(
      hash: hash,
      name: name,
      size: 1000000,
      progress: 0.5,
      state: state,
      dlSpeed: 0,
      upSpeed: 0,
      numSeeds: 12,
      numLeechs: 3,
      ratio: 2.31,
    );





Dio fakeQb(
  List<String> calls, {
  String version = 'v4.6.2',
  bool pauseOk = true,
  bool stopOk = true,
}) {
  final Dio dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.1.10:8080',
    validateStatus: (int? s) => s != null && s < 500,
    followRedirects: false,
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      final String p = o.uri.path;
      calls.add('${o.method} $p');
      Response<dynamic> ok(Object? data) =>
          Response<dynamic>(requestOptions: o, statusCode: 200, data: data);
      Response<dynamic> no() =>
          Response<dynamic>(requestOptions: o, statusCode: 404, data: '');

      if (p.endsWith('/auth/login')) {
        h.resolve(ok('Ok.'));
      } else if (p.endsWith('/app/version')) {
        h.resolve(ok(version));
      } else if (p.endsWith('/app/webapiVersion')) {
        h.resolve(ok('2.11.2'));
      } else if (p.endsWith('/torrents/info')) {
        h.resolve(ok(<Map<String, dynamic>>[]));
      } else if (p.endsWith('/sync/maindata')) {
        h.resolve(ok(<String, dynamic>{
          'rid': 1,
          'server_state': <String, dynamic>{},
        }));
      } else if (p.endsWith('/torrents/pause') ||
          p.endsWith('/torrents/resume')) {
        h.resolve(pauseOk ? ok('') : no());
      } else if (p.endsWith('/torrents/stop') ||
          p.endsWith('/torrents/start')) {
        h.resolve(stopOk ? ok('') : no());
      } else {
        h.resolve(ok(''));
      }
    },
  ));
  return dio;
}


String opLog() => AppLog.instance.entries
    .where((LogEntry e) => e.source == AppLog.srcOp)
    .map((LogEntry e) => e.message)
    .join('\n');


String netLog() => AppLog.instance.entries
    .where((LogEntry e) => e.source == AppLog.srcNet)
    .map((LogEntry e) => e.message)
    .join('\n');

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
  });

  
  
  
  group('① 下载中筛选排除暂停态', () {
    test('★ pausedDL（4.x）/ stoppedDL（5.x）都不再算「下载中」', () {
      expect(TorrentFilter.downloading.matches(mk(hash: 'a', state: 'pausedDL')),
          isFalse,
          reason: '★ qB 4.x 暂停的下载：不该出现在「下载中」');
      expect(
          TorrentFilter.downloading.matches(mk(hash: 'b', state: 'stoppedDL')),
          isFalse,
          reason: '★ qB 5.x 暂停的下载：不该出现在「下载中」');
      expect(TorrentFilter.downloading.matches(mk(hash: 'c', state: 'StoppedDL')),
          isFalse,
          reason: '★ 远端大小写不保证，判定必须大小写不敏感');
    });

    test('★ 它们仍属于「暂停」筛选，且真正的下载态不受影响', () {
      expect(TorrentFilter.paused.matches(mk(hash: 'a', state: 'pausedDL')),
          isTrue);
      expect(TorrentFilter.paused.matches(mk(hash: 'b', state: 'stoppedDL')),
          isTrue);
      expect(TorrentFilter.downloading
          .matches(mk(hash: 'c', state: 'downloading')), isTrue);
      expect(
          TorrentFilter.downloading.matches(mk(hash: 'd', state: 'stalledDL')),
          isTrue);
      expect(TorrentFilter.downloading.matches(mk(hash: 'e', state: 'metaDL')),
          isTrue);
      expect(TorrentFilter.downloading.matches(mk(hash: 'f', state: 'forcedDL')),
          isTrue);
    });
  });

  
  
  
  group('② 操作日志：暂停 / 继续', () {
    test('★ 记下种子名与服务器（此前只有一个数字，无法复盘）', () async {
      final List<String> calls = <String>[];
      final ServerController sc =
          Get.put(ServerController(qb: QbMethod(dio: fakeQb(calls))));
      Get.put(ThemeController(), permanent: true);
      Get.put(TorrentController());

      final ServerData srv = qbSrv();
      sc.servers.assignAll(<ServerData>[srv]);
      sc.select(srv);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final TorrentController ctrl = Get.find<TorrentController>();
      ctrl.items.assignAll(<Torrent>[
        mk(hash: 'h1', name: 'Ubuntu 24.04 桌面版镜像'),
        mk(hash: 'h2', name: 'Debian 12 netinst'),
      ]);
      ctrl.selected
        ..add('h1')
        ..add('h2');

      await ctrl.pauseSelected();

      expect(opLog(), contains('暂停 2 个种子'),
          reason: '★ 数量仍要在');
      expect(opLog(), contains('Ubuntu 24.04 桌面版镜像'),
          reason: '★ 必须能看出操作的是哪几个种子');
      expect(opLog(), contains('家庭 NAS'),
          reason: '★ 必须能看出操作的是哪台服务器');
      expect(opLog(), contains('qB'), reason: '★ 服务器类型（qB / TR）');
    });

    test('★ 种子过多时只列前 3 个 + 「等 N 个」，不会撑爆日志行', () async {
      final List<String> calls = <String>[];
      final ServerController sc =
          Get.put(ServerController(qb: QbMethod(dio: fakeQb(calls))));
      Get.put(ThemeController(), permanent: true);
      Get.put(TorrentController());

      final ServerData srv = qbSrv();
      sc.servers.assignAll(<ServerData>[srv]);
      sc.select(srv);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final TorrentController ctrl = Get.find<TorrentController>();
      ctrl.items.assignAll(<Torrent>[
        for (int i = 0; i < 6; i++) mk(hash: 'h$i', name: '种子$i'),
      ]);
      for (int i = 0; i < 6; i++) {
        ctrl.selected.add('h$i');
      }

      await ctrl.pauseSelected();
      expect(opLog(), contains('等 6 个'), reason: '★ 超量时折叠');
    });
  });

  
  
  
  group('③ 端点自适应留痕', () {
    test('★ 5.x 用 stop，日志写明实际端点与版本风格', () async {
      final List<String> calls = <String>[];
      final QbMethod qb = QbMethod(dio: fakeQb(calls, version: 'v5.0.0'));
      qb.setServer(qbSrv());
      await qb.pauseTorrent('h1');

      expect(calls, contains('POST /api/v2/torrents/stop'));
      expect(netLog(), contains('暂停种子：stop'),
          reason: '★ 日志必须写明实际用的端点');
      expect(netLog(), contains('qB v5 风格'));
    });

    test('★ 版本探测误判时：404 换端点并把纠偏过程记下来', () async {
      final List<String> calls = <String>[];
      
      final QbMethod qb = QbMethod(
        dio: fakeQb(calls, version: 'v4.6.2', pauseOk: false, stopOk: true),
      );
      qb.setServer(qbSrv());
      await qb.pauseTorrent('h1');

      expect(calls, contains('POST /api/v2/torrents/pause'),
          reason: '★ 先按探测结论试老端点');
      expect(calls, contains('POST /api/v2/torrents/stop'),
          reason: '★ 404 后自动改用新端点');
      expect(netLog(), contains('暂停端点自适应'),
          reason: '★ 纠偏过程必须留痕：这是判断服务端版本的第一手证据');
      expect(netLog(), contains('pause 不可用（404）'));
    });

    test('★ 4.x 仍用 pause，不写纠偏日志', () async {
      final List<String> calls = <String>[];
      final QbMethod qb = QbMethod(dio: fakeQb(calls, version: 'v4.6.2'));
      qb.setServer(qbSrv());
      await qb.pauseTorrent('h1');

      expect(calls, contains('POST /api/v2/torrents/pause'));
      expect(calls, isNot(contains('POST /api/v2/torrents/stop')));
      expect(netLog(), contains('暂停种子：pause'));
      expect(netLog(), isNot(contains('端点自适应')));
    });
  });

  
  
  
  group('④ 取消添加服务器', () {
    testWidgets('★ 点「取消」记一条未保存的操作日志', (WidgetTester tester) async {
      Get.put(ThemeController(), permanent: true);
      Get.put(ServerController(qb: QbMethod(dio: fakeQb(<String>[]))));

      await tester.pumpWidget(GetMaterialApp(
        home: Builder(
          builder: (BuildContext ctx) => TextButton(
            onPressed: () => showServerDialog(ctx),
            child: const Text('open'),
          ),
        ),
        initialBinding: AppBinding(),
      ));

      await tester.tap(find.text('open'));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text(S.cancel), findsOneWidget, reason: '★ 对话框应已打开');

      await tester.tap(find.text(S.cancel));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(opLog(), contains('取消添加服务器（未保存）'),
          reason: '★ 关掉对话框 = 一次有排查价值的操作（能区分"没保存"与"连不上"）');
      expect(opLog(), contains('未填'),
          reason: '★ 摘要要说明填到了哪一步');
    });
  });
}
