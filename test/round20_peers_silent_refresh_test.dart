














import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/pages/torrent_info_peers_page.dart';





Map<String, dynamic> peer(String ip, int dl, int up) => <String, dynamic>{
      'ip': ip,
      'address': ip,
      'client': 'Client-$ip',
      'clientName': 'Client-$ip',
      'progress': 0.42,
      'dl_speed': dl,
      'rateToClient': dl,
      'up_speed': up,
      'rateToPeer': up,
    };

List<Map<String, dynamic>> manyPeers(int n) => <Map<String, dynamic>>[
      for (int i = 0; i < n; i++) peer('10.0.0.$i', i * 10, i * 5),
    ];

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

  Future<void> pumpPeers(WidgetTester tester) async {
    await tester.pumpWidget(GetMaterialApp(
      home: const Scaffold(body: SizedBox(height: 600, child: TorrentInfoPeersPage())),
      initialBinding: AppBinding(),
    ));
    await tester.pump();
  }

  
  
  ScrollableState verticalList(WidgetTester tester) =>
      tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .firstWhere((ScrollableState s) => s.position.axis == Axis.vertical);

  
  
  
  group('① 无刷新动画 / 无加载态', () {
    testWidgets('★ 即使 detailLoading 为真、且列表为空，也不出现转圈',
        (WidgetTester tester) async {
      await pumpPeers(tester);
      final TorrentController ctrl = Get.find<TorrentController>();

      
      ctrl.detailLoading.value = true;
      ctrl.peers.assignAll(manyPeers(3));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: '★ 需求 1：Peers 栏全程**不展示刷新动画或加载态**');
      expect(find.text('暂无 Peer 数据'), findsNothing);
      expect(find.text('10.0.0.0'), findsOneWidget,
          reason: '★ 有数据时应照常渲染，不受加载态影响');
    });

    testWidgets('★ 轮询更新（同一批 + 新数据）前后，均无加载态闪现',
        (WidgetTester tester) async {
      await pumpPeers(tester);
      final TorrentController ctrl = Get.find<TorrentController>();
      ctrl.peers.assignAll(manyPeers(3));
      await tester.pump();

      
      ctrl.detailLoading.value = true;
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: '★ 轮询期间不得出现加载指示');

      ctrl.detailLoading.value = false;
      ctrl.peers.assignAll(manyPeers(4));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('10.0.0.3'), findsOneWidget,
          reason: '★ 新数据应原地同步出现');
    });
  });

  
  
  
  group('② 数据变化不重置滚动位置', () {
    testWidgets('★ 轮询写入新 peers 后，滚动 offset 原地保留',
        (WidgetTester tester) async {
      await pumpPeers(tester);
      final TorrentController ctrl = Get.find<TorrentController>();
      ctrl.peers.assignAll(manyPeers(40));
      await tester.pump();

      final ScrollableState list = verticalList(tester);
      final double before = list.position.pixels;
      
      list.position.jumpTo(180);
      await tester.pump();
      expect(list.position.pixels, 180);

      
      final List<Map<String, dynamic>> next = manyPeers(40);
      next[0]['dl_speed'] = 999999; 
      ctrl.peers.assignAll(next);
      await tester.pump();

      expect(list.position.pixels, 180,
          reason: '★ 需求 1：数据更新后**不得重置滚动位置**'
              '（ListView 的 key 必须恒定，重建才能复用同一个 Scrollable 状态）');
      expect(before, 0, reason: '初始值应为 0，用于确认上面的 jumpTo 确实生效');
    });
  });

  
  
  
  group('③ 没有可用 Peer 链接', () {
    testWidgets('★ 保持现有空状态，且不执行任何刷新动画',
        (WidgetTester tester) async {
      await pumpPeers(tester);
      final TorrentController ctrl = Get.find<TorrentController>();

      ctrl.detailLoading.value = true;
      ctrl.peers.clear();
      await tester.pump();

      expect(find.text('暂无 Peer 数据'), findsOneWidget,
          reason: '★ 空状态文案保持不变');
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: '★ 需求 1：该种子没有 Peer 时**同样不执行刷新动画**');

      
      ctrl.detailLoading.value = false;
      await tester.pump();
      expect(find.text('暂无 Peer 数据'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
