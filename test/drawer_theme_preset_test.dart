import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/app/theme.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/main.dart';
import 'package:torrent_manager/pages/drawer_page.dart';
import 'package:torrent_manager/pages/theme_page.dart';
import 'package:torrent_manager/utils/strings.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall call) async => null);
    Get.testMode = true;
    Get.reset();
    Get.put(ThemeController(), permanent: true);
  });

  Future<void> pumpDrawer(WidgetTester tester) async {
    await tester.pumpWidget(GetMaterialApp(
      home: const DrawerPage(),
      initialBinding: AppBinding(),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('抽屉主题分组默认折叠，点「查看更多」展开全部', (WidgetTester tester) async {
    await pumpDrawer(tester);

    expect(find.text(S.groupTheme), findsOneWidget);

    expect(find.text(S.themePresets), findsNothing,
        reason: '需求 6：不再有「精选主题」分隔文本');
    expect(find.text(S.themeCustom), findsOneWidget,
        reason: '预设应跟在「自定义主题」条目之后');

    expect(find.text(presets[0].name), findsOneWidget);
    expect(find.text(presets[1].name), findsOneWidget);
    expect(find.text(presets[2].name), findsNothing,
        reason: '折叠态下第 3 套应收进「查看更多」');
    expect(find.text(S.themeShowMore), findsWidgets, reason: '应有「查看更多」入口');
    expect(find.text(S.themeShowLess), findsNothing,
        reason: '默认即折叠态，不该出现「收起」');

    final Finder showMore = find.text(S.themeShowMore).first;
    await tester.ensureVisible(showMore);
    await tester.pumpAndSettle();
    await tester.tap(showMore);
    await tester.pumpAndSettle();

    for (final ThemePreset p in lightPresets) {
      expect(find.text(p.name), findsOneWidget,
          reason: '展开后「${p.name}」应出现在抽屉里');
    }
    expect(find.text(S.themeShowLess), findsWidgets,
        reason: '展开后按钮应变为「收起」');
  });

  testWidgets('点按抽屉里的预设即套用（勾选同步）', (WidgetTester tester) async {
    await pumpDrawer(tester);
    final ThemeController tc = Get.find<ThemeController>();

    final Finder green = find.text(presets[1].name); 
    await tester.ensureVisible(green);
    await tester.pumpAndSettle();
    await tester.tap(green);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(tc.currentPreset.value, 'green_bamboo');
    expect(tc.themeMode.value, 1, reason: '六套均为浅色（明亮档）');
    expect(tc.seed.value, presets[1].seed);
  });

  testWidgets('★ 抽屉勾选跟随主题来源（三档 / 自定义主题 互斥）',
      (WidgetTester tester) async {
    await pumpDrawer(tester);
    final ThemeController tc = Get.find<ThemeController>();

    tc.applyBuiltinMode(2);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tc.isBuiltinMode(2), isTrue);

    tc.markCustomTheme();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tc.isCustomSelected, isTrue);
    expect(tc.isBuiltinMode(2), isFalse);
    expect(find.byIcon(Icons.check), findsOneWidget,
        reason: '同一时刻只能有一个勾');

    await tester.tap(find.text(S.themeLight));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tc.isBuiltinMode(1), isTrue);
    expect(tc.isCustomSelected, isFalse);
  });

  testWidgets('「恢复默认」把自定义主题的参数还原成默认值', (WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: ThemePage()));
    await tester.pump(const Duration(milliseconds: 300));
    final ThemeController tc = Get.find<ThemeController>();

    tc.applyPreset(presets.first);
    tc.setThemeMode(2); 
    await tester.pump();

    await tester.tap(find.text(S.restoreDefaults));
    await tester.pump();

    expect(tc.themeMode.value, 1, reason: '参数还原成默认参数（首启值：明亮）');
    expect(tc.bgModeValue, 0);
    expect(tc.seed.value, AppTheme.seedColors.first);
    expect(tc.currentPreset.value, isNull);

    expect(tc.useCustom.value, isTrue);
    expect(tc.isCustomSelected, isTrue);
    expect(tc.isBuiltinMode(1), isFalse);

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('★ 改背景后全局容器立即重建（不必重启）', (WidgetTester tester) async {
    final ThemeController tc = Get.find<ThemeController>();
    await tc.load();

    await tester.pumpWidget(const TorrentManagerApp());
    await tester.pump(const Duration(milliseconds: 300));

    bool hasGradient() => tester
        .widgetList<Container>(find.byType(Container))
        .any((Container c) =>
            c.decoration is BoxDecoration &&
            (c.decoration! as BoxDecoration).gradient != null);

    expect(hasGradient(), isFalse, reason: '默认纯色背景，不该有渐变容器');

    tc.applyPreset(presets.first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(hasGradient(), isTrue, reason: '套用渐变背景主题后应立即出现渐变容器');
  });

  testWidgets('主题页已移除「精选主题」栏目', (WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: ThemePage()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(S.themePresets), findsNothing,
        reason: '精选主题已搬到抽屉，主题页不应再出现该栏目');
    for (final ThemePreset p in presets) {
      if (p.builtin) continue;
      expect(find.text(p.name), findsNothing,
          reason: '主题页不应出现预设「${p.name}」');
    }

    expect(find.text(S.themeCustom), findsWidgets);
    expect(find.text(S.themeFontColor), findsOneWidget);

    expect(find.textContaining('背景背景模式'), findsNothing);

    expect(find.textContaining('背景选择'), findsNothing);

    expect(find.text(S.themeGlass), findsOneWidget,
        reason: '「透明玻璃面板」开关要移出折叠栏、常驻可点');
    expect(find.text(S.themeOpacity), findsOneWidget,
        reason: '「透明度」滑条要移到菜单图片上方');

    expect(find.textContaining(S.themeCurrentPrefix), findsNothing);
    expect(find.text(S.themeFollowSystem), findsNothing);
    expect(find.text(S.themeLight), findsNothing);
    expect(find.text(S.themeDark), findsNothing);
  });
}
