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
  group('第 70 轮 · 展开区对齐 v3（2026-09-26 第 99 轮：展开区整体退役）', () {
    final String src = _listPageSrc();
    final String ef = _fieldSrc();
    final String ov = _overviewSrc();

    test('★ 第 99 轮：卡片展开区已整体删除，点卡片直达详情', () {
      expect(src.contains('Widget _detail(Torrent t, ColorScheme cs)'), isFalse,
          reason: '展开区代码已随功能退役删除');
      expect(src.contains('_expanded'), isFalse,
          reason: '展开集合已删除');
      expect(src.contains('ensureEditFields'), isFalse,
          reason: '展开按需取数通道退役');

      final int i = src.indexOf('void _onCardTap(Torrent t)');
      final String body = src.substring(i, i + 400);
      expect(body.contains('_openDetail(t)'), isTrue,
          reason: '点击种子卡片 = 直接进详情');
      expect(body.contains('clearDraft'), isFalse,
          reason: '卡片不再有草稿生命周期');
    });

    test('★ 编辑能力收敛到详情页（与概览 Tab 共用同一批组件）', () {
      expect(ov.contains('ReadonlyKvGrid(pairs:'), isTrue);
      expect(ov.contains('_foldCard('), isTrue,
          reason: '2026-09-26 详情页重设计：概览分组卡为可折叠 _foldCard');
      expect(src.contains('EditSectionCard('), isFalse);
      expect(src.contains('EditNumberField('), isFalse,
          reason: '限速编辑随展开区退役，收敛到详情页');
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
