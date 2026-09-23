import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/theme.dart';
import 'package:torrent_manager/controllers/locale_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/pages/drawer_page.dart';
import 'package:torrent_manager/utils/formatter.dart';
import 'package:torrent_manager/utils/i18n.dart';
import 'package:torrent_manager/utils/strings.dart';

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

    L.code.value = '';

    LocaleController.updateSystemLocale = false;
  });

  group('★ ① 标题栏 / 弹窗 / 菜单 / 抽屉 —— 底色必须跟随主题', () {
    test('四处的背景色都不是 null，且六套预设各不相同', () {
      final ThemeController tc = Get.put(ThemeController());
      final List<ThemeData> ts = <ThemeData>[];
      for (final ThemePreset p in lightPresets) {
        tc.applyPreset(p);
        ts.add(tc.lightTheme);
      }

      for (int i = 0; i < ts.length; i++) {
        final ThemeData t = ts[i];
        final String n = lightPresets[i].name;

        expect(t.appBarTheme.backgroundColor, isNotNull,
            reason: '$n：标题栏底色缺失 → 切主题时标题栏不变色');
        expect(t.dialogTheme.backgroundColor, isNotNull,
            reason: '$n：弹窗底色缺失 → 切主题时弹窗不变色');
        expect(t.drawerTheme.backgroundColor, isNotNull,
            reason: '$n：抽屉底色缺失 → 切主题时抽屉不变色');
        expect(t.popupMenuTheme.color, isNotNull,
            reason: '$n：弹出菜单底色缺失 → 切主题时菜单不变色');

        expect(t.appBarTheme.backgroundColor,
            isNot(t.scaffoldBackgroundColor),
            reason: '$n：标题栏应与页面底色有区分');
      }

      expect(
        ts.map((ThemeData t) => t.appBarTheme.backgroundColor).toSet().length,
        6,
        reason: '六套主题的标题栏底色应各不相同',
      );
      expect(
        ts.map((ThemeData t) => t.dialogTheme.backgroundColor).toSet().length,
        6,
        reason: '六套主题的弹窗底色应各不相同',
      );
      expect(
        ts.map((ThemeData t) => t.drawerTheme.backgroundColor).toSet().length,
        6,
        reason: '六套主题的抽屉底色应各不相同',
      );
    });

    test('★ 深色端仍保证近黑字可读（加深不能加深到看不清）', () {
      final ThemeController tc = Get.put(ThemeController());
      for (final ThemePreset p in lightPresets) {
        tc.applyPreset(p);
        final ThemeData t = tc.lightTheme;

        for (final Color? bg in <Color?>[
          t.appBarTheme.backgroundColor,
          t.dialogTheme.backgroundColor,
          t.drawerTheme.backgroundColor,
        ]) {
          expect(AppTheme.contrastOn(bg!), const Color(0xFF1A1A1A),
              reason: '${p.name}：底色 $bg 上应使用近黑字');
        }
      }
    });
  });

  group('★ ② 语言：抽屉入口的位置与切换', () {
    testWidgets('「语言」分组排在「分享与导出」之上', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(340 * 2, 1400 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      Get.put(ThemeController(), permanent: true);
      Get.put(LocaleController(), permanent: true);

      await tester.pumpWidget(const GetMaterialApp(
        home: Scaffold(body: SafeArea(child: DrawerMenu())),
      ));
      await tester.pump();

      final double langY = tester.getTopLeft(find.text(S.langTitle)).dy;
      final double shareY = tester.getTopLeft(find.text(S.groupShare)).dy;
      expect(langY, lessThan(shareY),
          reason: '语言必须在分享与导出**上方**（用户明确要求的位置）');
    });

    testWidgets('点「语言」→ 弹两项 → 选 English → 全站文案变英文并落盘',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(340 * 2, 1400 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      Get.put(ThemeController(), permanent: true);
      final LocaleController lc = Get.put(LocaleController(), permanent: true);

      await tester.pumpWidget(const GetMaterialApp(
        home: Scaffold(body: SafeArea(child: DrawerMenu())),
      ));
      await tester.pump();

      expect(find.text(S.groupShare), findsWidgets);

      await tester.tap(find.text(S.langZh));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(S.langZh), findsWidgets);
      expect(find.text(S.langEn), findsOneWidget);

      await lc.setLang(L.en);
      await tester.pump();

      expect(L.current, L.en, reason: '选中 English 后语言层应切到 en');
      expect(lc.currentName, S.langEn);

      expect(find.text('Share & export'), findsWidgets,
          reason: '切完语言后抽屉应整体重建为英文');

      expect(await Formatter.getGlobalData(LocaleController.kLang), L.en);
    });

    testWidgets('未选过语言时按系统语言判定；选过之后系统语言不再覆盖',
        (WidgetTester tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
      final LocaleController lc = Get.put(LocaleController());

      await tester.pump();

      expect(L.code.value, isEmpty);
      await lc.load();
      expect(L.code.value, isEmpty,
          reason: 'load() 不应把系统语言固化成落盘值，否则换系统语言就跟不上了');
      expect(L.current, isIn(<String>[L.zh, L.en]));

      await lc.setLang(L.en);
      expect(L.code.value, L.en);
      expect(await Formatter.getGlobalData(LocaleController.kLang), L.en);
      expect(lc.isPinned, isTrue);
    });
  });
}
