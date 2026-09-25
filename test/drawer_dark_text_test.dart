import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/pages/drawer_page.dart';
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

  Future<ThemeController> pumpDark(WidgetTester tester) async {
    final ThemeController tc = Get.find<ThemeController>();
    tc.setThemeMode(2);
    await tester.pumpWidget(GetMaterialApp(
      home: const DrawerPage(),
      initialBinding: AppBinding(),
      theme: tc.lightTheme,
      darkTheme: tc.darkTheme,
      themeMode: ThemeMode.dark,
    ));
    await tester.pump(const Duration(milliseconds: 300));
    return tc;
  }

  Color textColorOf(WidgetTester tester, String text) {
    final Text w = tester.widget<Text>(find.text(text));

    return w.style?.color ??
        (throw TestFailure('「$text」没有显式字色，会继承被重置的默认主题'));
  }

  testWidgets('黑暗模式：分组标题与子项字色 = 生效字色（浅色）',
      (WidgetTester tester) async {
    final ThemeController tc = await pumpDark(tester);

    final Color base = tc.drawerFontColor;
    expect(base.computeLuminance(), greaterThan(0.5),
        reason: '★ 黑暗档抽屉底色是深色，生效字色必须是**浅色**');

    for (final String t in <String>[S.groupTheme]) {
      expect(textColorOf(tester, t), base, reason: '分组标题「$t」应为 100% 字色');
    }

    for (final String t in <String>[
      S.themeLight,
      S.themeDark,
      S.themeCustom,
      S.themePresetPinkCherry,
    ]) {
      final Color c = textColorOf(tester, t);
      expect(c, base.withValues(alpha: 0.87),
          reason: '子项「$t」应为 87% 字色（比分组标题低一档，但仍可读）');
      expect(c.computeLuminance(), greaterThan(0.5),
          reason: '「$t」在黑暗模式下必须是**浅色**字，否则压在深底上看不见');
    }
  });

  testWidgets('★ 抽屉字色与主题页「当前主题：」同源（不被局部 Theme 重置）',
      (WidgetTester tester) async {
    final ThemeController tc = await pumpDark(tester);

    final Color? inherited = tc.darkTheme.textTheme.bodyMedium?.color;
    expect(inherited, isNotNull);

    final Color base = tc.drawerFontColor;
    expect(textColorOf(tester, S.themeLight), base.withValues(alpha: 0.87),
        reason: '抽屉子项必须取自抽屉自己的字色，而不是被重置的主题默认色');
    expect(textColorOf(tester, S.groupTheme), base,
        reason: '分组标题也必须同源');
    expect(base.computeLuminance(), greaterThan(0.5));
  });

  testWidgets('未修复时会退化成 M3 默认深字（反证这条护栏有效）',
      (WidgetTester tester) async {
    final ThemeData reset = ThemeData(dividerColor: Colors.transparent);
    final Color? bad = reset.textTheme.bodyMedium?.color;
    expect(bad, isNotNull);
    expect(bad!.computeLuminance(), lessThan(0.5),
        reason: '默认 ThemeData 的字色是深色 —— 这正是暗色下看不见的成因');
  });
}
