






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

  test('★ 勾选标识：模板行与"在用的那套"不会同时打勾', () async {
    final ThemeController tc = Get.put(ThemeController());
    await tc.load();

    tc.setSeed(AppTheme.seedColors.last);
    final CustomTheme a = await tc.saveCustomTheme('甲');

    expect(tc.isCustomThemeSelected(a), isTrue, reason: '保存后应勾选新存的这套');
    expect(tc.isCustomSelected, isFalse,
        reason: '★「自定义主题」模板行不应与它同时打勾');

    
    final ThemePreset base = wallpaperPresets.first;
    tc.applyPreset(base);
    expect(tc.customThemes.any(tc.isCustomThemeSelected), isFalse,
        reason: '切走之后勾应从自定义主题上移开');

    
    tc.enterCustomTheme();
    expect(tc.isCustomSelected, isTrue);
    expect(tc.isCustomThemeSelected(a), isFalse,
        reason: '★ 参数是"自由模板"的，勾就不该留在甲身上');
  });

  test('★ 编辑会话：载入草稿不改变全站观感，未保存返回则完全复原', () async {
    final ThemeController tc = Get.put(ThemeController());
    await tc.load();

    
    final ThemePreset base = wallpaperPresets.first;
    tc.applyPreset(base);

    
    tc.setSeed(AppTheme.seedColors.last);
    tc.setComponentOpacity(0.35);
    final CustomTheme a = await tc.saveCustomTheme('甲');

    
    tc.applyPreset(base);
    final ColorScheme renderedBefore = tc.theme.colorScheme;
    final Color seedBefore = tc.seed.value;
    final double opacityBefore = tc.componentOpacity.value;

    
    tc.beginThemeEditing(load: a);
    expect(tc.editingCustomId, a.id);
    expect(tc.seed.value, isNot(seedBefore), reason: '草稿应把该套参数载入内存');
    expect(tc.componentOpacity.value, 0.35);

    expect(tc.theme.colorScheme, renderedBefore,
        reason: '★ 未点保存前，全站渲染必须仍是进入前那套');
    expect(tc.customThemes.any(tc.isCustomThemeSelected), isFalse,
        reason: '★ 未点保存前，勾选状态一动不动');

    
    tc.cancelThemeEditing();
    expect(tc.seed.value, seedBefore, reason: '★ 返回后参数完全复原');
    expect(tc.componentOpacity.value, opacityBefore);
    expect(tc.theme.colorScheme, renderedBefore);
    expect(tc.editingCustomId, isNull);
    expect(tc.customThemes.any(tc.isCustomThemeSelected), isFalse);
    expect(tc.isCustomSelected, isFalse, reason: '勾仍留在原来的精选主题上');
    expect(tc.currentPreset.value, base.id, reason: '精选主题标记未被草稿改掉');
  });

  test('★ 覆盖更新：候选、原地写回、并应用它', () async {
    final ThemeController tc = Get.put(ThemeController());
    await tc.load();

    expect(tc.overwriteCandidates, isEmpty);
    expect(tc.defaultOverwriteTarget, isNull, reason: '一套都没有时不给覆盖更新');

    tc.setSeed(AppTheme.seedColors[3]);
    final CustomTheme a = await tc.saveCustomTheme('甲');
    final int aIndex = tc.customThemes.indexWhere((CustomTheme t) => t.id == a.id);
    tc.setSeed(AppTheme.seedColors[4]);
    await tc.saveCustomTheme('乙');

    
    tc.applyPreset(lightPresets.first);
    expect(tc.overwriteCandidates.length, 2);
    expect(tc.defaultOverwriteTarget, isNotNull,
        reason: '★ 只要还有已创建的自定义主题，就必须能给出覆盖更新');

    
    tc.beginThemeEditing(load: tc.customThemes[aIndex]);
    expect(tc.editingCustomId, a.id);
    expect(tc.defaultOverwriteTarget?.id, a.id,
        reason: '默认覆盖"正在编辑"的那一套');

    final Color changed = AppTheme.seedColors.last;
    tc.setSeed(changed);
    await tc.overwriteThemeEditing(a.id);

    expect(tc.customThemes.length, 2, reason: '覆盖不应新增条目');
    expect(tc.customThemes[aIndex].id, a.id, reason: '★ 原地更新：id 不变');
    expect(tc.customThemes[aIndex].name, '甲', reason: '名称保持');
    expect(tc.customThemes[aIndex].seed, changed, reason: '★ 写入了当前配置');
    expect(tc.isCustomThemeSelected(tc.customThemes[aIndex]), isTrue,
        reason: '★ 覆盖更新后应用并勾选它');
    expect(tc.seed.value, changed);
  });

  test('★ currentCustomId 落盘：重启后勾选仍落在正确的那一套上', () async {
    final ThemeController tc = Get.put(ThemeController());
    await tc.load();
    tc.setSeed(AppTheme.seedColors[2]);
    final CustomTheme a = await tc.saveCustomTheme('甲');

    
    Get.reset();
    final ThemeController tc2 = ThemeController();
    await tc2.load();

    expect(tc2.customThemes.length, 1);
    expect(tc2.currentCustomId.value, a.id,
        reason: '★ 重启后仍应指向正在使用的那套');
    expect(tc2.isCustomThemeSelected(tc2.customThemes.first), isTrue);
    expect(tc2.isCustomSelected, isFalse,
        reason: '★ 勾不应落到「自定义主题」模板行上');
  });
}
