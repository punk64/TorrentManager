import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/pages/torrent_info_overview_page.dart';
import 'package:torrent_manager/utils/strings.dart';
import 'package:torrent_manager/widgets/torrent_edit_fields.dart';

/// 第 69 轮：概览 Tab **紧凑布局 v3 补做**（2026-09-24 17:30 拍板、此前漏做）。
///
/// v3 三条排布规则：只读短值两列网格 / 长内容独占一行 / 可编辑 4 项 2×2 + 开关同一行 chip。
/// 外加审查台账 **B3**：窄屏与大字体必须回退单列。
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

ServerData _qb() => ServerData(
      id: 'qb',
      name: 'qb',
      type: 'qbittorrent',
      host: '1.2.3.4',
      port: 8080,
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

  Future<void> pump(
    WidgetTester tester, {
    double width = 400,
    ServerData? server,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GetMaterialApp(
      initialBinding: AppBinding(),
      home: const Scaffold(body: TorrentInfoOverviewPage()),
    ));
    if (server != null) {
      Get.find<ServerController>().current.value = server;
    }
    Get.find<TorrentController>().current.value = t;
    await tester.pump();
  }

  group('第 69 轮 · v3 紧凑布局（源码结构）', () {
    final String src =
        File('lib/pages/torrent_info_overview_page.dart').readAsStringSync();
    final String ef =
        File('lib/widgets/torrent_edit_fields.dart').readAsStringSync();

    test('两列网格骨架齐备（共享组件 ReadonlyKvGrid/EditLayout）', () {
      // ★ 第 70 轮起：v3 的判据与两列排布**抽成共享组件**（概览 Tab 与卡片展开区共用），
      //   所以这几条断言从"本页私有方法"改指组件。
      expect(ef.contains('class ReadonlyKvGrid'), isTrue);
      expect(ef.contains('static bool gridOkOf('), isTrue);
      expect(src.contains('ReadonlyKvGrid(pairs:'), isTrue);
      // ★ 2026-09-24 用户整改：2×2 撤回 ⇒ 本页 `_editGrid` 已拆除，
      //   改由分区卡片（EditSectionCard）直排 4 个整行。
      expect(src.contains('Widget _editGrid('), isFalse,
          reason: '4 项改回独占一行后不再需要 2×2 装配方法');
      expect(ef.contains('class EditSectionCard'), isTrue,
          reason: '每栏目边界感靠分区卡片');
    });

    test('★ B3：窄屏 / 大字体回退单列有判据（宽 <360dp 或缩放 >1.15）', () {
      final int i = ef.indexOf('static bool gridOkOf(');
      final String body = ef.substring(i, i + 200);
      expect(body.contains('>= 360'), isTrue);
      expect(body.contains('1.15'), isTrue);
      // 回退分支必须真的走整行，否则判据是摆设（现在在共享组件里）。
      expect(ef.contains('if (!EditLayout.gridOkOf(context))'), isTrue);
      expect(ef.contains('fullCell(p[0], p[1])'), isTrue);
    });

    test('旧的单列 _remainingRow 已拆除（剩余量并入组①、元数据进条件块）', () {
      // 断言"方法定义没了"而不是"字里没有这个词" —— 注释里保留新旧对照是好事。
      expect(src.contains('_remainingRow(Torrent'), isFalse,
          reason: 'v3：剩余量移进组①两列网格、元数据进度移进末尾条件块');
      expect(src.contains('bool _metaIncomplete('), isTrue);
      expect(src.contains('S.fieldRemaining'), isTrue,
          reason: '剩余量必须在（只是换了位置，不能顺手丢掉）');
    });

    test('★ 开关组上移到操作按钮下方（_switchGroup 出现在组①网格之前）', () {
      final int sw = src.indexOf('_switchGroup(t)');
      final int grid = src.indexOf('ReadonlyKvGrid(pairs: <List<String>>[');
      expect(sw, greaterThan(0));
      expect(grid, greaterThan(0));
      expect(sw, lessThan(grid),
          reason: 'v3 最终顺序：操作按钮 Wrap → 开关组 → 参数区');
    });

    test('★ 开关压成同一行 chip（EditSwitchChip + Wrap），不再用整行 EditSwitchRow', () {
      expect(src.contains('EditSwitchChip('), isTrue);
      expect(src.contains('EditSwitchRow('), isFalse,
          reason: 'v3 排布规则第 4 条：4 个开关压成同一行');
      expect(ef.contains('class EditSwitchChip'), isTrue);

      // ★ v3 实现要点 1：必须 SizedBox + FittedBox ——
      //   Transform.scale 只缩视觉不缩布局，Switch 布局宽仍约 59dp 会挤爆文字。
      final int i = ef.indexOf('class EditSwitchChip');
      final String chip = ef.substring(i, ef.indexOf('/// B 类 · 只读值'));
      expect(chip.contains('FittedBox'), isTrue);
      expect(chip.contains('Transform.scale'), isFalse);
      expect(chip.contains('width: 26'), isTrue);
      expect(chip.contains('height: 15'), isTrue);
    });

    test('★ 可编辑 4 项**各独占一行**（2026-09-24 用户整改：撤回 2×2）', () {
      // 组件层仍保留 compact 能力（将来可能复用），但本页**不再传 compact**。
      expect(ef.contains('this.compact = false'), isTrue);
      expect(src.contains('_dlLimitField(t, compact: true)'), isFalse);
      expect(src.contains('_upLimitField(t, compact: true)'), isFalse);
      expect(src.contains('_ratioLimitField(t, compact: true)'), isFalse);
      expect(src.contains('_seedTimeField(t, compact: true)'), isFalse);
      // 顺序：下载限速 / 上传限速 / 分享率上限 / 做种时限（各项独占一行）。
      final int dl = src.indexOf('_dlLimitField(t)');
      final int up = src.indexOf('_upLimitField(t)');
      final int ratio = src.indexOf('_ratioLimitField(t)');
      final int seed = src.indexOf('_seedTimeField(t)');
      expect(dl, greaterThan(0));
      expect(up, greaterThan(dl));
      expect(ratio, greaterThan(up));
      expect(seed, greaterThan(ratio));
      // 独行后 label 有 88dp ⇒ 用**完整文案**「分享率上限」（用户口径），不再用短文案。
      expect(src.contains('label: S.fieldRatioLimit,'), isTrue);
    });

    test('两列网格用的是短标签（半格 50dp 放不下长文案）', () {
      expect(src.contains('S.fieldWastedShort'), isTrue);
      expect(src.contains('S.fieldTrackerShort'), isTrue);
      final String st = File('lib/utils/strings.dart').readAsStringSync();
      expect(st.contains("fieldWastedShort => L.pick('损坏/浪费'"), isTrue);
      expect(st.contains("fieldTrackerShort => L.pick('Tracker'"), isTrue);
      expect(st.contains("fieldRatioLimitShort => L.pick('分享上限'"), isTrue);
    });

    test('★ 组③末尾有导出种子入口（v3 第 10 条）+ 条件块落在末尾（第 11 条）', () {
      expect(src.contains('Future<void> _exportTorrent('), isTrue);
      expect(src.contains('_exportTorrent(t)'), isTrue);

      final int magnet = src.indexOf('S.fieldMagnet, t.magnetUri!');
      final int err = src.indexOf('_errorBanner(t, cs)');
      final int meta = src.indexOf('_metadataBar(t)');
      expect(magnet, greaterThan(0));
      expect(err, greaterThan(magnet),
          reason: 'v3：错误红条挪到组③之后的末尾条件块（原来在名称下方）');
      expect(meta, greaterThan(err), reason: '条件块②：元数据进度在错误红条之后');
    });

    test('导出仍然按能力显隐（V3：TR 无接口、qB 要 4.5+）', () {
      expect(src.contains('_ctrl.capabilities.exportTorrent'), isTrue);
    });
  });

  group('第 69 轮 · v3 紧凑布局（渲染）', () {
    testWidgets('★ 宽屏（400dp）：只读参数两列并排', (WidgetTester tester) async {
      await pump(tester, width: 400);

      final double yState = tester.getCenter(find.text(S.fieldState)).dy;
      final double yCheck = tester.getCenter(find.text('校验进度')).dy;
      final double ySize = tester.getCenter(find.text(S.fieldSize)).dy;
      final double yRatio = tester.getCenter(find.text(S.fieldRatio)).dy;

      expect(yCheck, closeTo(yState, 0.6), reason: '状态｜校验进度 = 同一行');
      expect(yRatio, closeTo(ySize, 0.6), reason: '大小｜分享率 = 同一行');
      expect(ySize, greaterThan(yCheck), reason: '第二行必须在第一行下面');
    });

    testWidgets('★ 窄屏（320dp）：回退单列（B3）', (WidgetTester tester) async {
      await pump(tester, width: 320);

      final double yState = tester.getCenter(find.text(S.fieldState)).dy;
      final double yCheck = tester.getCenter(find.text('校验进度')).dy;
      expect(yState, lessThan(yCheck),
          reason: 'B3：窄屏回退单列 ⇒ 每项独占一行，不再并排');
    });

    testWidgets('★ qB：4 个开关 chip 同一行，且紧跟操作按钮下方',
        (WidgetTester tester) async {
      await pump(tester, width: 400, server: _qb());

      expect(find.byType(EditSwitchChip), findsNWidgets(4),
          reason: 'qB 支持 强制做种 / 顺序下载 / 首尾块优先 / 超级做种');

      final double y1 = tester.getCenter(find.text(S.swForceStart)).dy;
      final double y2 = tester.getCenter(find.text(S.swSequential)).dy;
      final double y3 = tester.getCenter(find.text(S.swFirstLast)).dy;
      final double y4 = tester.getCenter(find.text(S.swSuperSeeding)).dy;
      expect(y2, closeTo(y1, 0.6), reason: 'v3：4 个开关在**同一行**');
      expect(y3, closeTo(y1, 0.6));
      expect(y4, closeTo(y1, 0.6));

      final double opY = tester.getCenter(find.text('继续')).dy;
      expect(y1, greaterThan(opY), reason: 'v3：开关组在操作按钮正下方');
    });

    testWidgets('★ qB：可编辑 4 项各独占一行（2026-09-24 用户整改）',
        (WidgetTester tester) async {
      await pump(tester, width: 400, server: _qb());

      final double yDl = tester.getCenter(find.text(S.fieldDlLimit)).dy;
      final double yUp = tester.getCenter(find.text(S.fieldUpLimit)).dy;
      final double yRatio = tester.getCenter(find.text(S.fieldRatioLimit)).dy;
      final double ySeed =
          tester.getCenter(find.text(S.fieldSeedingTimeLimit)).dy;

      expect(yUp, greaterThan(yDl), reason: '下载限速独占一行');
      expect(yRatio, greaterThan(yUp), reason: '上传限速独占一行');
      expect(ySeed, greaterThan(yRatio), reason: '分享率上限独占一行');
      // ★ 独行后 label 恢复完整文案（用户口径「文本以这个为准」）。
      expect(find.text(S.fieldRatioLimitShort), findsNothing);
    });

    testWidgets('窄屏：可编辑 4 项同样是 4 行（不再有 2×2 可回退）',
        (WidgetTester tester) async {
      await pump(tester, width: 320, server: _qb());

      final double yDl = tester.getCenter(find.text(S.fieldDlLimit)).dy;
      final double yUp = tester.getCenter(find.text(S.fieldUpLimit)).dy;
      expect(yDl, lessThan(yUp), reason: 'B3：回退单列后不再并排');
    });
  });
}
