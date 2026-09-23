




import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('AppTheme.contrastOn（反色）', () {
    test('深底 → 浅色字', () {
      expect(AppTheme.contrastOn(const Color(0xFF1E1E1E)),
          const Color(0xFFE6E6E6));
      expect(AppTheme.contrastOn(const Color(0xFF282828)),
          const Color(0xFFE6E6E6));
      expect(AppTheme.contrastOn(Colors.black), const Color(0xFFE6E6E6));
    });

    test('浅底 → 深色字', () {
      expect(AppTheme.contrastOn(Colors.white), const Color(0xFF1A1A1A));
      expect(AppTheme.contrastOn(const Color(0xFFF5F5F5)),
          const Color(0xFF1A1A1A));
    });

    test('暗色三档（#1E1E1E / #282828 / #464646）全部取浅色字', () {
      for (final Color c in <Color>[
        AppTheme.darkBackground,
        AppTheme.darkSurface,
        AppTheme.darkSurfaceVariant,
      ]) {
        expect(AppTheme.contrastOn(c), const Color(0xFFE6E6E6),
            reason: '$c 应取浅色字');
      }
    });
  });

  group('ThemeController 生效字色', () {
    test('明亮模式 + 纯色背景 → 深色字', () async {
      final ThemeController tc = Get.put(ThemeController());
      await tc.load();
      tc.setThemeMode(1);
      expect(tc.effectiveFontColor, const Color(0xFF1A1A1A));
      
      expect(tc.theme.textTheme.bodyMedium?.color, const Color(0xFF1A1A1A));
    });

    test('黑暗模式 + 纯色背景 → 浅色字（反色生效）', () async {
      final ThemeController tc = Get.put(ThemeController());
      await tc.load();
      tc.setThemeMode(2);
      expect(tc.effectiveFontColor, const Color(0xFFE6E6E6));
      expect(tc.darkTheme.textTheme.bodyMedium?.color,
          const Color(0xFFE6E6E6));
    });

    test('★ 明亮档位但背景是深色渐变 → 仍取浅色字（本次修复的核心）', () async {
      final ThemeController tc = Get.put(ThemeController());
      await tc.load();
      
      
      
      const ThemePreset darkGradient = ThemePreset(
        id: 'test_dark_gradient',
        name: '深色渐变（测试用）',
        descriptor: '',
        themeMode: 1,
        seed: Color(0xFF1565C0),
        bgMode: 1,
        gradient1: Color(0xFF101010),
        gradient2: Color(0xFF202020),
      );
      tc.applySpec(darkGradient);

      expect(tc.themeMode.value, 1, reason: '主题档位仍是「明亮模式」');
      expect(tc.effectiveBackgroundColor, isNotNull);
      expect(tc.effectiveFontColor, const Color(0xFFE6E6E6),
          reason: '背景是深色渐变时，即便主题档位是明亮也必须反色成浅色字');
    });

    test('图片背景：字色回落到按明暗档的默认值（调亮/调暗滑条已删除）', () async {
      final ThemeController tc = Get.put(ThemeController());
      await tc.load();
      
      
      
      
      tc.applyPreset(wallpaperPresets.first);
      expect(tc.effectiveBackgroundColor, isNull, reason: '图片色彩无从推断');
      expect(tc.effectiveFontColor, const Color(0xFF1A1A1A));
      expect(tc.glassAlpha, greaterThan(0),
          reason: '壁纸套默认开玻璃，组件是半透明白，近黑字仍有足够对比度');
    });

    test('手动指定字色优先于反色，且可恢复', () async {
      final ThemeController tc = Get.put(ThemeController());
      await tc.load();
      tc.setThemeMode(2);
      tc.setFontColor(const Color(0xFFFF0000));
      expect(tc.effectiveFontColor, const Color(0xFFFF0000));
      expect(tc.isFontColorCustom, true);

      tc.setFontColor(null);
      expect(tc.isFontColorCustom, false);
      expect(tc.effectiveFontColor, const Color(0xFFE6E6E6));
    });

    test('图标色跟随字色一起反色（否则字变白了图标还是黑的）', () async {
      final ThemeController tc = Get.put(ThemeController());
      await tc.load();
      tc.setThemeMode(2);
      expect(tc.darkTheme.iconTheme.color, const Color(0xFFE6E6E6));
    });
  });

  group('★ 页面底色：明亮 = 纯白黑字，黑暗 = 纯黑白字', () {
    
    test('明亮模式：scaffold 纯白 + 正文近黑', () async {
      final ThemeController tc = Get.put(ThemeController());
      await tc.load();
      tc.setThemeMode(1);
      expect(tc.lightTheme.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      expect(tc.lightTheme.textTheme.bodyMedium?.color,
          const Color(0xFF1A1A1A));
      
      expect(tc.effectiveBackgroundColor, const Color(0xFFFFFFFF));
    });

    test('黑暗模式：scaffold 纯黑 + 正文近白', () async {
      final ThemeController tc = Get.put(ThemeController());
      await tc.load();
      tc.setThemeMode(2);
      expect(tc.darkTheme.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(tc.darkTheme.textTheme.bodyMedium?.color,
          const Color(0xFFE6E6E6));
      expect(tc.effectiveBackgroundColor, const Color(0xFF000000));
    });

    test('纯黑 / 纯白底色下反色仍成立（对比度不塌）', () {
      expect(AppTheme.contrastOn(AppTheme.darkScaffold),
          const Color(0xFFE6E6E6));
      expect(AppTheme.contrastOn(AppTheme.lightScaffold),
          const Color(0xFF1A1A1A));
      expect(AppTheme.darkBackground, const Color(0xFF1E1E1E));
      expect(AppTheme.darkSurface, const Color(0xFF282828));
    });
  });
}
