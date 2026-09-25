import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/style_keys.dart';
import '../app/theme.dart';
import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';
import '../utils/theme_backup.dart';

class ThemeController extends GetxController {
  static const Color defaultGradient1 = Color(0xFFFFFFFF);
  static const Color defaultGradient2 = Color(0xFFF0F2F5);
  static const Color defaultPanelColor = Color(0xFFFFFFFF);
  static const double defaultPanel1Alpha = 0.92;
  static const double defaultPanel2Alpha = 0.80;

  static const String defaultMenuImage =
      'assets/images/drawer_menu_default.webp';
  static const String defaultBackgroundImage = defaultMenuImage;

  static final Set<String> bundledAssets = <String>{
    defaultMenuImage,
    for (final ThemePreset p in presets)
      if (p.bgImage != null) p.bgImage!,
  };

  static String? aliveAsset(String? path) {
    if (path == null || path.isEmpty) return null;
    if (!path.startsWith('assets/')) return path;
    return bundledAssets.contains(path) ? path : null;
  }

  final themeMode = 0.obs;

  final seed = AppTheme.seedColors.first.obs;

  final _bgMode = 0.obs;
  final _gradient1 = defaultGradient1.obs;
  final _gradient2 = defaultGradient2.obs;

  int get bgModeValue => _bgMode.value;

  Color get gradient1 => _gradient1.value;
  Color get gradient2 => _gradient2.value;

  String? get pageBgImage => _pageBgImage.value;

  final panelColor = defaultPanelColor.obs;
  final panel1Alpha = defaultPanel1Alpha.obs;
  final panel2Alpha = defaultPanel2Alpha.obs;

  final _pageBgImage = RxnString();

  final menuImagePath = RxnString();

  final menuBgBrightness = 0.0.obs;

  final menuBgFade = 0.0.obs;

  final menuBgBlur = 0.0.obs;

  final fontColor = Rxn<Color>();

  final globalBgEnabled = false.obs;
  final globalBgImagePath = RxnString();

  final globalBgBrightness = 0.0.obs;

  final globalBgFade = 0.0.obs;

  final globalBgBlur = 0.0.obs;

  final componentOpacity = 0.0.obs;

  static const double glassPanelTransparency = 0.26;

  final pageColors = <String, Color?>{}.obs;

  Color? pageColor(AppPageKey page, AppStyleSlot slot) =>
      pageColors[specOf(page).slotKey(slot)];

  void setPageColor(AppPageKey page, AppStyleSlot slot, Color? color) {
    final PageStyleSpec spec = specOf(page);
    final String key = spec.slotKey(slot);
    pageColors[key] = color;

    pageColors.refresh();
    Formatter.saveGlobalData(key, color?.toARGB32());
    markCustomTheme();
  }

  final currentPreset = RxnString();

  final useCustom = false.obs;

  final customThemes = <CustomTheme>[].obs;

  final currentCustomId = RxnString();

  bool _applyingPreset = false;

  bool get isFontColorCustom => fontColor.value != null;

  Color get effectiveFontColor {
    final Color? custom = fontColor.value;
    if (custom != null) return custom;
    final Color? bg = effectiveBackgroundColor;
    return bg == null
        ? AppTheme.defaultFontColor(_brightness)
        : AppTheme.contrastOn(bg);
  }

  Color? get effectiveBackgroundColor {
    switch (_bgMode.value) {
      case 1:
        return Color.lerp(_gradient1.value, _gradient2.value, 0.5) ??
            _gradient1.value;
      case 2:
        return null;
      default:
        return _brightness == Brightness.dark
            ? AppTheme.darkScaffold
            : AppTheme.lightScaffold;
    }
  }

  Brightness get _brightness =>
      themeMode.value == 2 ? Brightness.dark : Brightness.light;

  ThemeMode get materialMode =>
      themeMode.value == 2 ? ThemeMode.dark : ThemeMode.light;

  bool get backgroundActive =>
      renderGlobalBgDecorationImage != null || _liveBackgroundDecoration != null;

  bool get glassEnabled => componentOpacity.value > 0;

  double? get glassAlpha =>
      glassEnabled ? (1.0 - componentOpacity.value).clamp(0.0, 1.0) : null;

  ThemeData get theme => AppTheme.of(_liveSeed, _liveBrightness,
      fontColor: _liveEffectiveFontColor,
      background: _liveBackgroundColor,
      transparentScaffold: backgroundActive,
      glassAlpha: _liveGlassAlpha);
  ThemeData get darkTheme => AppTheme.of(_liveSeed, Brightness.dark,
      fontColor: _liveEffectiveFontColor,
      background: _liveBackgroundColor,
      transparentScaffold: backgroundActive,
      glassAlpha: _liveGlassAlpha);
  ThemeData get lightTheme => AppTheme.of(_liveSeed, Brightness.light,
      fontColor: _liveEffectiveFontColor,
      background: _liveBackgroundColor,
      transparentScaffold: backgroundActive,
      glassAlpha: _liveGlassAlpha);

  ThemeData get previewTheme => AppTheme.of(seed.value, _brightness,
      fontColor: effectiveFontColor,
      background: effectiveBackgroundColor,
      transparentScaffold: backgroundActive,
      glassAlpha: glassAlpha);

  double? get _liveGlassAlpha {
    final double t = _liveOpacity;
    return t > 0 ? (1.0 - t).clamp(0.0, 1.0) : null;
  }

  Brightness get _liveBrightness =>
      _liveThemeMode == 2 ? Brightness.dark : Brightness.light;

  Color get _liveEffectiveFontColor {
    final Color? custom = _liveFontColor;
    if (custom != null) return custom;
    final Color? bg = effectiveBackgroundColor;
    return bg == null
        ? AppTheme.defaultFontColor(_liveBrightness)
        : AppTheme.contrastOn(bg);
  }

  String get themeModeName => themeMode.value == 2 ? S.themeDark : S.themeLight;

  Decoration? get backgroundDecoration {
    switch (_bgMode.value) {
      case 1:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[_gradient1.value, _gradient2.value],
          ),
        );
      case 2:

        return Formatter.themeBackground(path: _pageBgImage.value);
      default:
        return null;
    }
  }

  @override
  void onInit() {
    super.onInit();

    load();
  }

  static const String _kThemeMode = 'torrentmanager.themeMode';
  static const String _kSeed = 'torrentmanager.theme.seed';

  static const String _kBgMode = 'torrentmanager.theme.bgMode';
  static const String _kGrad1 = 'torrentmanager.theme.grad1';
  static const String _kGrad2 = 'torrentmanager.theme.grad2';

  static const String _kFontColor = 'torrentmanager.theme.fontColor';
  static const String _kPreset = 'torrentmanager.theme.preset';
  static const String _kUseCustom = 'torrentmanager.theme.useCustom';
  static const String _kGlobalBgOn = 'torrentmanager.theme.globalBgEnabled';
  static const String _kGlobalBgPath = 'torrentmanager.theme.globalBgPath';
  static const String _kGlobalBgBrightness =
      'torrentmanager.theme.globalBgBrightness';
  static const String _kGlobalBgFade = 'torrentmanager.theme.globalBgFade';
  static const String _kGlobalBgBlur = 'torrentmanager.theme.globalBgBlur';
  static const String _kMenuBgBrightness = 'torrentmanager.theme.menuBgBrightness';
  static const String _kMenuBgFade = 'torrentmanager.theme.menuBgFade';
  static const String _kMenuBgBlur = 'torrentmanager.theme.menuBgBlur';

  static const String _kComponentOpacity = 'torrentmanager.theme.componentOpacity';

  static const String _kTransparency = 'torrentmanager.theme.transparency';

  static const String _kOpacitySemantics = 'torrentmanager.theme.opacitySemantics';

  static const String _kCustomThemes = 'torrentmanager.theme.customThemes';

  static const String _kCurrentCustomId = 'torrentmanager.theme.currentCustomId';

  Future<void> load() async {
    final int storedMode = await Formatter.getGlobalInt(_kThemeMode);
    themeMode.value = storedMode == 2 ? 2 : 1;
    seed.value = await _readColor(_kSeed) ?? AppTheme.seedColors.first;

    _bgMode.value = await Formatter.getGlobalInt(_kBgMode);
    _gradient1.value = await _readColor(_kGrad1) ?? defaultGradient1;
    _gradient2.value = await _readColor(_kGrad2) ?? defaultGradient2;

    panelColor.value = defaultPanelColor;
    panel1Alpha.value = defaultPanel1Alpha;
    panel2Alpha.value = defaultPanel2Alpha;

    _pageBgImage.value = aliveAsset(await Formatter.getBackgroundImage()) ??
        defaultBackgroundImage;
    menuImagePath.value =
        aliveAsset(await Formatter.getMenuBackgroundImage()) ?? defaultMenuImage;

    menuBgBrightness.value =
        (await Formatter.getGlobalData(_kMenuBgBrightness) as num?)
                ?.toDouble() ??
            0;
    menuBgFade.value =
        (await Formatter.getGlobalData(_kMenuBgFade) as num?)?.toDouble() ?? 0;
    menuBgBlur.value =
        (await Formatter.getGlobalData(_kMenuBgBlur) as num?)?.toDouble() ?? 0;

    fontColor.value = await _readColor(_kFontColor);

    final Object? preset = await Formatter.getGlobalData(_kPreset);
    currentPreset.value = preset is String ? preset : null;

    useCustom.value = (await Formatter.getGlobalData(_kUseCustom)) == true;

    final Object? cid = await Formatter.getGlobalData(_kCurrentCustomId);
    currentCustomId.value = cid is String && cid.isNotEmpty ? cid : null;

    globalBgEnabled.value =
        (await Formatter.getGlobalData(_kGlobalBgOn)) == true;
    final Object? bgPath = await Formatter.getGlobalData(_kGlobalBgPath);

    globalBgImagePath.value = aliveAsset(bgPath is String ? bgPath : null);
    globalBgBrightness.value =
        (await Formatter.getGlobalData(_kGlobalBgBrightness) as num?)
                ?.toDouble() ??
            0;
    globalBgFade.value =
        (await Formatter.getGlobalData(_kGlobalBgFade) as num?)?.toDouble() ?? 0;
    globalBgBlur.value =
        (await Formatter.getGlobalData(_kGlobalBgBlur) as num?)?.toDouble() ?? 0;

    Object? rawTransparency = await Formatter.getGlobalData(_kTransparency);
    if (rawTransparency is! num) {
      final Object? legacy =
          await Formatter.getGlobalData(_kComponentOpacity);
      final bool legacyMigrated =
          (await Formatter.getGlobalData(_kOpacitySemantics)) == true;
      double t = 0.0;
      if (legacy is num) {
        t = legacy.toDouble();
        if (!legacyMigrated) {
          t = 1.0 - t;
        } else if (t >= 1.0) {
          t = 0.0;
        }
      }
      t = t.clamp(0.0, 1.0);
      await Formatter.saveGlobalData(_kTransparency, t);
      rawTransparency = t;
    }
    componentOpacity.value = rawTransparency.toDouble().clamp(0.0, 1.0);

    for (final PageStyleSpec spec in kPageStyles) {
      for (final AppStyleSlot slot in spec.slots) {
        final String key = spec.slotKey(slot);
        final Color? c = await _readColor(key);
        if (c != null) pageColors[key] = c;
      }
    }
    pageColors.refresh();

    await _migrateLegacyFreeTheme();

    await _loadCustomThemes();

    final String? dangling = currentCustomId.value;
    if (dangling != null &&
        !customThemes.any((CustomTheme t) => t.id == dangling)) {
      currentCustomId.value = null;
    }
  }

  void resetVisualParams({
    bool includePageStyles = true,
    bool includeImages = false,
  }) {
    seed.value = AppTheme.seedColors.first;
    _writeColor(_kSeed, AppTheme.seedColors.first);

    _bgMode.value = 0;
    Formatter.saveGlobalData(_kBgMode, 0);

    _gradient1.value = defaultGradient1;
    _gradient2.value = defaultGradient2;
    _writeColor(_kGrad1, defaultGradient1);
    _writeColor(_kGrad2, defaultGradient2);

    panelColor.value = defaultPanelColor;
    panel1Alpha.value = defaultPanel1Alpha;
    panel2Alpha.value = defaultPanel2Alpha;

    fontColor.value = null;
    Formatter.saveGlobalData(_kFontColor, null);

    if (includePageStyles) _clearPageStyles();

    if (includeImages) {
      _setPageBgImage(defaultBackgroundImage);
      setMenuImage(defaultMenuImage);

      setComponentOpacity(0.0);
      _resetGlobalBg();
    }
  }

  void _resetGlobalBg() {
    globalBgEnabled.value = false;
    globalBgImagePath.value = null;
    globalBgBrightness.value = 0;
    globalBgFade.value = 0;
    globalBgBlur.value = 0;
    Formatter.saveGlobalData(_kGlobalBgOn, false);
    Formatter.saveGlobalData(_kGlobalBgPath, null);
    Formatter.saveGlobalData(_kGlobalBgBrightness, 0.0);
    Formatter.saveGlobalData(_kGlobalBgFade, 0.0);
    Formatter.saveGlobalData(_kGlobalBgBlur, 0.0);
  }

  void _clearPageStyles() {
    for (final PageStyleSpec spec in kPageStyles) {
      for (final AppStyleSlot slot in spec.slots) {
        Formatter.saveGlobalData(spec.slotKey(slot), null);
      }
    }
    pageColors.clear();
    pageColors.refresh();
  }

  void restoreFactoryDefaults() {
    _applyingPreset = true;
    try {
      useCustom.value = true;
      Formatter.saveGlobalData(_kUseCustom, true);
      clearPreset();

      setThemeMode(1);

      resetVisualParams(includePageStyles: true, includeImages: true);
    } finally {
      _applyingPreset = false;
    }
    _apply();
    AppLog.instance.op('恢复默认外观（参数复位为出厂明亮档）');
  }

  static const String _kMigrFreeTheme = 'torrentmanager.theme.mig.freeToLight';

  Future<void> _migrateLegacyFreeTheme() async {
    final Object? done = await Formatter.getGlobalData(_kMigrFreeTheme);
    if (done == true) return;
    final bool builtin = currentPreset.value == null && !useCustom.value;

    final bool dirty = _bgMode.value != 0 ||
        _gradient1.value != defaultGradient1 ||
        _gradient2.value != defaultGradient2 ||
        panelColor.value != defaultPanelColor ||
        pageColors.isNotEmpty ||

        menuImagePath.value != defaultMenuImage;
    if (builtin && dirty) {
      _applyingPreset = true;
      try {
        resetVisualParams(includePageStyles: true, includeImages: true);
      } finally {
        _applyingPreset = false;
      }
      AppLog.instance.info('主题迁移：已清理内置三档下残留的预设外观参数');
    }
    await Formatter.saveGlobalData(_kMigrFreeTheme, true);
  }

  static Future<Color?> _readColor(String key) async {
    final Object? v = await Formatter.getGlobalData(key);
    if (v is int) return Color(v);
    if (v is String) {
      final int? n = int.tryParse(v);
      if (n != null) return Color(n);
    }
    return null;
  }

  static Future<void> _writeColor(String key, Color c) =>
      Formatter.saveGlobalData(key, c.toARGB32());

  void _markCustom() {
    if (_applyingPreset) return;
    markCustomTheme();
    if (currentPreset.value == null) return;
    clearPreset();
  }

  void markCustomTheme() {
    if (_applyingPreset) return;
    if (useCustom.value) return;
    useCustom.value = true;
    Formatter.saveGlobalData(_kUseCustom, true);
  }

  void enterCustomTheme() {
    clearPreset();
    markCustomTheme();

    currentCustomId.value = null;
    _persistCurrentCustomId();
  }

  String get _seedHex =>
      '#${seed.value.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  String get _fontColorDesc {
    final Color? c = fontColor.value;
    return c == null
        ? '字色跟随主题'
        : '字色 #${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  void applyBuiltinMode(int mode) {
    applySpec(mode == 2 ? builtinDark : builtinLight);
    AppLog.instance.op('切换主题：${mode == 2 ? '黑暗模式' : '明亮模式'}'
        '（seed $_seedHex · $_fontColorDesc）');
  }

  void setThemeMode(int mode) {
    themeMode.value = mode.clamp(0, 2);
    Formatter.saveGlobalData(_kThemeMode, themeMode.value);

    _apply();
  }

  void setSeed(Color c) {
    seed.value = c;
    _writeColor(_kSeed, c);
    _markCustom();
    _apply();
  }

  void setFontColor(Color? c) {
    fontColor.value = c;

    Formatter.saveGlobalData(_kFontColor, c?.toARGB32());
    _apply();
  }

  void applyPreset(ThemePreset p) {
    applySpec(p);
    AppLog.instance.op('应用主题：${p.name}'
        '（${themeMode.value == 2 ? '暗' : '亮'} · seed $_seedHex）');
  }

  final _draft = Rxn<_ThemeDraft>();

  bool get editingTheme => _draft.value != null;

  String? _editingCustomId;

  String? get editingCustomId => _editingCustomId;

  void beginThemeEditing({CustomTheme? load, String? editingId}) {
    if (_draft.value != null) return;
    _draft.value = _snapshotDraft();
    Formatter.persistSuspended = true;
    if (load != null) {
      _editingCustomId = editingId ?? load.id;
      _writeAppearance(load);
    }
  }

  void cancelThemeEditing() {
    final _ThemeDraft? s = _draft.value;
    _draft.value = null;
    _editingCustomId = null;
    Formatter.persistSuspended = false;
    if (s == null) return;
    _restoreDraft(s);
  }

  Future<CustomTheme> commitThemeEditing(String name) async {
    _draft.value = null;
    _editingCustomId = null;
    Formatter.persistSuspended = false;
    return saveCustomTheme(name);
  }

  Future<void> overwriteThemeEditing(String id, {String? name}) async {
    _draft.value = null;
    _editingCustomId = null;
    Formatter.persistSuspended = false;
    await overwriteCustomTheme(id, name: name);
  }

  Future<void> updateThemeEditing(String id) => overwriteThemeEditing(id);

  _ThemeDraft _snapshotDraft() => _ThemeDraft(
        themeMode: themeMode.value,
        seed: seed.value,
        fontColor: fontColor.value,
        bgMode: _bgMode.value,
        gradient1: _gradient1.value,
        gradient2: _gradient2.value,
        bgImage: _pageBgImage.value,
        componentOpacity: componentOpacity.value,
        pageColors: <String, int>{
          for (final MapEntry<String, Color?> e in pageColors.entries)
            if (e.value != null) e.key: e.value!.toARGB32(),
        },
        menuImage: menuImagePath.value,
        menuBgBrightness: menuBgBrightness.value,
        menuBgFade: menuBgFade.value,
        menuBgBlur: menuBgBlur.value,
        globalBgEnabled: globalBgEnabled.value,
        globalBgImage: globalBgImagePath.value,
        globalBgBrightness: globalBgBrightness.value,
        globalBgFade: globalBgFade.value,
        globalBgBlur: globalBgBlur.value,
      );

  void _restoreDraft(_ThemeDraft s) {
    themeMode.value = s.themeMode;
    seed.value = s.seed;
    fontColor.value = s.fontColor;
    _bgMode.value = s.bgMode;
    _gradient1.value = s.gradient1;
    _gradient2.value = s.gradient2;
    _pageBgImage.value = s.bgImage;
    componentOpacity.value = s.componentOpacity;
    pageColors.clear();
    for (final MapEntry<String, int> e in s.pageColors.entries) {
      pageColors[e.key] = Color(e.value);
    }
    pageColors.refresh();
    menuImagePath.value = s.menuImage;
    menuBgBrightness.value = s.menuBgBrightness;
    menuBgFade.value = s.menuBgFade;
    menuBgBlur.value = s.menuBgBlur;
    globalBgEnabled.value = s.globalBgEnabled;
    globalBgImagePath.value = s.globalBgImage;
    globalBgBrightness.value = s.globalBgBrightness;
    globalBgFade.value = s.globalBgFade;
    globalBgBlur.value = s.globalBgBlur;
  }

  int get _liveThemeMode {
    final _ThemeDraft? d = _draft.value;
    final int live = themeMode.value;
    return d?.themeMode ?? live;
  }

  Color get _liveSeed {
    final _ThemeDraft? d = _draft.value;
    final Color live = seed.value;
    return d?.seed ?? live;
  }

  Color? get _liveFontColor {
    final _ThemeDraft? d = _draft.value;
    final Color? live = fontColor.value;
    return d?.fontColor ?? live;
  }

  double get _liveOpacity {
    final _ThemeDraft? d = _draft.value;
    final double live = componentOpacity.value;
    return d?.componentOpacity ?? live;
  }

  int get _liveBgMode {
    final _ThemeDraft? d = _draft.value;
    final int live = _bgMode.value;
    return d?.bgMode ?? live;
  }

  Color get _liveGradient1 {
    final _ThemeDraft? d = _draft.value;
    final Color live = _gradient1.value;
    return d?.gradient1 ?? live;
  }

  Color get _liveGradient2 {
    final _ThemeDraft? d = _draft.value;
    final Color live = _gradient2.value;
    return d?.gradient2 ?? live;
  }

  Color? get _liveBackgroundColor {
    switch (_liveBgMode) {
      case 1:
        return Color.lerp(_liveGradient1, _liveGradient2, 0.5) ??
            _liveGradient1;
      case 2:
        return null;
      default:
        return _liveBrightness == Brightness.dark
            ? AppTheme.darkScaffold
            : AppTheme.lightScaffold;
    }
  }

  Decoration? get _liveBackgroundDecoration {
    switch (_liveBgMode) {
      case 1:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[_liveGradient1, _liveGradient2],
          ),
        );
      case 2:
        return Formatter.themeBackground(path: _draft.value?.bgImage ?? _pageBgImage.value);
      default:
        return null;
    }
  }

  Color get drawerBaseColor {
    if (_bgMode.value == 0) {
      return _brightness == Brightness.dark
          ? AppTheme.darkDrawer
          : AppTheme.lightScaffold;
    }
    return Color.lerp(_gradient1.value, _gradient2.value, 0.5) ??
        _gradient1.value;
  }

  Color get drawerFontColor {
    final Color? slot = pageColor(AppPageKey.drawer, AppStyleSlot.text);
    if (slot != null) return slot;
    final Color? custom = fontColor.value;
    if (custom != null) return custom;
    return AppTheme.contrastOn(drawerBaseColor);
  }

  Future<CustomTheme> saveCustomTheme(String name) async {
    final CustomTheme t = CustomTheme(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      themeMode: themeMode.value,
      seed: seed.value,
      fontColor: fontColor.value,
      bgMode: _bgMode.value,
      gradient1: _gradient1.value,
      gradient2: _gradient2.value,
      bgImage: _pageBgImage.value,
      componentOpacity: componentOpacity.value,
      pageColors: <String, int>{
        for (final MapEntry<String, Color?> e in pageColors.entries)
          if (e.value != null) e.key: e.value!.toARGB32(),
      },
    );
    customThemes.add(t);
    currentCustomId.value = t.id;
    useCustom.value = true;

    Formatter.saveGlobalData(_kUseCustom, true);
    _persistCurrentCustomId();
    await _persistCustomThemes();
    AppLog.instance.op('保存自定义主题：$name');
    return t;
  }

  Future<void> overwriteCustomTheme(String id, {String? name}) async {
    final int i = customThemes.indexWhere((CustomTheme t) => t.id == id);
    if (i < 0) return;
    final CustomTheme old = customThemes[i];
    final CustomTheme fresh = CustomTheme(
      id: old.id,
      name: name ?? old.name,
      themeMode: themeMode.value,
      seed: seed.value,
      fontColor: fontColor.value,
      bgMode: _bgMode.value,
      gradient1: _gradient1.value,
      gradient2: _gradient2.value,
      bgImage: _pageBgImage.value,
      componentOpacity: componentOpacity.value,
      pageColors: <String, int>{
        for (final MapEntry<String, Color?> e in pageColors.entries)
          if (e.value != null) e.key: e.value!.toARGB32(),
      },
    );
    customThemes[i] = fresh;
    currentCustomId.value = id;
    useCustom.value = true;
    Formatter.saveGlobalData(_kUseCustom, true);
    _persistCurrentCustomId();
    await _persistCustomThemes();
    AppLog.instance.op('覆盖更新自定义主题：${fresh.name}');
  }

  Future<void> updateCustomTheme(String id) => overwriteCustomTheme(id);

  List<CustomTheme> get overwriteCandidates => customThemes.toList();

  CustomTheme? get defaultOverwriteTarget {
    if (customThemes.isEmpty) return null;
    final String? editing = _editingCustomId;
    if (editing != null) {
      final int i = customThemes.indexWhere((CustomTheme t) => t.id == editing);
      if (i >= 0) return customThemes[i];
    }
    final String? cur = currentCustomId.value;
    if (cur != null) {
      final int i = customThemes.indexWhere((CustomTheme t) => t.id == cur);
      if (i >= 0) return customThemes[i];
    }
    return customThemes.first;
  }

  Future<void> renameCustomTheme(String id, String name) async {
    final int i = customThemes.indexWhere((CustomTheme t) => t.id == id);
    if (i < 0) return;
    final String old = customThemes[i].name;
    customThemes[i] = customThemes[i].copyWith(name: name);
    customThemes.refresh();
    await _persistCustomThemes();
    AppLog.instance.op('重命名自定义主题：$old → $name');
  }

  Future<void> deleteCustomTheme(String id) async {
    final int at = customThemes.indexWhere((CustomTheme t) => t.id == id);
    final String name = at >= 0 ? customThemes[at].name : id;
    customThemes.removeWhere((CustomTheme t) => t.id == id);
    if (currentCustomId.value == id) {
      currentCustomId.value = null;
      _persistCurrentCustomId();
    }
    if (_editingCustomId == id) _editingCustomId = null;
    await _persistCustomThemes();
    AppLog.instance.op('删除自定义主题：$name');
  }

  void _writeAppearance(CustomTheme t) {
    final bool prevUse = useCustom.value;
    final String? prevId = currentCustomId.value;
    final String? prevPreset = currentPreset.value;
    applySpec(ThemePreset(
      id: t.id,
      name: t.name,
      descriptor: '',
      themeMode: t.themeMode,
      seed: t.seed,
      bgMode: t.bgMode,
      gradient1: t.gradient1,
      gradient2: t.gradient2,
      bgImage: t.bgImage,
      glass: t.componentOpacity > 0,
    ));

    setComponentOpacity(t.componentOpacity);
    pageColors.clear();
    for (final MapEntry<String, int> e in t.pageColors.entries) {
      pageColors[e.key] = Color(e.value);
    }
    pageColors.refresh();
    useCustom.value = prevUse;
    currentCustomId.value = prevId;

    currentPreset.value = prevPreset;
  }

  void applyCustomTheme(CustomTheme t) {
    _writeAppearance(t);

    clearPreset();
    currentCustomId.value = t.id;
    useCustom.value = true;

    Formatter.saveGlobalData(_kUseCustom, true);
    _persistCurrentCustomId();
    AppLog.instance.op('应用自定义主题：${t.name}（seed $_seedHex）');
  }

  void _persistCurrentCustomId() =>
      Formatter.saveGlobalData(_kCurrentCustomId, currentCustomId.value);

  bool isCustomThemeSelected(CustomTheme t) =>
      useCustom.value && currentCustomId.value == t.id;

  Future<void> _persistCustomThemes() => Formatter.saveGlobalData(
        _kCustomThemes,
        jsonEncode(customThemes.map((CustomTheme t) => t.toJson()).toList()),
      );

  Future<void> _loadCustomThemes() async {
    final Object? raw = await Formatter.getGlobalData(_kCustomThemes);
    if (raw is! String || raw.isEmpty) return;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final List<CustomTheme> loaded = <CustomTheme>[];
      bool migrated = false;
      for (final dynamic e in decoded) {
        if (e is! Map<String, dynamic>) continue;
        final CustomTheme? t = CustomTheme.fromJson(e);
        if (t == null) continue;
        loaded.add(t);

        if (CustomTheme.needsOpacityMigration(e)) migrated = true;
      }
      customThemes.assignAll(loaded);
      if (migrated) await _persistCustomThemes();
    } catch (_) {
    }
  }

  String exportPackFileName([DateTime? now]) =>
      ThemePack(themes: const <CustomTheme>[], exportedAt: now ?? DateTime.now())
          .suggestedFileName();

  String buildExportPack() =>
      ThemePack(themes: customThemes.toList()).encode();

  Future<ThemeImportOutcome> applyImportedThemes(
    List<CustomTheme> incoming, {
    required bool overwrite,
  }) async {
    int added = 0;
    int replaced = 0;
    CustomTheme? first;
    for (int i = 0; i < incoming.length; i++) {
      final CustomTheme t = incoming[i];
      final int at = overwrite
          ? customThemes.indexWhere((CustomTheme x) => x.name == t.name)
          : -1;
      if (at >= 0) {
        final CustomTheme merged =
            t.withIdentity(id: customThemes[at].id, name: t.name);
        customThemes[at] = merged;
        replaced++;
        first ??= merged;
        continue;
      }
      final String name = customThemes.any((CustomTheme x) => x.name == t.name)
          ? '${t.name}${S.themeImportNameSuffix}'
          : t.name;
      final CustomTheme fresh = t.withIdentity(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}-$i',
        name: name,
      );
      customThemes.add(fresh);
      added++;
      first ??= fresh;
    }
    customThemes.refresh();
    await _persistCustomThemes();
    AppLog.instance.op(
      '导入自定义主题：新增 $added 套、覆盖 $replaced 套',
    );
    return ThemeImportOutcome(
      added: added,
      replaced: replaced,
      first: first,
    );
  }

  List<String> conflictingNames(List<CustomTheme> incoming) {
    final Set<String> mine = customThemes.map((CustomTheme t) => t.name).toSet();
    final List<String> hit = <String>[];
    for (final CustomTheme t in incoming) {
      if (mine.contains(t.name) && !hit.contains(t.name)) hit.add(t.name);
    }
    return hit;
  }

  void applySpec(ThemePreset p) {
    _applyingPreset = true;
    try {
      if (p.builtin) {
        clearPreset();
      } else {
        currentPreset.value = p.id;
      }
      setThemeMode(p.themeMode);
      setSeed(p.seed);

      _bgMode.value = p.bgMode;
      Formatter.saveGlobalData(_kBgMode, _bgMode.value);
      _gradient1.value = p.gradient1;
      _gradient2.value = p.gradient2;
      _writeColor(_kGrad1, p.gradient1);
      _writeColor(_kGrad2, p.gradient2);

      _setPageBgImage(p.bgImage ?? defaultBackgroundImage);

      setComponentOpacity(p.glass ? glassPanelTransparency : 0.0);
      setFontColor(null);

      _clearPageStyles();

      _resetGlobalBg();

      useCustom.value = false;
      Formatter.saveGlobalData(_kUseCustom, false);
      Formatter.saveGlobalData(_kPreset, p.builtin ? null : p.id);
    } finally {
      _applyingPreset = false;
    }
    _apply();
  }

  bool isBuiltinMode(int mode) =>
      !useCustom.value &&
      currentPreset.value == null &&
      themeMode.value == mode;

  bool get isCustomSelected =>
      useCustom.value &&
      currentPreset.value == null &&
      currentCustomId.value == null;

  void clearPreset() {
    currentPreset.value = null;
    Formatter.saveGlobalData(_kPreset, null);
  }

  void _setPageBgImage(String path) {
    _pageBgImage.value = path;
    Formatter.saveBackgroundImage(path);

    _markCustom();
  }

  void setMenuImage(String path) {
    menuImagePath.value = path;
    Formatter.saveMenuBackgroundImage(path);

    _markCustom();
  }

  static ImageProvider<Object> imageProviderFor(String path) {
    if (path.startsWith('assets/')) {
      return AssetImage(path) as ImageProvider<Object>;
    }
    if (path.startsWith('content://')) {
      return FileImage(File(path));
    }
    return FileImage(File(path));
  }

  void setMenuBgBrightness(double v) {
    menuBgBrightness.value = v.clamp(-1.0, 1.0);
    Formatter.saveGlobalData(_kMenuBgBrightness, menuBgBrightness.value);
  }

  void setMenuBgFade(double v) {
    menuBgFade.value = v.clamp(0.0, 1.0);
    Formatter.saveGlobalData(_kMenuBgFade, menuBgFade.value);
  }

  void setMenuBgBlur(double v) {
    menuBgBlur.value = v.clamp(0.0, 20.0);
    Formatter.saveGlobalData(_kMenuBgBlur, menuBgBlur.value);
  }

  void setGlobalBgEnabled(bool on) {
    globalBgEnabled.value = on;
    Formatter.saveGlobalData(_kGlobalBgOn, on);

    if (on) _markCustom();
  }

  void setGlobalBgImage(String path) {
    globalBgImagePath.value = path;
    Formatter.saveGlobalData(_kGlobalBgPath, path);
    _markCustom();
  }

  void setGlobalBgBrightness(double v) {
    globalBgBrightness.value = v.clamp(-1.0, 1.0);
    Formatter.saveGlobalData(_kGlobalBgBrightness, globalBgBrightness.value);
  }

  void setGlobalBgFade(double v) {
    globalBgFade.value = v.clamp(0.0, 1.0);
    Formatter.saveGlobalData(_kGlobalBgFade, globalBgFade.value);
  }

  void setGlobalBgBlur(double v) {
    globalBgBlur.value = v.clamp(0.0, 20.0);
    Formatter.saveGlobalData(_kGlobalBgBlur, globalBgBlur.value);
  }

  void setComponentOpacity(double v) {
    componentOpacity.value = v.clamp(0.0, 1.0);

    Formatter.saveGlobalData(_kTransparency, componentOpacity.value);
  }

  void setGlassEnabled(bool on) =>
      setComponentOpacity(on ? glassPanelTransparency : 0.0);

  DecorationImage? get globalBgDecorationImage {
    if (!globalBgEnabled.value) return null;

    final String? p = globalBgImagePath.value;
    if (p == null || p.isEmpty) return null;

    return DecorationImage(image: imageProviderFor(p), fit: BoxFit.cover);
  }

  DecorationImage? get renderGlobalBgDecorationImage {
    final _ThemeDraft? d = _draft.value;
    final bool on = d?.globalBgEnabled ?? globalBgEnabled.value;
    final String? p = d == null ? globalBgImagePath.value : d.globalBgImage;
    if (!on || p == null || p.isEmpty) return null;
    return DecorationImage(image: imageProviderFor(p), fit: BoxFit.cover);
  }

  double get renderGlobalBgBrightness {
    final _ThemeDraft? d = _draft.value;
    final double live = globalBgBrightness.value;
    return d?.globalBgBrightness ?? live;
  }

  double get renderGlobalBgFade {
    final _ThemeDraft? d = _draft.value;
    final double live = globalBgFade.value;
    return d?.globalBgFade ?? live;
  }

  double get renderGlobalBgBlur {
    final _ThemeDraft? d = _draft.value;
    final double live = globalBgBlur.value;
    return d?.globalBgBlur ?? live;
  }

  void _apply() => Get.changeThemeMode(materialMode);
}

class _ThemeDraft {
  const _ThemeDraft({
    required this.themeMode,
    required this.seed,
    required this.fontColor,
    required this.bgMode,
    required this.gradient1,
    required this.gradient2,
    required this.bgImage,
    required this.componentOpacity,
    required this.pageColors,
    required this.menuImage,
    required this.menuBgBrightness,
    required this.menuBgFade,
    required this.menuBgBlur,
    required this.globalBgEnabled,
    required this.globalBgImage,
    required this.globalBgBrightness,
    required this.globalBgFade,
    required this.globalBgBlur,
  });

  final int themeMode;
  final Color seed;
  final Color? fontColor;
  final int bgMode;
  final Color gradient1;
  final Color gradient2;
  final String? bgImage;
  final double componentOpacity;
  final Map<String, int> pageColors;

  final String? menuImage;
  final double menuBgBrightness;
  final double menuBgFade;
  final double menuBgBlur;

  final bool globalBgEnabled;
  final String? globalBgImage;
  final double globalBgBrightness;
  final double globalBgFade;
  final double globalBgBlur;
}
