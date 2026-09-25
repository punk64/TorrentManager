import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:torrent_manager/app/theme.dart';
import 'package:torrent_manager/controllers/locale_controller.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/pages/drawer_page.dart';
import 'package:torrent_manager/pages/log_page.dart';
import 'package:torrent_manager/pages/server_dialog.dart';
import 'package:torrent_manager/utils/app_log.dart';
import 'package:torrent_manager/utils/crypto_box.dart';
import 'package:torrent_manager/utils/net_error.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Get.reset();
    AppLog.instance.clear();
  });

  tearDown(() {
    Get.reset();
  });

  test('① 黑暗模式：抽屉底色为深色，字色反成浅色', () async {
    final ThemeController tc = Get.put(ThemeController());

    await Future<void>.delayed(const Duration(milliseconds: 300));
    tc.applyBuiltinMode(2);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final Color base = tc.drawerBaseColor;
    expect(base, AppTheme.darkDrawer,
        reason: '抽屉实际铺的底色与算字色用的底色必须是同一个值');
    expect(base.computeLuminance(), lessThan(0.179),
        reason: '底色必须是"暗"的，否则这条检查失去意义');

    final Color font = tc.drawerFontColor;
    expect(font.computeLuminance(), greaterThan(0.5),
        reason: '暗底抽屉的字色应当是浅色（用户报的正是白字压白底）');

    expect(tc.gradient1.computeLuminance(), lessThan(0.179));
    expect(tc.gradient2.computeLuminance(), lessThan(0.179));
  });

  test('① 明亮模式不回归：底色浅、字色深', () async {
    final ThemeController tc = Get.put(ThemeController());

    await Future<void>.delayed(const Duration(milliseconds: 300));
    tc.applyBuiltinMode(1);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(tc.drawerBaseColor, AppTheme.lightScaffold);
    expect(tc.drawerFontColor.computeLuminance(), lessThan(0.3));
  });

  testWidgets('① 黑暗模式下渲染出的 Drawer 有显式底色且为深色', (
    WidgetTester tester,
  ) async {
    final ThemeController tc = Get.put(ThemeController());
    Get.put(LocaleController());

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.of(AppTheme.seedColors.first, Brightness.light),
        darkTheme: AppTheme.of(AppTheme.seedColors.first, Brightness.dark),
        home: const Scaffold(body: AppDrawer()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    tc.applyBuiltinMode(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final Drawer drawer = tester.widget<Drawer>(find.byType(Drawer));
    expect(drawer.backgroundColor, isNotNull,
        reason: '纯色档必须显式给 Drawer 底色（留 null 会透出那层白色渐变）');
    final double lum = drawer.backgroundColor!.computeLuminance();
    expect(lum, lessThan(0.179),
        reason: '黑暗模式下抽屉底色必须是深色，实测 luminance=$lum');
  });

  testWidgets('② 「类型」下拉菜单项显式取 onSurface（浅色主题下为深色字）', (
    WidgetTester tester,
  ) async {
    Get.put(ThemeController());
    Get.put(LocaleController());

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.of(AppTheme.seedColors.first, Brightness.light),
        home: const Scaffold(body: _AutoOpenDialog()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('类型'), findsWidgets);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final Text item = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere((Text t) => t.data == 'transmission');
    expect(item.style?.color, isNotNull,
        reason: '菜单项必须显式给色 —— 不给色时 Overlay 里默认是浅色，'
            '浅色主题下就是白字压白底');
    expect(item.style!.color!.computeLuminance(), lessThan(0.5));
  });

  test('③ 用户目录不可写 → 自动回落到私有目录，且内容是本机加密信封', () async {
    final Directory tmp =
        Directory.systemTemp.createTempSync('tm_r34_fallback');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    final ServerController sc = Get.put(ServerController(
      qb: QbMethod(),
      tr: TrMethod(),
    ));
    sc.backupFallbackDirProvider = () async => tmp;

    sc.backupDir.value = 'bad${String.fromCharCode(0)}dir';

    sc.servers.add(ServerData(
      id: 'r34',
      name: '本地',
      type: 'qbittorrent',
      host: '127.0.0.1',
      port: 8080,
    ));

    final String path = await sc.saveBackup();
    expect(path, startsWith(tmp.path), reason: '写不动时必须回落到私有目录');
    expect(path, contains(ServerController.backupFileName));

    final String raw = File(path).readAsStringSync();
    expect(raw, isNot(contains('127.0.0.1')));
    expect(await CryptoBox.tryDecrypt(raw), isNotNull);

    final int added = await sc.restoreBackup();
    expect(added, greaterThanOrEqualTo(0));
    expect(sc.servers.where((ServerData s) => s.host == '127.0.0.1'),
        isNotEmpty,
        reason: '回落到私有目录的那份备份必须能被恢复读到');
  });

  const String kRealError =
      "PathAccessException: Cannot open file, path = "
      "'/storage/emulated/0/MyHarmonyOSDevice/Download/"
      "torrentmanager_backup.json' (OS Error: Permission denied, errno = 13)";

  test('④ 报错全文保留（旧上限 140 曾把它断在 Permiss…）', () {
    expect(kRealError.length, greaterThan(140),
        reason: '样例必须比旧上限长，否则测不出回归');

    final String des = NetError.describe(Exception(kRealError));
    expect(des, contains('Permission denied'));
    expect(des, contains('errno = 13'));
    expect(des, contains('Download'));
    expect(des, isNot(endsWith('…')));
  });

  test('④ 超长文本仍上限封顶（避免几百 KB 的日志条目）', () {
    final String des = NetError.describe(Exception('E' * 5000));
    expect(des.length, NetError.maxFallbackLength + 1);
    expect(des, endsWith('…'));
  });

  testWidgets('④ 列表行 3 行封顶，点开可看未截断的全文', (WidgetTester tester) async {
    Get.put(ThemeController());
    Get.put(LocaleController());
    Get.put(ServerController(qb: QbMethod(), tr: TrMethod()));

    AppLog.instance.error(kRealError);
    await tester.pumpWidget(const GetMaterialApp(home: LogPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final Text row =
        tester.widget<Text>(find.textContaining('PathAccessException'));
    expect(row.maxLines, 3);
    expect(row.overflow, TextOverflow.ellipsis);

    await tester.tap(find.textContaining('PathAccessException'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('复制全文'), findsOneWidget);
    final SelectableText detail =
        tester.widget<SelectableText>(find.byType(SelectableText));
    expect(detail.data, kRealError, reason: '详情里必须是未经截断的全文');
    expect(detail.maxLines, isNull);
  });
}

class _AutoOpenDialog extends StatefulWidget {
  const _AutoOpenDialog();

  @override
  State<_AutoOpenDialog> createState() => _AutoOpenDialogState();
}

class _AutoOpenDialogState extends State<_AutoOpenDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showServerDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
