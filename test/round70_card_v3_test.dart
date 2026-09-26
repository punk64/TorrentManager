import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/widgets/torrent_edit_fields.dart';

String _listPageSrc() =>
    File('lib/pages/torrent_list_page.dart').readAsStringSync();
String _fieldSrc() =>
    File('lib/widgets/torrent_edit_fields.dart').readAsStringSync();
String _overviewSrc() =>
    File('lib/pages/torrent_info_overview_page.dart').readAsStringSync();

int _nextDecl(String src, int from) {
  final RegExp re = RegExp(
      r'\n(?:  )?(?:static\s+)?(?:class\s+\w|Widget\s+\w|void\s+\w|Future<[^>]*>\s+\w|List<[^>]*>\s+\w|Map<[^>]*>\s+\w|Set<[^>]*>\s+\w|String\s+\w|bool\s+\w|int\s+\w|double\s+\w|Color\s+\w)');
  final Match? m = re.firstMatch(src.substring(from + 1));
  return m == null ? src.length : from + 1 + m.start;
}

void main() {
  group('第 70 轮 · 展开区对齐 v3（源码结构）', () {
    final String src = _listPageSrc();
    final String ef = _fieldSrc();
    final String ov = _overviewSrc();

    String detailBody() {
      final int i = src.indexOf('Widget _detail(Torrent t, ColorScheme cs)');
      return src.substring(i, _nextDecl(src, i));
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

    test('★ v2.b：展开区限速改 2×2 紧凑框（2026-09-26 用户拍板，覆盖 09-24 各占一行）', () {
      final String body = detailBody();
      expect(body.contains('Expanded(child: dlField(compact: true))'), isTrue);
      expect(body.contains('Expanded(child: upField(compact: true))'), isTrue);
      expect(body.contains('Expanded(child: ratioField(compact: true))'), isTrue);
      expect(body.contains('Expanded(child: seedTimeField(compact: true))'), isTrue);

      expect(body.contains('EditLayout.gridOkOf(context)'), isFalse,
          reason: '网格判据不下放：2×2 是固定布局，不再按屏宽回退');

      expect('EditSectionCard('.allMatches(body).length, 0,
          reason: 'v2：展开区用单一 inset 容器 + 分组标题，不再逐板块套分区卡片');
    });

    test('★ 与概览 Tab 共用同一套组件（不再各写一套排布）', () {

      expect(ov.contains('ReadonlyKvGrid(pairs:'), isTrue);
      expect(src.contains('ReadonlyKvGrid('), isTrue);
      // 2026-09-26 详情页重设计：概览 Tab 分组卡升级为可折叠 _foldCard
      //（视觉沿用 EditSectionCard 规格：色条 + 分组标题 + 同款边框），
      // KV 网格 / 限速输入 / 动作行仍与展开区共用同一批组件。
      expect(ov.contains('_foldCard('), isTrue);
      expect(src.contains('EditSectionCard('), isFalse,
          reason: 'v2：卡片展开区不再套分区卡片（概览 Tab 改用 _foldCard 折叠卡）');
      expect(src.contains('EditNumberField('), isTrue,
          reason: '限速编辑仍与概览共用 EditNumberField/EditRatioField');
      expect(src.contains('EditActionRow('), isTrue,
          reason: '路径/分类/标签仍共用 EditActionRow');

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
