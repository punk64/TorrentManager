import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/utils/app_log.dart';
import 'package:torrent_manager/utils/formatter.dart';
import 'package:torrent_manager/utils/strings.dart';
import 'package:torrent_manager/widgets/server_stats_panel.dart';

Torrent _t(
  String hash, {
  int dlSpeed = 0,
  int upSpeed = 0,
  int seeds = 0,
  int leechs = 0,
  int activePeers = -1,
  int uploaded = 0,
  int downloaded = 0,
}) {
  return Torrent(
    hash: hash,
    name: hash,
    size: 1024,
    progress: 0.5,
    state: 'downloading',
    dlSpeed: dlSpeed,
    upSpeed: upSpeed,
    numSeeds: seeds,
    numLeechs: leechs,
    ratio: 1.0,
    activePeers: activePeers,
    uploaded: uploaded,
    downloaded: downloaded,
  );
}

ServerData _srv(String id) => ServerData(
      id: id,
      name: id,
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'admin',
      password: 'adminadmin',
    );

/// 判断某个文本是否出现在任何 RichText（含 Text.rich 的 TextSpan）中。
bool _richHas(WidgetTester tester, String s) => tester
    .widgetList(find.byType(RichText))
    .any((Widget w) => (w as RichText).text.toPlainText().contains(s));

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

  group('★ 连接数与流量口径', () {
    test('★ transferPeers：TR 精确值优先，qB 只在有速度时用 seeds+leechs', () {
      expect(_t('a', activePeers: 7).transferPeers, 7);
      expect(
          _t('b', activePeers: -1, seeds: 3, leechs: 4, dlSpeed: 100)
              .transferPeers,
          7);
      expect(_t('c', activePeers: -1, seeds: 3, leechs: 4).transferPeers, 0);
    });

    test('★ TransferTotals.of 汇总三值且负值归零', () {
      final TransferTotals m = TransferTotals.of(<Torrent>[
        _t('a', activePeers: 5, uploaded: 100, downloaded: 200),
        _t('b', activePeers: 2, uploaded: -5, downloaded: 300),
      ]);
      expect(m.peers, 7);
      expect(m.uploadedBytes, 100);
      expect(m.downloadedBytes, 500);
      expect(m.movedBytes, 600);
    });

    test('★ 空列表与默认值不炸', () {
      final TransferTotals m = TransferTotals.of(const <Torrent>[]);
      expect(m.peers, 0);
      expect(m.movedBytes, 0);
    });
  });

  group('★ 控制器跨服务器汇总', () {
    test('★ transferTotals 把所有服务器的种子相加', () {
      final ServerController c = Get.put(ServerController());
      c.servers.assignAll(<ServerData>[_srv('s1'), _srv('s2')]);
      c.torrentCache['s1'] = <Torrent>[
        _t('a', activePeers: 4, uploaded: 1024, downloaded: 2048),
      ];
      c.torrentCache['s2'] = <Torrent>[
        _t('b', activePeers: 6, uploaded: 512, downloaded: 4096),
        _t('c', activePeers: 1, uploaded: 0, downloaded: 0),
      ];

      final TransferTotals m = c.transferTotals;
      expect(m.peers, 11);
      expect(m.uploadedBytes, 1536);
      expect(m.downloadedBytes, 6144);
    });

    test('★ 没有种子时全为 0（不误报）', () {
      final ServerController c = Get.put(ServerController());
      c.servers.assignAll(<ServerData>[_srv('s1')]);
      expect(c.transferTotals.peers, 0);
      expect(c.transferTotals.movedBytes, 0);
    });
  });

  group('★ 总计卡片渲染', () {
    testWidgets('★ 显示当前连接 / 累计下载 / 累计上传三块', (WidgetTester tester) async {
      const TransferTotals totals = TransferTotals(
        peers: 148,
        uploadedBytes: 480 * 1024 * 1024 * 1024,
        downloadedBytes: 1200 * 1024 * 1024 * 1024,
      );

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ServerStatsPanel(
            dlSpeed: 1024,
            upSpeed: 2048,
            counts: TorrentStatusCounts(
              downloading: 3,
              seeding: 5,
              paused: 1,
              checking: 0,
              error: 0,
              other: 0,
            ),
            serversOnline: 2,
            serversTotal: 3,
            totals: totals,
          ),
        ),
      ));

      // 数值与标签都在 Text.rich 内（find.text 匹配不到 TextSpan），
      // 因此按 RichText 的明文判断是否渲染出来。
      expect(_richHas(tester, S.statsLabelPeers), isTrue);
      expect(_richHas(tester, S.statsLabelTotalDl), isTrue);
      expect(_richHas(tester, S.statsLabelTotalUl), isTrue);
      expect(_richHas(tester, '148'), isTrue);
      expect(_richHas(tester, Formatter.setSize(totals.downloadedBytes)),
          isTrue);
      expect(_richHas(tester, Formatter.setSize(totals.uploadedBytes)), isTrue);
      // 速度右侧的「下载 / 上传」标签
      expect(_richHas(tester, S.chartLabelDownload), isTrue);
      expect(_richHas(tester, S.chartLabelUpload), isTrue);
      // 图例含「错误」项（不再按 0 过滤）
      expect(_richHas(tester, S.error), isTrue);
      expect(find.byKey(const Key('stats-status-donut')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('★ 零流量时渲染空槽不报错', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ServerStatsPanel(
            dlSpeed: 0,
            upSpeed: 0,
            counts: const TorrentStatusCounts(
              downloading: 0,
              seeding: 0,
              paused: 0,
              checking: 0,
              error: 0,
              other: 0,
            ),
            serversOnline: 0,
            serversTotal: 1,
            totals: TransferTotals.of(const <Torrent>[]),
          ),
        ),
      ));

      expect(find.text('0'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
