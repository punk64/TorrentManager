import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/utils/formatter.dart';
import 'package:torrent_manager/utils/strings.dart';
import 'package:torrent_manager/widgets/server_stats_panel.dart';

bool _richHas(WidgetTester tester, String text) {
  for (final RichText rt
      in tester.widgetList<RichText>(find.byType(RichText))) {
    if (rt.text.toPlainText().contains(text)) return true;
  }
  return false;
}

void main() {
  group('★ 第 72 轮 · 卡片隐私按钮判据（一键同时显示 / 隐藏地址 + 端口）', () {
    test('全显示 → 点击后全部隐藏', () {
      expect(
        ServerController.nextPrivacyHidden(
            hideAddress: false, hidePort: false),
        isTrue,
      );
    });

    test('全隐藏 → 点击后全部显示', () {
      expect(
        ServerController.nextPrivacyHidden(hideAddress: true, hidePort: true),
        isFalse,
      );
    });

    test('★ 不一致（只藏地址）→ 统一为全部隐藏', () {
      expect(
        ServerController.nextPrivacyHidden(
            hideAddress: true, hidePort: false),
        isTrue,
        reason: '用户拍板：两个字段不一致时，点击统一为「全部隐藏」',
      );
    });

    test('★ 不一致（只藏端口）→ 统一为全部隐藏', () {
      expect(
        ServerController.nextPrivacyHidden(
            hideAddress: false, hidePort: true),
        isTrue,
      );
    });
  });

  group('★ 第 72 轮 · 总计卡片：去圆环 + 折叠只留速度', () {
    const TransferTotals totals = TransferTotals(
      peers: 128,
      uploadedBytes: 4 * 1024 * 1024 * 1024,
      downloadedBytes: 12 * 1024 * 1024 * 1024,
    );

    Future<void> pump(WidgetTester tester, {required bool expanded}) {
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ServerStatsPanel(
            dlSpeed: 1024 * 1024,
            upSpeed: 320 * 1024,
            counts: const TorrentStatusCounts(
              downloading: 3,
              seeding: 12,
              paused: 5,
              checking: 0,
              error: 1,
              other: 0,
            ),
            serversOnline: 3,
            serversTotal: 5,
            totals: totals,
            expanded: expanded,
            onToggle: () {},
          ),
        ),
      ));
    }

    testWidgets('圆环（含中心总数）已移除', (WidgetTester tester) async {
      await pump(tester, expanded: true);
      expect(find.byKey(const Key('stats-status-donut')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('展开态：在线 / 当前连接 / 累计下载 / 累计上传 / 图例齐全',
        (WidgetTester tester) async {
      await pump(tester, expanded: true);

      expect(_richHas(tester, '3/5'), isTrue, reason: '服务器 3/5');
      expect(_richHas(tester, S.chartLabelServersOnline), isTrue);
      expect(find.text('128'), findsOneWidget, reason: '当前连接数（速度带右端）');
      expect(_richHas(tester, S.statsLabelTotalDl), isTrue);
      expect(_richHas(tester, S.statsLabelTotalUl), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('★ 折叠态：只留速度带（含当前连接），其余全部收起',
        (WidgetTester tester) async {
      await pump(tester, expanded: false);
      expect(_richHas(tester, S.statsLabelTotalDl), isFalse,
          reason: '折叠后不该再有累计下载');
      expect(_richHas(tester, S.statsLabelTotalUl), isFalse);
      expect(_richHas(tester, S.chartLabelServersOnline), isFalse);
      expect(_richHas(tester, '3/5'), isFalse);

      expect(find.text(Formatter.setSpeed(1024 * 1024)), findsOneWidget);
      expect(find.text(Formatter.setSpeed(320 * 1024)), findsOneWidget);

      expect(find.text('128'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
