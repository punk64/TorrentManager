import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/widgets/torrent_edit_fields.dart';

/// 第 70 轮：卡片展开区**对齐 v3**（2026-09-24 22:1x 用户报障后补做）。
///
/// 背景：v3（10.5 定稿）此前只落到**概览 Tab**，展开区仍是旧排布（4 个整行 Switch +
/// 单列只读信息），与展开区自己的定稿图 `round67-展开区新方案-内联编辑-浅色.png`
/// （开关同一行 chip + 只读两列）也不符。本轮把 v3 的排布**抽成共享组件**
/// （`EditLayout` / `ReadonlyKvGrid`），概览 Tab 与展开区共用同一份实现。
String _listPageSrc() =>
    File('lib/pages/torrent_list_page.dart').readAsStringSync();
String _fieldSrc() =>
    File('lib/widgets/torrent_edit_fields.dart').readAsStringSync();
String _overviewSrc() =>
    File('lib/pages/torrent_info_overview_page.dart').readAsStringSync();

void main() {
  group('第 70 轮 · 展开区对齐 v3（源码结构）', () {
    final String src = _listPageSrc();
    final String ef = _fieldSrc();
    final String ov = _overviewSrc();

    /// 取 `_detail()` 全文（到下一个注释分隔线为止）。
    String detailBody() {
      final int i = src.indexOf('Widget _detail(Torrent t, ColorScheme cs)');
      return src.substring(i, src.indexOf('// ------', i));
    }

    test('展开区开关 = 同一行 chip（EditSwitchChip + Wrap），旧整行 Switch 已拆', () {
      final String body = detailBody();
      expect(body.contains('EditSwitchChip('), isTrue);
      expect(body.contains('Wrap('), isTrue);
      expect(body.contains('EditSwitchRow('), isFalse,
          reason: 'v3：4 个开关压成同一行，不再用整行 Switch');
    });

    test('展开区只读信息 = 两列网格（ReadonlyKvGrid），旧的单列拼接已拆', () {
      final String body = detailBody();
      expect(body.contains('ReadonlyKvGrid('), isTrue);
      expect(body.contains('fullRows:'), isTrue);
      expect(body.contains('pairs:'), isTrue);
      expect(body.contains(r"kv('${S.fieldPath}：'"), isFalse,
          reason: 'v3：只读信息改两列网格；长值（内容路径）走 fullRows 独占行');
    });

    test('展开区可编辑 4 项 = **各独占一行**（2026-09-24 用户整改：撤回 2×2）', () {
      final String body = detailBody();
      expect(body.contains('dlField(),'), isTrue);
      expect(body.contains('upField(),'), isTrue);
      expect(body.contains('ratioField(),'), isTrue);
      expect(body.contains('seedTimeField(),'), isTrue);
      // 撤回 2×2
      expect(body.contains('dlField(compact: true)'), isFalse);
      expect(body.contains('EditLayout.gridOkOf(context)'), isFalse,
          reason: '不再 2×2 ⇒ 展开区无需紧凑判据（网格判据下沉到共享组件内部）');
      // 每栏目有边界感：常规 / 限速与分享 / 下载策略 / 信息 = 4 个分区卡片
      expect('EditSectionCard('.allMatches(body).length, 4,
          reason: '展开区 4 个板块各套一张分区卡片');
    });

    test('★ 与概览 Tab 共用同一套组件（不再各写一套排布）', () {
      // 只读两列网格 + 分区卡片：两处共用同一份实现
      expect(ov.contains('ReadonlyKvGrid(pairs:'), isTrue);
      expect(src.contains('ReadonlyKvGrid('), isTrue);
      expect(ov.contains('EditSectionCard('), isTrue);
      expect(src.contains('EditSectionCard('), isTrue);
      // 展开区不该再自己造两列网格（这会回到"两处各一套、改一处漏一处"的老路）
      expect(src.contains('Widget _kvGrid('), isFalse);
      expect(src.contains('Widget _kvHalf('), isFalse);
    });

    test('共享组件的判据与回退形态（台账 B3）', () {
      expect(ef.contains('class EditLayout'), isTrue);
      expect(ef.contains('static bool gridOkOf('), isTrue);
      final int i = ef.indexOf('static bool gridOkOf(');
      final String body = ef.substring(i, i + 200);
      expect(body.contains('>= 360'), isTrue);
      expect(body.contains('1.15'), isTrue);
      expect(ef.contains('class ReadonlyKvGrid'), isTrue);
    });
  });

  group('第 70 轮 · ReadonlyKvGrid 渲染', () {
    Future<void> pumpGrid(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ReadonlyKvGrid(
            fullRows: <List<String>>[
              <String>['路径', '/downloads/anime/长路径示例'],
            ],
            pairs: <List<String>>[
              <String>['已上传', '1.2 GB'],
              <String>['已下载', '3.4 GB'],
              <String>['添加时间', '2026-09-10'],
              <String>['完成时间', '2026-09-11'],
              <String>['活动时间', '3 分钟前'],
            ],
          ),
        ),
      ));
    }

    testWidgets('宽屏（400dp）：短值两两一行', (WidgetTester tester) async {
      await pumpGrid(tester, 400);

      final double yUp = tester.getCenter(find.text('已上传')).dy;
      final double yDl = tester.getCenter(find.text('已下载')).dy;
      final double yAdd = tester.getCenter(find.text('添加时间')).dy;
      final double yDone = tester.getCenter(find.text('完成时间')).dy;

      expect(yDl, closeTo(yUp, 0.6), reason: '已上传｜已下载 = 同一行');
      expect(yDone, closeTo(yAdd, 0.6), reason: '添加时间｜完成时间 = 同一行');
      expect(yAdd, greaterThan(yUp), reason: '第二行在第一行下面');
    });

    testWidgets('窄屏（320dp）：回退单列（B3）', (WidgetTester tester) async {
      await pumpGrid(tester, 320);

      final double yUp = tester.getCenter(find.text('已上传')).dy;
      final double yDl = tester.getCenter(find.text('已下载')).dy;
      expect(yUp, lessThan(yDl), reason: 'B3：窄屏回退单列，不再并排');
    });

    testWidgets('长值（fullRows）独占一行，不参与两列', (WidgetTester tester) async {
      await pumpGrid(tester, 400);

      final double yPath = tester.getCenter(find.text('路径')).dy;
      final double yUp = tester.getCenter(find.text('已上传')).dy;
      expect(yPath, lessThan(yUp), reason: '长值路径在网格之前独占一行');
    });
  });
}
