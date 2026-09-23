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

  group('presets 数据完整性', () {
    test('12 套预设参数均合理（浅色 6 + 壁纸 6）', () {
      expect(presets.length, 12, reason: '2026-09-18 新增六套壁纸主题');
      expect(lightPresets.length, 6);
      expect(wallpaperPresets.length, 6);
      for (final ThemePreset p in presets) {
        expect(p.themeMode, isIn(<int>[0, 1, 2]));
        expect(p.bgMode, isIn(<int>[1, 2]));
        expect(p.gradient1, isA<Color>());
        expect(p.gradient2, isA<Color>());
        expect(p.seed, isA<Color>());
      }
    });

    test('★ 浅色六套：起点浅 / 终点明显加深 / 字色近黑（2026-09-20 改口径）', () {
      for (final ThemePreset p in lightPresets) {
        expect(p.themeMode, 1, reason: '${p.name} 应为明亮档');
        expect(p.bgMode, 1, reason: '${p.name} 走渐变背景');
        expect(p.bgImage, isNull, reason: '浅色套不带壁纸');
        expect(p.wallpaper, isFalse);
        final double l1 = p.gradient1.computeLuminance();
        final double l2 = p.gradient2.computeLuminance();
        expect(l1, greaterThan(0.78), reason: '${p.name} 渐变起点应偏浅');
        expect(l1, lessThan(0.95), reason: '${p.name} 起点避开纯白');
        expect(l2, greaterThan(0.50),
            reason: '${p.name} 终点要够深 —— 色感可辨（旧口径 0.70 太浅）');
        expect(l2, lessThan(0.70),
            reason: '${p.name} 终点也不能深到像暗色主题');
        expect(l1 - l2, greaterThan(0.15),
            reason: '${p.name} 渐变幅度要看得出来（用户：几乎分辨不出风格）');
        expect(l1 - l2, lessThan(0.35), reason: '${p.name} 渐变别过猛');

        expect(AppTheme.contrastOn(p.gradient2), const Color(0xFF1A1A1A),
            reason: '${p.name} 深色端也要保证近黑字可读');
      }
      expect(AppTheme.contrastOn(ThemeController.defaultPanelColor),
          const Color(0xFF1A1A1A),
          reason: '面板是浅色，文字应为近黑');
    });

    test('★ 壁纸六套：图片背景 + 自带壁纸资产', () {
      for (final ThemePreset p in wallpaperPresets) {
        expect(p.wallpaper, isTrue, reason: '${p.name} 应标记为壁纸主题');
        expect(p.themeMode, 1,
            reason: '${p.name} 走明亮档（近黑文字压在亮色玻璃卡片上）');
        expect(p.bgMode, 2, reason: '${p.name} 背景模式应为「图片」');
        expect(p.bgImage, isNotNull, reason: '${p.name} 必须自带壁纸');
        expect(p.bgImage!.startsWith('assets/images/wallpapers/'), isTrue,
            reason: '${p.name} 壁纸应放在 assets/images/wallpapers/ 下');

        expect(ThemeController.bundledAssets.contains(p.bgImage), isTrue,
            reason: '${p.name} 的壁纸不在 bundledAssets 里');
      }
    });

    test('预设 id 唯一', () {
      final List<String> ids = presets.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('preview：浅色套走渐变，壁纸套走缩略图', () {
      for (final ThemePreset p in lightPresets) {
        final BoxDecoration deco = p.preview;
        expect(deco.gradient, isA<LinearGradient>());
        final LinearGradient g = deco.gradient! as LinearGradient;
        expect(g.colors.first, p.gradient1);
        expect(g.colors.last, p.gradient2);
        expect(deco.image, isNull);
      }
      for (final ThemePreset p in wallpaperPresets) {
        final BoxDecoration deco = p.preview;
        expect(deco.image, isNotNull, reason: '${p.name} 预览应是壁纸缩略图');
        expect(deco.image!.image, isA<AssetImage>());
        expect(deco.gradient, isNull);
      }
    });
  });

  group('★ 壁纸主题：套用 / 亮色玻璃 / 资产路径迁移', () {
    ThemeController makeTc() => Get.put(ThemeController());

    test('套用壁纸主题 → 图片背景 + 该壁纸落盘 + 玻璃生效', () {
      final ThemeController tc = makeTc();
      final ThemePreset wp = wallpaperPresets.first;
      tc.applyPreset(wp);

      expect(tc.currentPreset.value, wp.id);
      expect(tc.bgModeValue, 2, reason: '套用后应整页铺壁纸');
      expect(tc.pageBgImage, wp.bgImage);
      expect(tc.themeMode.value, 1);
      expect(tc.glassAlpha, greaterThan(0),
          reason: '图片背景 → 卡片应是半透明亮色玻璃');

      expect(tc.effectiveFontColor, const Color(0xFF1A1A1A));
    });

    test('套用浅色主题 → 玻璃关闭（观感与以前完全一致）', () {
      final ThemeController tc = makeTc();
      tc.applyPreset(lightPresets.first);

      expect(tc.glassAlpha, isNull, reason: '纯色 / 渐变背景不该出现半透明卡片');
      expect(tc.bgModeValue, 1);
    });

    test('★ 旧默认图路径失效 → 判为不可用（否则背景是一片空白）', () {
      const String legacy = 'assets/images/drawer_background.webp';
      expect(ThemeController.aliveAsset(legacy), isNull,
          reason: '已删除的资产必须被判为失效');
      expect(ThemeController.aliveAsset(ThemeController.defaultMenuImage),
          ThemeController.defaultMenuImage);
      expect(ThemeController.aliveAsset(wallpaperPresets.first.bgImage),
          wallpaperPresets.first.bgImage);

      expect(ThemeController.aliveAsset('/storage/emulated/0/a.png'),
          '/storage/emulated/0/a.png');
      expect(ThemeController.aliveAsset(null), isNull);
    });

    test('六套壁纸各自对应一张不同的资产（不能写重）', () {
      final Set<String?> imgs =
          wallpaperPresets.map((ThemePreset p) => p.bgImage).toSet();
      expect(imgs.length, 6);
    });
  });

  group('applyPreset 套用', () {
    ThemeController makeTc() => Get.put(ThemeController());

    test('粉樱：浅粉 + 小幅度渐变 + 字色近黑', () {
      final ThemeController tc = makeTc();
      tc.applyPreset(presets[0]);
      expect(tc.currentPreset.value, 'snow_plum');
      expect(tc.themeMode.value, 1);
      expect(tc.seed.value, const Color(0xFFC2185B));
      expect(tc.bgModeValue, 1);

      expect(tc.gradient2, const Color(0xFFF5B9CE));

      expect(tc.panelColor.value, ThemeController.defaultPanelColor);
      expect(tc.fontColor.value, isNull);

      expect(tc.effectiveFontColor, const Color(0xFF1A1A1A));
    });

    test('青筠：浅绿 + 字色近黑', () {
      final ThemeController tc = makeTc();
      tc.applyPreset(presets[1]);
      expect(tc.currentPreset.value, 'green_bamboo');
      expect(tc.themeMode.value, 1);
      expect(tc.seed.value, const Color(0xFF2E7D32));
      expect(tc.bgModeValue, 1);

      for (final Color c in <Color>[tc.gradient1, tc.gradient2]) {
        expect(c.g, greaterThan(c.r), reason: '$c 应偏绿');
      }
      expect(tc.effectiveFontColor, const Color(0xFF1A1A1A));
    });

    test('紫霞：浅紫（承接原「紫色心情」的 id）+ 字色近黑', () {
      final ThemeController tc = makeTc();
      tc.applyPreset(presets[4]);
      expect(tc.currentPreset.value, 'purple_mood', reason: '历史 id 保持不变，兼容已落盘的选中状态');
      expect(tc.themeMode.value, 1);
      expect(tc.seed.value, const Color(0xFF6A1B9A));
      expect(tc.effectiveFontColor, const Color(0xFF1A1A1A));

      for (final Color c in <Color>[tc.gradient1, tc.gradient2]) {
        expect(c.b, greaterThan(c.g), reason: '$c 应呈现紫色（蓝通道高于绿通道）');

        expect(c.computeLuminance(), greaterThan(0.50),
            reason: '$c 应偏浅（用户要求浅色系，不再用深紫）');
      }
    });

    test('云青：浅灰蓝（承接原「大暗黑天」的 id）+ 字色近黑', () {
      final ThemeController tc = makeTc();
      tc.applyPreset(presets[5]);
      expect(tc.currentPreset.value, 'dark_sky', reason: '历史 id 保持不变');
      expect(tc.themeMode.value, 1);
      expect(tc.seed.value, const Color(0xFF37474F));

      expect(tc.gradient2, const Color(0xFFBFD2D8));
      expect(tc.effectiveFontColor, const Color(0xFF1A1A1A));
    });

    test('clearPreset 清除标记', () {
      final ThemeController tc = makeTc();
      tc.applyPreset(presets[0]);
      expect(tc.currentPreset.value, isNotNull);
      tc.clearPreset();
      expect(tc.currentPreset.value, isNull);
    });

    test('套用预设的过程中不会被自己的 setter 清掉标记', () {
      final ThemeController tc = makeTc();
      tc.applyPreset(presets[0]);
      expect(tc.currentPreset.value, 'snow_plum');
      expect(tc.seed.value, presets[0].seed);

      expect(tc.panelColor.value, ThemeController.defaultPanelColor);
      expect(tc.panel1Alpha.value, ThemeController.defaultPanel1Alpha);
      expect(tc.panel2Alpha.value, ThemeController.defaultPanel2Alpha);
    });

    test('套用后再 load 能恢复 preset id 与各参数', () async {
      final ThemeController tc = makeTc();
      tc.applyPreset(presets[2]); 

      final ThemeController tc2 = ThemeController();
      await tc2.load();
      expect(tc2.currentPreset.value, 'blue_sky');
      expect(tc2.themeMode.value, 1);
      expect(tc2.seed.value, const Color(0xFF1565C0));
    });
  });

  group('★ 手动微调后自动脱钩预设', () {
    ThemeController makeTc() => Get.put(ThemeController());

    test('改主色 → 不再算这套预设（抽屉勾选要消失）', () {
      final ThemeController tc = makeTc();
      tc.applyPreset(presets[1]); 
      expect(tc.currentPreset.value, 'green_bamboo');

      tc.setSeed(const Color(0xFF009688));
      expect(tc.currentPreset.value, isNull,
          reason: '手动改过主色后，抽屉还勾着「青筠」就是误导');
    });

    test('切明暗档 / 改主色 → 同样脱钩', () {
      final ThemeController tc = makeTc();
      tc.applyPreset(presets[0]);

      tc.applyBuiltinMode(2);
      expect(tc.currentPreset.value, isNull);

      tc.applyPreset(presets[0]);
      tc.setSeed(const Color(0xFF123456));
      expect(tc.currentPreset.value, isNull);

      tc.applyPreset(presets[0]);
      tc.setComponentOpacity(0.5);
      expect(tc.currentPreset.value, presets[0].id,
          reason: '透明度只影响可读性，不算"改了这套主题"');
    });

    test('改字色不算脱钩（预设允许叠加自定义字色）', () {
      final ThemeController tc = makeTc();
      tc.applyPreset(presets[2]); 
      tc.setFontColor(const Color(0xFF00FF00));
      expect(tc.currentPreset.value, 'blue_sky');
    });
  });

  group('★ 抽屉勾选：自定义主题 vs 内置三档 vs 精选主题', () {
    ThemeController makeTc() => Get.put(ThemeController());

    test('默认（未做任何改动）勾在「跟随系统」', () {
      final ThemeController tc = makeTc();
      tc.setThemeMode(0);
      expect(tc.isBuiltinMode(0), isTrue);
      expect(tc.isCustomSelected, isFalse);
    });

    test('点「自定义主题」→ 勾选从三档移到自定义主题', () {
      final ThemeController tc = makeTc();
      tc.applyBuiltinMode(2); 
      expect(tc.isBuiltinMode(2), isTrue);

      tc.markCustomTheme(); 
      expect(tc.useCustom.value, isTrue);
      expect(tc.isCustomSelected, isTrue);
      expect(tc.isBuiltinMode(2), isFalse,
          reason: '不能同时勾「黑暗模式」和「自定义主题」');

      expect(tc.themeMode.value, 2);
    });

    test('在主题页改参数（主色）→ 自动算作自定义主题', () {
      final ThemeController tc = makeTc();
      tc.applyBuiltinMode(1);

      tc.setSeed(const Color(0xFF112233));
      expect(tc.isCustomSelected, isTrue);
      expect(tc.isBuiltinMode(1), isFalse);
    });

    test('套用精选主题 → 不再算自定义主题', () {
      final ThemeController tc = makeTc();
      tc.markCustomTheme();
      expect(tc.isCustomSelected, isTrue);

      tc.applyPreset(presets[0]);
      expect(tc.useCustom.value, isFalse);
      expect(tc.isCustomSelected, isFalse);
      expect(tc.currentPreset.value, 'snow_plum');
    });

    test('切回内置三档 → 清掉自定义主题标记', () {
      final ThemeController tc = makeTc();
      tc.markCustomTheme();
      tc.applyBuiltinMode(1);
      expect(tc.useCustom.value, isFalse);
      expect(tc.isBuiltinMode(1), isTrue);
    });

    test('useCustom 会持久化（重启后仍在）', () async {
      final ThemeController tc = makeTc();
      tc.markCustomTheme();
      final ThemeController tc2 = ThemeController();
      await tc2.load();
      expect(tc2.useCustom.value, isTrue);
    });
  });
}
