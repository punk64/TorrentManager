














import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/pages/torrent_info_overview_page.dart';
import 'package:torrent_manager/pages/torrent_info_peers_page.dart';
import 'package:torrent_manager/utils/strings.dart';

const Torrent t = Torrent(
  hash: 'h1',
  name: '示例种子',
  size: 10000000,
  progress: 0.5,
  state: 'downloading',
  dlSpeed: 2048,
  upSpeed: 1024,
  numSeeds: 12,
  numLeechs: 3,
  ratio: 2.31,
  downloaded: 300000000,
  uploaded: 120000000,
);

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
  });

  Future<void> pumpOverview(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GetMaterialApp(
      initialBinding: AppBinding(),
      home: const Scaffold(body: TorrentInfoOverviewPage()),
    ));
    Get.find<TorrentController>().current.value = t;
    await tester.pump();
  }

  Future<void> pumpPeers(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GetMaterialApp(
      initialBinding: AppBinding(),
      home: const Scaffold(
        body: SizedBox(height: 700, child: TorrentInfoPeersPage()),
      ),
    ));
    await tester.pump();
  }

  
  
  
  group('A. 概览页：操作按钮上移到字段之上', () {
    testWidgets('★ 五个操作按钮都在，且排在字段列表之前',
        (WidgetTester tester) async {
      await pumpOverview(tester);

      const List<String> ops = <String>['继续', '暂停', '重新校验', '重新汇报'];
      for (final String label in ops) {
        expect(find.text(label), findsOneWidget,
            reason: '★ 操作按钮 `$label` 应恰好存在一份（搬位置不是复制）');
      }
      expect(find.text(S.delete), findsOneWidget);

      
      final double opY = tester.getCenter(find.text('继续')).dy;
      final double progressY =
          tester.getCenter(find.textContaining(S.fieldProgress)).dy;
      final double fieldY = tester.getCenter(find.text(S.fieldState)).dy;

      expect(opY, greaterThan(progressY),
          reason: '按钮组应紧跟在「进度」之后（在进度下方、字段上方）');
      expect(opY, lessThan(fieldY),
          reason: '★ 需求：操作按钮上移到页面上方 —— 必须排在字段列表之前，'
              '否则等于没改（旧实现排在整页最底部）');
    });

    testWidgets('★ 概览按钮组是 Wrap（空间不足换行，不横滑）',
        (WidgetTester tester) async {
      await pumpOverview(tester);
      expect(find.byType(Wrap), findsWidgets,
          reason: '★ 需求 3：改用 Wrap 让宽度不足时自动换行，全部按钮可见');

      
      for (final ScrollableState s
          in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
        expect(s.position.axis, Axis.vertical,
            reason: '★ 概览页不得出现横向滑动条目列表');
      }
    });
  });

  
  
  
  group('C. Peers 排序条：Wrap 换行 + 全部可见', () {
    testWidgets('★ 不再是横向 ListView：页面上没有横向 Scrollable',
        (WidgetTester tester) async {
      await pumpPeers(tester);

      expect(find.byType(Wrap), findsOneWidget,
          reason: '★ 需求 3：排序条改为 Wrap，空间不足自动换行');
      for (final ScrollableState s
          in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
        expect(s.position.axis, Axis.vertical,
            reason: '★ 需求 3：按钮组不得再采用左右横向滑动');
      }
    });

    testWidgets('★ 窄屏（360dp）下五个排序按钮全部可见',
        (WidgetTester tester) async {
      await pumpPeers(tester);

      for (final String label in <String>[
        S.fieldDlSpeed,
        S.fieldUpSpeed,
        S.fieldProgress,
        S.fieldIp,
      ]) {
        expect(find.text(label), findsOneWidget,
            reason: '★ 需求 3：`$label` 必须全部可见（不得藏在屏外）');
      }
      expect(find.textContaining('排序'), findsOneWidget,
          reason: '★ 需求 2：组前应补一个「排序」标签说明这排按钮的作用');
    });
  });

  group('D. Peers 排序条：tooltip 与动态方向文案', () {
    testWidgets('★ 每个排序按钮都带 Tooltip 说明', (WidgetTester tester) async {
      await pumpPeers(tester);

      
      expect(find.byType(Tooltip), findsNWidgets(5),
          reason: '★ 需求 2：排序切换类按钮要有 tooltip / 说明，'
              '让用户知道它是"切换排序依据"而不是某个动作');
      expect(
        find.byTooltip('按${S.fieldDlSpeed}排序'),
        findsWidgets,
        reason: '★ 下载速度 chip 应说明「按下载速度排序」',
      );
    });

    testWidgets('★ 「方向」改为动态文案：随维度与升/降序变化',
        (WidgetTester tester) async {
      await pumpPeers(tester);

      expect(find.text('方向'), findsNothing,
          reason: '★ 旧文案「方向」含义不明，必须换成动态说明');

      
      
      final Finder dirChip = find.byType(ActionChip);

      
      expect(find.text('从快到慢'), findsOneWidget);

      
      await tester.tap(dirChip);
      await tester.pump();
      expect(find.text('从慢到快'), findsOneWidget,
          reason: '★ 切换后文案应同步反转');

      
      
      await tester.tap(find.text(S.fieldIp));
      await tester.pump();
      expect(find.text('正序'), findsOneWidget,
          reason: '★ 按 IP 排不属于大小关系，应说正序 / 倒序；'
              '且升降序状态跨维度保留（此前是升序）');

      await tester.tap(dirChip);
      await tester.pump();
      expect(find.text('倒序'), findsOneWidget);
    });
  });
}
