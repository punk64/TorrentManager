import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/pages/torrent_info_overview_page.dart';
import 'package:torrent_manager/pages/torrent_list_page.dart';
import 'package:torrent_manager/utils/strings.dart';
import 'package:torrent_manager/widgets/sort_filter_panel.dart';
import 'package:torrent_manager/widgets/torrent_edit_fields.dart';

/// 第 71 轮：**8 条界面整改**（2026-09-24 用户逐条下达）。
///
/// ① 卡片展开区/详情页**每栏目要有边界感** ⇒ 新增共享组件 `EditSectionCard`；
/// ②/⑦ 四个限速项（下载限速 / 上传限速 / 分享率上限 / 做种时限）**改回独占一行**
///   （撤回 2026-09-24 早先的 v3 2×2 —— 半格里输入框只剩几十 dp，边框都看不见）；
/// ③ 筛选面板「主状态」下拉 → **按钮网格**（与「排序方式」同形态、单选）；
/// ④ 多选栏按钮**加填充底**、改成**固定两行 × 4 列**、**不允许左右滑动**；
/// ⑤ 详情页每栏目分区；
/// ⑥ 详情页六个操作按钮**固定两行 × 3 列**、自适应、不横滑；
/// ⑧ 详情页底部**站点名称 / 哈希各独占一行 + 复制按钮**。
String _read(String p) => File(p).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final String listSrc = _read('lib/pages/torrent_list_page.dart');
  final String ovSrc = _read('lib/pages/torrent_info_overview_page.dart');
  final String panelSrc = _read('lib/widgets/sort_filter_panel.dart');
  final String fieldSrc = _read('lib/widgets/torrent_edit_fields.dart');

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    Get.testMode = true;
    Get.reset();
  });

  final Torrent t = Torrent(
    hash: 'a1b2c3d4e5f60718293a4b5c6d7e8f9012345678',
    name: '示例种子',
    size: 5368709120,
    progress: 0.42,
    state: 'downloading',
    dlSpeed: 2048,
    upSpeed: 1024,
    numSeeds: 12,
    numLeechs: 3,
    ratio: 2.31,
    downloaded: 300000000,
    uploaded: 120000000,
    savePath: '/downloads/ubuntu',
    contentPath: '/downloads/ubuntu/x.iso',
    trackerCount: 1,
    magnetUri: 'magnet:?xt=urn:btih:a1b2c3d4e5f60718293a4b5c6d7e8f9012345678',
    comment: 'https://example.com/details/1',
  );

  ServerData qb() => ServerData(
        id: 'qb',
        name: 'qb',
        type: 'qbittorrent',
        host: '1.2.3.4',
        port: 8080,
      );

  Future<void> pumpOverview(WidgetTester tester, {ServerData? server}) async {
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GetMaterialApp(
      initialBinding: AppBinding(),
      home: const Scaffold(body: TorrentInfoOverviewPage()),
    ));
    if (server != null) Get.find<ServerController>().current.value = server;
    Get.find<TorrentController>().current.value = t;
    await tester.pump();
  }

  group('第 71 轮 · ① 分区卡片（每栏目边界感）', () {
    test('共享组件 EditSectionCard 就位，且用主题色（不硬编码）', () {
      expect(fieldSrc.contains('class EditSectionCard'), isTrue);
      final int i = fieldSrc.indexOf('class EditSectionCard');
      final String body = fieldSrc.substring(i, i + 1400);
      expect(body.contains('surfaceContainerHighest'), isTrue,
          reason: '底色跟主题走');
      expect(body.contains('outlineVariant'), isTrue, reason: '边框跟主题走');
      expect(body.contains('AppTheme.radiusSmall'), isTrue);
    });

    test('展开区 4 个栏目各套一张分区卡片；详情页 7 个栏目同样', () {
      // 展开区：常规 / 限速与分享 / 下载策略 / 信息
      final int a = listSrc.indexOf('Widget _detail(Torrent t, ColorScheme cs)');
      final String detail =
          listSrc.substring(a, listSrc.indexOf('// ------', a));
      expect('EditSectionCard('.allMatches(detail).length, 4);
      // 详情页：实时状态 / 操作 / 信息 / 限速与分享 / 时间信息 / 常规 / 链接与标识
      expect('EditSectionCard('.allMatches(ovSrc).length, 7);
    });
  });

  group('第 71 轮 · ②⑦ 四个限速项改回独占一行', () {
    test('展开区：4 个字段直排，不再传 compact、不再有 wide 判据', () {
      final int a = listSrc.indexOf('Widget _detail(Torrent t, ColorScheme cs)');
      final String detail =
          listSrc.substring(a, listSrc.indexOf('// ------', a));
      expect(detail.contains('dlField(),'), isTrue);
      expect(detail.contains('upField(),'), isTrue);
      expect(detail.contains('ratioField(),'), isTrue);
      expect(detail.contains('seedTimeField(),'), isTrue);
      expect(detail.contains('compact: true'), isFalse);
      expect(detail.contains('final bool wide'), isFalse);
    });

    test('详情页：4 个字段直排，`_editGrid` 已拆', () {
      expect(ovSrc.contains('Widget _editGrid('), isFalse);
      expect(ovSrc.contains('_dlLimitField(t)'), isTrue);
      expect(ovSrc.contains('_upLimitField(t)'), isTrue);
      expect(ovSrc.contains('_ratioLimitField(t)'), isTrue);
      expect(ovSrc.contains('_seedTimeField(t)'), isTrue);
      expect(ovSrc.contains('compact: true'), isFalse);
    });

    test('文案以用户口径为准：完整「分享率上限」，不用短文案', () {
      expect(ovSrc.contains('label: S.fieldRatioLimit,'), isTrue);
      expect(ovSrc.contains('S.fieldRatioLimitShort'), isFalse);
      expect(S.fieldRatioLimit, '分享率上限');
      expect(S.fieldDlLimit, '下载限速');
      expect(S.fieldUpLimit, '上传限速');
      expect(S.fieldSeedingTimeLimit, '做种时限');
    });

    testWidgets('渲染：详情页 4 项各占一行（y 递增）', (WidgetTester tester) async {
      await pumpOverview(tester, server: qb());

      final double yDl = tester.getCenter(find.text(S.fieldDlLimit)).dy;
      final double yUp = tester.getCenter(find.text(S.fieldUpLimit)).dy;
      final double yRatio = tester.getCenter(find.text(S.fieldRatioLimit)).dy;
      final double ySeed =
          tester.getCenter(find.text(S.fieldSeedingTimeLimit)).dy;
      expect(yUp, greaterThan(yDl));
      expect(yRatio, greaterThan(yUp));
      expect(ySeed, greaterThan(yRatio));
    });
  });

  group('第 71 轮 · ③ 主状态改按钮网格', () {
    test('下拉已拆、按钮网格就位，且走共享 _btn（单选）', () {
      expect(panelSrc.contains('_statusGrid()'), isTrue);
      expect(panelSrc.contains('_statusDropdown'), isFalse);
      final int i = panelSrc.indexOf('Widget _statusGrid()');
      final String body = panelSrc.substring(i, i + 1200);
      expect(body.contains('TorrentFilter.values'), isTrue);
      expect(body.contains('_btn('), isTrue, reason: '与「排序方式」同一套按钮形态');
      expect(body.contains('selected: ctrl.filter.value == row[j]'), isTrue,
          reason: '单选：只高亮当前主状态');
      expect(body.contains('onTap: () => ctrl.setFilter(row[j])'), isTrue);
    });

    testWidgets('渲染：9 个主状态都以按钮呈现，点选即生效且单选',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Get.put(ServerController());
      final TorrentController ctrl = TorrentController();
      Get.put(ctrl);

      await tester.pumpWidget(const GetMaterialApp(
        home: Scaffold(body: SortFilterPanel()),
      ));
      await tester.pump();

      for (final TorrentFilter f in TorrentFilter.values) {
        expect(find.text(f.label), findsOneWidget,
            reason: '缺「${f.label}」按钮');
      }
      // 单选：切换主状态后只剩一个选中
      await tester.tap(find.text(TorrentFilter.downloading.label));
      await tester.pump();
      expect(ctrl.filter.value, TorrentFilter.downloading);
      await tester.tap(find.text(TorrentFilter.seeding.label));
      await tester.pump();
      expect(ctrl.filter.value, TorrentFilter.seeding);
    });
  });

  group('第 71 轮 · ④ 多选栏两行网格 + 填充底', () {
    test('旧的横滑批量行已拆，改固定网格；网格方法里没有任何横向滚动', () {
      expect(listSrc.contains('Widget _actionGrid()'), isTrue);
      expect(listSrc.contains('Widget _batchRow()'), isFalse);
      expect(listSrc.contains('Widget _actionRow()'), isFalse);
      final int i = listSrc.indexOf('Widget _actionGrid()');
      final String body = listSrc.substring(i, listSrc.indexOf('/// 网格里的按钮', i));
      expect(body.contains('SingleChildScrollView'), isFalse,
          reason: '用户要求：不可以左右滑动');
      expect(body.contains('scrollDirection'), isFalse);
      expect(body.contains('Expanded('), isTrue, reason: '等宽自适应');
    });

    test('按钮有填充底 + 边框（与「状态筛选」按钮同口径）', () {
      final int i = listSrc.indexOf('Widget _gridButton(');
      final String body = listSrc.substring(i, i + 1800);
      expect(body.contains('surfaceContainerHighest'), isTrue,
          reason: '不透明填充底 ⇒ 彩色壁纸下文字可读');
      expect(body.contains('BorderSide'), isTrue);
      expect(body.contains('AppTheme.radius'), isTrue);
      expect(body.contains('overflow: TextOverflow.ellipsis'), isTrue);
    });

    test('整块有不透明外层底色（隔开壁纸）', () {
      final int i = listSrc.indexOf('Widget _actionGrid()');
      final String body = listSrc.substring(i, i + 2600);
      expect(body.contains('color: cs.surface,'), isTrue);
    });

    testWidgets('渲染：进入多选后 8 个按钮排成两行 × 4 列',
        (WidgetTester tester) async {
      // ★ 视口须放宽：顶部速度条 disk_io_chip 在测试宿主(方块字体)下窄屏会溢出，
      //   属既有组件、非本轮改动；放宽到能容纳即可（真机正常）。
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Get.put(ThemeController(), permanent: true);
      await tester.pumpWidget(GetMaterialApp(
        initialBinding: AppBinding(),
        home: const TorrentListPage(),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      // ★ 顺序关键：设服务器会触发监听清空 items ⇒ 先设服务器再灌数据。
      Get.find<ServerController>().current.value = qb();
      await tester.pump(const Duration(milliseconds: 200));
      final TorrentController ctrl = Get.find<TorrentController>();
      ctrl.items.assignAll(<Torrent>[t]);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pump(const Duration(milliseconds: 200));
      ctrl.selectAll();
      await tester.pump(const Duration(milliseconds: 200));

      final double y1 = tester.getCenter(find.text(S.actStart)).dy;
      final double y2 = tester.getCenter(find.text(S.actPause)).dy;
      final double y3 = tester.getCenter(find.text(S.fieldVerifyState)).dy;
      final double y4 = tester.getCenter(find.text(S.delete)).dy;
      expect(y2, closeTo(y1, 0.6), reason: '行 1：开始｜暂停｜校验｜删除');
      expect(y3, closeTo(y1, 0.6));
      expect(y4, closeTo(y1, 0.6));

      final double y5 = tester.getCenter(find.text(S.batchEdit)).dy;
      final double y6 = tester.getCenter(find.text(S.copyHash)).dy;
      final double y7 = tester.getCenter(find.text(S.copyMagnet)).dy;
      expect(y6, closeTo(y5, 0.6), reason: '行 2：批量编辑｜复制哈希｜复制磁力链');
      expect(y7, closeTo(y5, 0.6));
      expect(y5, greaterThan(y1), reason: '共两行（第 2 行在第 1 行下方）');
    });
  });

  group('第 71 轮 · ⑥ 详情页六按钮固定两行 × 3 列', () {
    test('`_actionGrid` 就是两个 Row（不再用 Wrap）', () {
      expect(ovSrc.contains('Widget _actionGrid('), isTrue);
      final int i = ovSrc.indexOf('Widget _actionGrid(');
      final String body = ovSrc.substring(i, ovSrc.indexOf('/// 开关组', i));
      expect(body.contains('Wrap('), isFalse,
          reason: 'Wrap 的折行位置随字数/屏幕变，位置不固定');
      expect('Row('.allMatches(body).length, 2, reason: '固定两行');
      // 每行 3 格：3 个 primary/secondary + 2 个 gap
      expect(body.contains('Expanded('), isTrue);
      expect(ovSrc.contains('final bool wide'), isFalse);
    });

    testWidgets('渲染：6 个按钮排成两行 × 3 列', (WidgetTester tester) async {
      await pumpOverview(tester, server: qb());

      final double y1 = tester.getCenter(find.text('继续')).dy;
      final double y2 = tester.getCenter(find.text('暂停')).dy;
      final double y3 = tester.getCenter(find.text('重新校验')).dy;
      final double y4 = tester.getCenter(find.text('重新汇报')).dy;
      final double y5 = tester.getCenter(find.text(S.renameTorrent)).dy;
      final double y6 = tester.getCenter(find.text(S.delete)).dy;

      expect(y2, closeTo(y1, 0.6), reason: '行 1：继续｜暂停｜重新校验');
      expect(y3, closeTo(y1, 0.6));
      expect(y5, closeTo(y4, 0.6), reason: '行 2：重新汇报｜重命名｜删除');
      expect(y6, closeTo(y4, 0.6));
      expect(y4, greaterThan(y1), reason: '第二行在第一行下方');
    });
  });

  group('第 71 轮 · ⑧ 站点 / 哈希各占一行 + 复制', () {
    test('两处都改用 _kvCopy（带复制按钮），不再是两列网格', () {
      expect(ovSrc.contains('_kvCopy(S.fieldSiteName, site, maxLines: 2)'),
          isTrue);
      expect(ovSrc.contains('_kvCopy(S.fieldHash, t.hash, maxLines: 2)'),
          isTrue);
      // 旧的「站点 + 哈希」两列网格已拆
      expect(ovSrc.contains('<String>[S.fieldSiteName, site]'), isFalse);
      expect(ovSrc.contains("<String>['哈希', t.hash]"), isFalse);
      // _kvCopy 支持 maxLines（超长值封顶，复制拿完整值）
      expect(ovSrc.contains('Widget _kvCopy(String k, String v'), isTrue);
      expect(ovSrc.contains('int? maxLines'), isTrue);
    });

    testWidgets('渲染：站点名称与哈希各占一行，且带复制按钮',
        (WidgetTester tester) async {
      await pumpOverview(tester, server: qb());

      expect(find.text(S.fieldSiteName), findsOneWidget);
      expect(find.text(S.fieldHash), findsOneWidget);
      final double ySite = tester.getCenter(find.text(S.fieldSiteName)).dy;
      final double yHash = tester.getCenter(find.text(S.fieldHash)).dy;
      expect(yHash, greaterThan(ySite),
          reason: '哈希在站点名称**下一行**（用户要求各独占一行）');

      // 复制按钮：标题 1 + 站点 1 + 哈希 1 + 磁力链 1 + 注释 1 ⇒ ≥5
      expect(find.byIcon(Icons.copy), findsAtLeastNWidgets(5));
    });
  });
}
