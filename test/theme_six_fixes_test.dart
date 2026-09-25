import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/page_style.dart';
import 'package:torrent_manager/app/routes.dart';
import 'package:torrent_manager/app/theme.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
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
  });

  ThemeController newTc() => Get.put(ThemeController());

  group('第 5 条：统一参数模板 + 玻璃参数化', () {
    test('★ 壁纸六套顺序 = 零 → 壹 → 贰 → 叁 → 肆 → 伍（改名 + 重排）', () {
      expect(
        wallpaperPresets.map((ThemePreset p) => p.name).toList(),
        <String>[
          '零 · 幽魂',
          '壹 · 紫焰',
          '贰 · 雨夜',
          '叁 · 金辉',
          '肆 · 青灯',
          '伍 · 绯霓',
        ],
        reason: '「壳中魂」改名为「零 · 幽魂」并补序号，其余五套按中文大写排序',
      );
    });

    test('★ 玻璃是参数：壁纸套 true / 浅色套与内置档 false', () {
      for (final ThemePreset p in wallpaperPresets) {
        expect(p.glass, isTrue, reason: '${p.name} 应在基础参数上叠加透明玻璃');
      }
      for (final ThemePreset p in lightPresets) {
        expect(p.glass, isFalse, reason: '${p.name} 不含玻璃');
      }
      expect(builtinLight.glass, isFalse);
      expect(builtinLight.builtin, isTrue);
      expect(builtinDark.builtin, isTrue);
      expect(builtinDark.themeMode, 2);
    });

    test('★ glassAlpha 由 glassEnabled 驱动（不再看 _isWallpaperPreset）', () {
      final ThemeController tc = newTc();

      tc.applyPreset(wallpaperPresets.first);
      expect(tc.glassEnabled, isTrue);
      expect(tc.glassAlpha, greaterThan(0), reason: '壁纸套 → 玻璃开启');

      tc.applyPreset(lightPresets.first);
      expect(tc.glassEnabled, isFalse);
      expect(tc.glassAlpha, isNull, reason: '浅色套 → 玻璃关闭');

      tc.setGlassEnabled(true);
      expect(tc.glassAlpha, greaterThan(0));
      tc.setGlassEnabled(false);
      expect(tc.glassAlpha, isNull);
    });

    test('★ 内置档走同一入口，且不占精选主题勾选位', () {
      final ThemeController tc = newTc();

      tc.applyPreset(lightPresets.first);
      expect(tc.currentPreset.value, isNotNull);

      tc.applyBuiltinMode(1);
      expect(tc.currentPreset.value, isNull,
          reason: '内置档不能占 currentPreset，否则抽屉勾选会从「明亮模式」跳走');
      expect(tc.isBuiltinMode(1), isTrue);
      expect(tc.themeMode.value, 1);
      expect(tc.glassEnabled, isFalse);

      tc.applyBuiltinMode(2);
      expect(tc.isBuiltinMode(2), isTrue);
      expect(tc.themeMode.value, 2);
    });
  });

  group('第 2 条：自定义主题勾选', () {
    test('★ 先套精选主题 → 再进自定义主题 → 勾选落在「自定义主题」', () {
      final ThemeController tc = newTc();

      tc.applyPreset(wallpaperPresets[1]);
      expect(tc.isCustomSelected, isFalse);

      tc.enterCustomTheme();
      expect(tc.currentPreset.value, isNull,
          reason: '必须清掉精选主题标记（否则勾会留在原来那套主题上）');
      expect(tc.isCustomSelected, isTrue, reason: '抽屉勾选要落在「自定义主题」那一行');
    });

    test('★ 自定义主题的参数天然"克隆"当前主题（含玻璃）', () {
      final ThemeController tc = newTc();
      tc.applyPreset(wallpaperPresets[2]);
      final Color seedBefore = tc.seed.value;
      final bool glassBefore = tc.glassEnabled;

      tc.enterCustomTheme();
      expect(tc.seed.value, seedBefore, reason: '进自定义主题不该改动任何参数值');
      expect(tc.glassEnabled, glassBefore);
    });
  });

  group('第 3 条：全局背景图状态残留', () {
    test('★ 启用全局背景图 → 套用任何主题都必须复位', () {
      final ThemeController tc = newTc();

      tc.setGlobalBgImage('assets/images/drawer_menu_default.webp');
      tc.setGlobalBgEnabled(true);
      expect(tc.globalBgEnabled.value, isTrue);

      tc.applyPreset(lightPresets[2]);
      expect(tc.globalBgEnabled.value, isFalse,
          reason: '套精选主题必须关掉全局背景图（否则新主题被全局图整块盖住）');
      expect(tc.globalBgImagePath.value, isNull);
      expect(tc.globalBgDecorationImage, isNull);

      tc.setGlobalBgEnabled(true);
      tc.applyBuiltinMode(1);
      expect(tc.globalBgEnabled.value, isFalse);
    });
  });

  group('第 4 条：跟随系统已删除', () {
    test('★ applyBuiltinMode(0) 等价于明亮，不再存在 0 档', () {
      final ThemeController tc = newTc();
      tc.applyBuiltinMode(0);
      expect(tc.themeMode.value, 1, reason: '0 档已不存在，非法值一律按明亮处理');
      expect(tc.isBuiltinMode(1), isTrue);
      expect(tc.themeModeName, '明亮模式');
    });
  });

  group('第 1 条：菜单图（抽屉头图）', () {
    test('★ 切主题保留用户自选的菜单图；只有「恢复默认」才还原系统默认图', () {
      final ThemeController tc = newTc();
      const String mine = '/storage/emulated/0/Pictures/mine.jpg';

      tc.setMenuImage(mine);
      tc.applyPreset(lightPresets.first);
      expect(tc.menuImagePath.value, mine,
          reason: '换主题不该覆盖用户自选的菜单图（第 1 条"改了没用"的根因）');

      tc.applyPreset(wallpaperPresets.first);
      expect(tc.menuImagePath.value, mine);

      tc.restoreFactoryDefaults();
      expect(tc.menuImagePath.value, ThemeController.defaultMenuImage,
          reason: '「恢复默认」要还原成系统默认图');
    });

    test('★ imageProviderFor 覆盖 assets / content:// / 绝对路径三种形态', () {
      expect(ThemeController.imageProviderFor('assets/images/a.webp'),
          isA<AssetImage>());
      expect(ThemeController.imageProviderFor('content://media/external/images/1'),
          isA<FileImage>(),
          reason: 'Android SAF 可能返回 content://，直接 File(path) 会读不到');
      expect(ThemeController.imageProviderFor(r'C:\pics\a.jpg'), isA<FileImage>());
      expect(ThemeController.imageProviderFor('/sdcard/a.jpg'), isA<FileImage>());
    });

    test('★ 换菜单图 / 背景图都算「自定义主题」（抽屉勾选要跟过去）', () {
      final ThemeController tc = newTc();
      tc.applyPreset(lightPresets.first);
      tc.setMenuImage('/tmp/a.jpg');
      expect(tc.isCustomSelected, isTrue);
    });
  });

  group('第 6 / 4.1 条：图片型背景的可读性底衬（2026-09-19 收敛后的规则）', () {
    testWidgets('★ 未传 fixedScrim 的页面（种子 / 服务器 / 设置页）不压整页蒙层',
        (WidgetTester tester) async {
      final ThemeController tc = newTc();
      await tester.pumpWidget(const GetMaterialApp(home: AppPageBackground()));

      for (int i = 0; i < 6; i++) {
        await tester.pump();
      }
      expect(find.byKey(AppPageBackground.scrimKey), findsNothing,
          reason: '没有图片背景时不该凭空多一层蒙层');

      tc.setGlobalBgImage('assets/images/drawer_menu_default.webp');
      tc.setGlobalBgEnabled(true);
      await tester.pump();

      expect(find.byKey(AppPageBackground.scrimKey), findsNothing,
          reason: '有卡片底板的页面不该再压整页蒙层');
    });

    testWidgets('★ 传了 fixedScrim 的页面（主题页 / 日志页等）压固定 0.62',
        (WidgetTester tester) async {
      final ThemeController tc = newTc();
      await tester.pumpWidget(const GetMaterialApp(
        home: AppPageBackground(
          fixedScrim: AppPageBackground.fixedScrimValue,
        ),
      ));
      for (int i = 0; i < 6; i++) {
        await tester.pump();
      }
      expect(find.byKey(AppPageBackground.scrimKey), findsNothing,
          reason: '还没铺背景图时不该画蒙层');

      tc.setGlobalBgImage('assets/images/drawer_menu_default.webp');
      tc.setGlobalBgEnabled(true);
      await tester.pump();
      expect(find.byKey(AppPageBackground.scrimKey), findsOneWidget,
          reason: '正文裸铺在照片上的页面必须压底衬，否则根本认不出字');
    });

    testWidgets('★ 壁纸主题的页面背景（非全局图）同样受 fixedScrim 控制',
        (WidgetTester tester) async {
      final ThemeController tc = newTc();
      await tester.pumpWidget(const GetMaterialApp(
        home: AppPageBackground(
          fixedScrim: AppPageBackground.fixedScrimValue,
        ),
      ));
      for (int i = 0; i < 6; i++) {
        await tester.pump();
      }

      tc.applyPreset(wallpaperPresets.first);
      await tester.pump();
      expect(find.byKey(AppPageBackground.scrimKey), findsOneWidget,
          reason: '壁纸图同样会让无底板页面的文字不可读，必须一起压底衬');
    });
  });

  group('第 7 条：无卡片底板的页面 → 底衬固定 0.62', () {
    double scrimAlpha(WidgetTester tester) {
      final Finder f = find.byKey(AppPageBackground.scrimKey);
      if (f.evaluate().isEmpty) return -1;
      return tester.widget<ColoredBox>(f).color.a;
    }

    Future<void> withBgImage(WidgetTester tester, ThemeController tc) async {
      tc.setGlobalBgImage('assets/images/drawer_menu_default.webp');
      tc.setGlobalBgEnabled(true);
      await tester.pump();
    }

    testWidgets('★ 无底板页面：滑条拉到 0，底衬仍是 0.62',
        (WidgetTester tester) async {
      final ThemeController tc = newTc();
      await tester.pumpWidget(const GetMaterialApp(
        home: AppPageBackground(
          fixedScrim: AppPageBackground.fixedScrimValue,
        ),
      ));

      for (int i = 0; i < 6; i++) {
        await tester.pump();
      }
      await withBgImage(tester, tc);
      tc.setComponentOpacity(0);
      await tester.pump();
      expect(scrimAlpha(tester), closeTo(0.62, 0.001),
          reason: '主题页 / 日志页正文裸铺在背景图上，底衬被调没就整页看不清');
    });

    testWidgets('★ 无底板页面：滑条拉到 0.9 也不跟着变', (WidgetTester tester) async {
      final ThemeController tc = newTc();
      await tester.pumpWidget(const GetMaterialApp(
        home: AppPageBackground(
          fixedScrim: AppPageBackground.fixedScrimValue,
        ),
      ));
      for (int i = 0; i < 6; i++) {
        await tester.pump();
      }
      await withBgImage(tester, tc);
      tc.setComponentOpacity(0.9);
      await tester.pump();
      expect(scrimAlpha(tester), closeTo(0.62, 0.001));
    });

    testWidgets('★ 有卡片的页面：恒不压整页蒙层，透明度滑条只作用于组件底衬',
        (WidgetTester tester) async {
      final ThemeController tc = newTc();
      await tester.pumpWidget(const GetMaterialApp(home: AppPageBackground()));
      for (int i = 0; i < 6; i++) {
        await tester.pump();
      }
      await withBgImage(tester, tc);

      for (final double v in <double>[0.3, 0.0, 0.9]) {
        tc.setComponentOpacity(v);
        await tester.pump();
        expect(scrimAlpha(tester), -1,
            reason: '组件透明度不该再影响背景层 —— 那层整页底色正是被取消的东西');
      }
    });

    test('★ 路由接线：7 个无底板页面带 fixedScrim，3 个有卡片页面不带', () {
      const Map<String, bool> expectFixed = <String, bool>{
        Routes.theme: true,
        Routes.log: true,
        Routes.logQb: true,
        Routes.share: true,
        Routes.serverSetting: true,
        Routes.torrentAdd: true,
        Routes.torrentInfo: true,
        Routes.servers: false,
        Routes.torrents: false,
      };
      for (final MapEntry<String, bool> e in expectFixed.entries) {
        final GetPage<dynamic> g = AppPages.pages
            .firstWhere((GetPage<dynamic> p) => p.name == e.key);
        final AppPageTheme t = g.page() as AppPageTheme;
        expect(
            t.fixedScrim,
            e.value ? AppPageBackground.fixedScrimValue : null,
            reason: '${e.key} 的底衬接线不对');
      }
    });
  });
}
