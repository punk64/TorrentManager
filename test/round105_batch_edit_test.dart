import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/app/theme.dart';
import 'package:torrent_manager/widgets/path_dropdown.dart';
import 'package:torrent_manager/widgets/torrent_edit_fields.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('路径候选：Windows/UNC 保留、去重、默认在前', () {
    final List<PathCandidate> out = PathCandidates.build(
      defaultPath: r'D:\Media\Downloads',
      tempPath: '/tmp/incomplete',
      categoryPaths: <String, String>{'电影': r'D:\Media\Movies'},
      current: r'D:\Media',
      seedPaths: <String, int>{
        '/mnt/data': 12,
        r'D:\Media\Movies': 3,
        r'\\NAS\share\bt': 7,
        '未指定': 9,
      },
    );
    final List<String> paths =
        out.map((PathCandidate c) => c.path).toList(growable: false);
    expect(paths.first, r'D:\Media\Downloads');
    expect(paths, contains(r'\\NAS\share\bt'));
    expect(paths, contains('/mnt/data'));
    expect(paths, isNot(contains('未指定')));
    expect(paths.where((String p) => p == r'D:\Media\Movies'), hasLength(1));
    expect(out.first.source, PathCandidates.srcDefault);
    expect(out[1].source, PathCandidates.srcTemp);
    expect(out[2].source, '分类：电影');
    expect(out[3].source, PathCandidates.srcCurrent);
    final int iData = paths.indexOf('/mnt/data');
    final int iNas = paths.indexOf(r'\\NAS\share\bt');
    expect(iData < iNas, isTrue, reason: '种子路径按数量降序');
  });

  testWidgets('EditActionRow：按钮与首行文字平齐（第 110 轮改顶对齐，center 会悬在两行值中间）',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(445 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: EditActionRow(
          label: '种子分类',
          value: '剧集',
          onTap: () {},
        ),
      ),
    ));

    final Row row = tester.widget<Row>(find.byType(Row));
    expect(row.crossAxisAlignment, CrossAxisAlignment.start);

    // 几何断言：单行值时「修改」按钮中线 == 左侧 label 文字中线（±1.5px）
    final Rect labelRect = tester.getRect(find.text('种子分类'));
    final Rect btnRect = tester.getRect(find.byType(FilledButton));
    expect(labelRect.center.dy, closeTo(btnRect.center.dy, 1.5));

    // label 与 value 用相同的顶距（保证值 2 行时首行依旧平齐）
    final List<double> tops = tester
        .widgetList<Padding>(find.descendant(
            of: find.byType(Row), matching: find.byType(Padding)))
        .map((Padding p) => p.padding)
        .whereType<EdgeInsets>()
        .where((EdgeInsets e) => e.top > 0)
        .map((EdgeInsets e) => e.top)
        .toList();
    expect(tops, hasLength(2), reason: 'label 与 value 各有一个顶距');
    expect(tops.first, tops.last);
  });

  testWidgets('路径下拉：Windows 路径可选且可编辑', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(445 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final TextEditingController c = TextEditingController();

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: PathDropdownField(
          controller: c,
          label: '保存路径',
          candidates: const <PathCandidate>[
            PathCandidate(r'D:\Media\Downloads', '默认保存路径'),
            PathCandidate('/mnt/data', '种子 ×3'),
          ],
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pump();

    expect(find.text(r'D:\Media\Downloads'), findsOneWidget);
    expect(find.text('默认保存路径'), findsOneWidget);
    await tester.tap(find.text(r'D:\Media\Downloads'));
    await tester.pump();
    expect(c.text, r'D:\Media\Downloads');
  });

  testWidgets('分类弹窗：下载器全量 + 来源徽章 + 搜索过滤',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(445 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () => unawaited(EditDialogs.category(
              ctx,
              initial: '',
              candidates: const <String>['电影', '剧集', '纪录片'],
              serverCandidates: const <String>['电影', '剧集'],
              counts: const <String, int>{'电影': 8},
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('电影'), findsOneWidget);
    expect(find.text('剧集'), findsOneWidget);
    expect(find.text('纪录片'), findsOneWidget);
    expect(find.text('下载器'), findsNWidgets(2));
    expect(find.text('列表'), findsOneWidget);
    expect(find.text('种子 ×8'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '剧');
    await tester.pump();
    expect(find.text('剧集'), findsOneWidget);
    expect(find.text('电影'), findsNothing);
    expect(find.textContaining('新建「剧」'), findsOneWidget);
  });

  testWidgets('标签弹窗：候选不截断 12 条 + 搜索过滤',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(445 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final List<String> cands =
        List<String>.generate(20, (int i) => 'T$i', growable: false);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () => unawaited(EditDialogs.tags(
              ctx,
              initial: const <String>['蓝光'],
              candidates: cands,
              showAppendSwitch: true,
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.widgetList(find.byType(ActionChip)), hasLength(20),
        reason: '服务器全量标签必须全部可选，不再截断 12 条');
    expect(find.textContaining('共 20 个标签'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'T1');
    await tester.pump();
    expect(tester.widgetList(find.byType(ActionChip)), hasLength(11),
        reason: 'T1 + T10~T19');
  });
}
