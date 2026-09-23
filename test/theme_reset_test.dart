import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/style_keys.dart';
import 'package:torrent_manager/app/theme.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';

const String _p = 'torrentmanager.global.';

ThemePreset presetOf(String id) =>
    presets.firstWhere((ThemePreset p) => p.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
  });

  late ThemeController tc;

  Future<void> boot() async {
    Get.testMode = true;
    Get.reset();
    tc = Get.put(ThemeController(), permanent: true);
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall call) async => null);
  });

  group('出厂默认外观 = 明亮系（不再是 #282828 / #1E1E1E）', () {
    test('默认渐变与面板色都是浅色', () async {
      await boot();
      expect(tc.gradient1, ThemeController.defaultGradient1);
      expect(tc.gradient2, ThemeController.defaultGradient2);
      expect(tc.panelColor.value, ThemeController.defaultPanelColor);
      expect(tc.panel1Alpha.value, ThemeController.defaultPanel1Alpha);
      expect(tc.panel2Alpha.value, ThemeController.defaultPanel2Alpha);

      expect(tc.gradient1.computeLuminance(), greaterThan(0.8));
      expect(tc.gradient2.computeLuminance(), greaterThan(0.8));
      expect(tc.panelColor.value.computeLuminance(), greaterThan(0.8));
    });
  });

  group('切内置三档 = 出厂外观（修「背景默认紫色」）', () {
    test('套过紫色预设后点「明亮模式」，背景必须回纯色且渐变复位', () async {
      await boot();
      final ThemePreset purple = presetOf('purple_mood');
      tc.applyPreset(purple);
      expect(tc.bgModeValue, 1, reason: '预设本身就是渐变背景');
      expect(tc.gradient1, purple.gradient1);

      tc.applyBuiltinMode(1);

      expect(tc.themeMode.value, 1);
      expect(tc.bgModeValue, 0, reason: '内置三档必须回纯色，否则页面底还是紫渐变');
      expect(tc.gradient1, ThemeController.defaultGradient1);
      expect(tc.gradient2, ThemeController.defaultGradient2);
      expect(tc.panelColor.value, ThemeController.defaultPanelColor);
      expect(tc.currentPreset.value, isNull, reason: '不再是精选主题');
      expect(tc.useCustom.value, isFalse, reason: '也不是自定义主题');
    });

    test('切内置三档会一并清掉分页面配色（残留会导致深底压黑字）', () async {
      await boot();
      tc.setPageColor(
          AppPageKey.torrentList, AppStyleSlot.background, const Color(0xFF101010));
      expect(tc.pageColors.isNotEmpty, isTrue);

      tc.applyBuiltinMode(1);
      expect(tc.pageColors.isEmpty, isTrue);
    });

    test('切黑暗档同样复位背景（只保留明暗差异）', () async {
      await boot();
      tc.applyPreset(presetOf('snow_plum'));
      expect(tc.bgModeValue, 1);

      tc.applyBuiltinMode(2);
      expect(tc.bgModeValue, 0, reason: '套过渐变预设后切黑暗档，背景必须回纯色');
      expect(tc.themeMode.value, 2);
      expect(tc.currentPreset.value, isNull);
      expect(tc.useCustom.value, isFalse);

      expect(tc.gradient1, builtinDark.gradient1);
      expect(tc.gradient2, builtinDark.gradient2);
      expect(tc.gradient1.computeLuminance(), lessThan(0.2),
          reason: '黑暗档的背景端点必须是深色');
    });
  });

  group('恢复默认 = 首启默认参数（需求 8：还原"首次启动加载的那套参数"）', () {
    test('恢复默认后所有外观参数都回默认，且不留预设 / 自定义标记', () async {
      await boot();
      tc.applyPreset(presetOf('purple_mood'));
      tc.setFontColor(const Color(0xFF00FF00));
      tc.setPageColor(
          AppPageKey.settings, AppStyleSlot.background, const Color(0xFF000000));
      tc.setGlobalBgEnabled(true);
      tc.setGlobalBgBlur(8);

      tc.restoreFactoryDefaults();

      expect(tc.themeMode.value, 1, reason: '参数还原成默认参数（首启值：明亮）');
      expect(tc.bgModeValue, 0);
      expect(tc.seed.value, AppTheme.seedColors.first);
      expect(tc.gradient1, ThemeController.defaultGradient1);
      expect(tc.gradient2, ThemeController.defaultGradient2);
      expect(tc.panelColor.value, ThemeController.defaultPanelColor);
      expect(tc.panel1Alpha.value, ThemeController.defaultPanel1Alpha);
      expect(tc.panel2Alpha.value, ThemeController.defaultPanel2Alpha);
      expect(tc.fontColor.value, isNull, reason: '字色回到跟随主题');

      expect(tc.pageColors.isEmpty, isTrue);

      expect(tc.pageBgImage, ThemeController.defaultBackgroundImage);
      expect(tc.menuImagePath.value, ThemeController.defaultMenuImage);
      expect(tc.globalBgEnabled.value, isFalse);
      expect(tc.globalBgImagePath.value, isNull);
      expect(tc.globalBgBlur.value, 0);
      expect(tc.currentPreset.value, isNull, reason: '不再是某套精选主题');

      expect(tc.useCustom.value, isTrue);
      expect(tc.isCustomSelected, isTrue);
      expect(tc.isBuiltinMode(1), isFalse);
    });

    test('★「恢复默认」产出的参数集 = 首次启动加载的那套参数', () async {
      await boot();

      tc.applyPreset(presetOf('purple_mood'));
      tc.setFontColor(const Color(0xFFFF00FF));
      tc.setPageColor(
          AppPageKey.log, AppStyleSlot.background, const Color(0xFF333333));
      tc.restoreFactoryDefaults();
      final List<Object?> restored = _snapshot(tc);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      Get.delete<ThemeController>(force: true);
      final ThemeController fresh = Get.put(ThemeController(), permanent: true);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final List<Object?> baseline = _snapshot(fresh);

      expect(restored, baseline,
          reason: '需求 8：恢复默认必须还原成"首次启动加载的参数"这一组具体值');
    });
  });

  group('套用预设会清掉分页面配色（修「套预设后文字与背景相近」）', () {
    test('预设套用后 pageColors 清空、字色回到跟随主题', () async {
      await boot();
      tc.setPageColor(
          AppPageKey.serverList, AppStyleSlot.background, const Color(0xFF222222));
      tc.setFontColor(const Color(0xFFEEEEEE));

      tc.applyPreset(presetOf('snow_plum'));

      expect(tc.pageColors.isEmpty, isTrue,
          reason: '残留的深色页底 + 预设算出的近黑字 = 看不清');
      expect(tc.fontColor.value, isNull,
          reason: '字色交给 AppTheme.contrastOn 按新背景自动反色');
    });
  });

  group('历史残留迁移（启动时清理内置三档下的预设背景）', () {
    test('落盘「渐变 + 紫 + 无预设标记」→ 启动后复位为纯色出厂外观', () async {
      SecurePrefs.useMemoryBackendForTest(<String, Object>{
        '${_p}torrentmanager.theme.bgMode': 1,
        '${_p}torrentmanager.theme.grad1': 0xFF4A148C,
        '${_p}torrentmanager.theme.grad2': 0xFF7B1FA2,
        '${_p}torrentmanager.theme.panelColor': 0xFF4E2A73,
        '${_p}torrentmanager.theme.panel1Alpha': 0.85,
      });
      await boot();

      expect(tc.bgModeValue, 0, reason: '内置三档档位下不该带着预设的渐变背景');
      expect(tc.gradient1, ThemeController.defaultGradient1);
      expect(tc.gradient2, ThemeController.defaultGradient2);
      expect(tc.panelColor.value, ThemeController.defaultPanelColor);
    });

    test('正在使用精选预设时不迁移（那套紫是用户主动选的）', () async {
      SecurePrefs.useMemoryBackendForTest(<String, Object>{
        '${_p}torrentmanager.theme.preset': 'purple_mood',
        '${_p}torrentmanager.theme.bgMode': 1,
        '${_p}torrentmanager.theme.grad1': 0xFF4A148C,
        '${_p}torrentmanager.theme.grad2': 0xFF7B1FA2,
      });
      await boot();

      expect(tc.currentPreset.value, 'purple_mood');
      expect(tc.bgModeValue, 1);
      expect(tc.gradient1, const Color(0xFF4A148C));
    });

    test('迁移只跑一次：之后落盘的渐变背景不会被再次清掉', () async {
      SecurePrefs.useMemoryBackendForTest(<String, Object>{
        '${_p}torrentmanager.theme.bgMode': 1,
        '${_p}torrentmanager.theme.grad1': 0xFF4A148C,
      });
      await boot();
      expect(tc.bgModeValue, 0, reason: '首次启动已迁移');

      SecurePrefs.useMemoryBackendForTest(<String, Object>{
        '${_p}torrentmanager.theme.bgMode': 1,
        '${_p}torrentmanager.theme.grad1': 0xFF4A148C,
        '${_p}torrentmanager.theme.mig.freeToLight': true,
      });
      Get.delete<ThemeController>(force: true);
      await boot();
      expect(tc.bgModeValue, 1, reason: '迁移标记已写盘，不该再清一次');
      expect(tc.gradient1, const Color(0xFF4A148C));
    });
  });
}

List<Object?> _snapshot(ThemeController tc) => <Object?>[
      tc.themeMode.value,
      tc.seed.value,
      tc.bgModeValue,
      tc.gradient1,
      tc.gradient2,
      tc.panelColor.value,
      tc.panel1Alpha.value,
      tc.panel2Alpha.value,
      tc.fontColor.value,
      tc.pageColors.length,
    ];
