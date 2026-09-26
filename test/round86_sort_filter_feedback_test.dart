import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/utils/strings.dart';
import 'package:torrent_manager/widgets/sort_filter_panel.dart';

Torrent mk({required String hash, String? category}) => Torrent(
      hash: hash,
      name: hash,
      size: 0,
      progress: 0,
      state: 'downloading',
      dlSpeed: 0,
      upSpeed: 0,
      numSeeds: 0,
      numLeechs: 0,
      ratio: 0,
      category: category,
    );

Future<void> pumpPanel(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    const GetMaterialApp(home: Scaffold(body: SortFilterPanel())),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TorrentController ctrl;

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
    Get.reset();
    Get.put(ServerController());
    ctrl = Get.put(TorrentController());
  });

  tearDown(() => Get.reset());

  testWidgets('第 86 轮 S1 · ★ 默认全部折叠，先给「标题 + 当前值摘要」',
      (WidgetTester tester) async {
    ctrl.items.assignAll(<Torrent>[mk(hash: 'a', category: '电影')]);
    await pumpPanel(tester);

    expect(find.text('排序方式'), findsOneWidget);
    expect(find.text(S.filterStatusTitle), findsOneWidget);

    expect(find.text('添加时间'), findsNothing, reason: '排序维度默认不铺开');
    expect(find.text('升序'), findsNothing, reason: '升 / 降序默认不铺开');
    expect(find.text('电影 (1)'), findsNothing, reason: '分类候选默认不铺开');

    expect(find.text('添加时间 ↓'), findsOneWidget,
        reason: '★ 折叠态也要让用户看到当前排序与方向');
    expect(find.text('未筛选'), findsNWidgets(5),
        reason: '状态 + 4 个分组都未筛选，摘要必须齐全');
  });

  testWidgets('第 86 轮 S2 · ★ 结果条随筛选实时变化（点一下立刻可见）',
      (WidgetTester tester) async {
    ctrl.items.assignAll(<Torrent>[
      mk(hash: 'a', category: '电影'),
      mk(hash: 'b'),
    ]);
    await pumpPanel(tester);

    expect(find.text('筛选后'), findsOneWidget);
    expect(find.text('2'), findsOneWidget,
        reason: '面板一进来就该显示「筛选后 2 / 共 2 个」');
    expect(find.text(' / 共 2 个'), findsOneWidget);

    await tester.tap(find.text('分类'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('电影 (1)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1'), findsNWidgets(2),
        reason: '★ 结果条数字变 1 + 分类徽标变 1：用户立刻知道这一下点生效了');
    expect(find.text('1 个已选'), findsOneWidget);
    expect(find.text('2 个已选'), findsNothing);
  });

  testWidgets('第 86 轮 S3 · ★ 展开有高度动画，箭头旋转 180°',
      (WidgetTester tester) async {
    ctrl.items.assignAll(<Torrent>[mk(hash: 'a')]);
    await pumpPanel(tester);

    expect(find.byType(AnimatedSize), findsWidgets,
        reason: '展开 / 收起要走高度动画，不能瞬间跳变');
    AnimatedRotation rot = tester
        .widget<AnimatedRotation>(find.byType(AnimatedRotation).first);
    expect(rot.turns, 0, reason: '折叠时箭头朝下');

    await tester.tap(find.text('排序方式'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    rot = tester
        .widget<AnimatedRotation>(find.byType(AnimatedRotation).first);
    expect(rot.turns, 0.5, reason: '★ 箭头转 180°，用户才知道这一下点开了');
    expect(find.text('添加时间'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsWidgets,
        reason: '按钮选中态要平滑过渡');
  });

  testWidgets('第 86 轮 S4 · ★ 筛选生效时结果条换主色实底（要显眼）',
      (WidgetTester tester) async {
    ctrl.items.assignAll(<Torrent>[
      mk(hash: 'a', category: '电影'),
      mk(hash: 'b'),
    ]);
    await pumpPanel(tester);

    final ColorScheme cs =
        Theme.of(tester.element(find.text('筛选后'))).colorScheme;

    BoxDecoration decoOf() => tester
        .widget<Container>(find
            .ancestor(of: find.text('筛选后'), matching: find.byType(Container))
            .first)
        .decoration! as BoxDecoration;

    expect(decoOf().color, isNot(cs.primary), reason: '没筛选时用浅底');

    ctrl.toggleFacet(FilterDim.category, '电影');
    await tester.pump();

    expect(decoOf().color, cs.primary,
        reason: '★ 一旦有筛选就用主色实底，一眼看出当前视图被筛选过');
  });
}
