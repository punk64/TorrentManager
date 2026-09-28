import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF282828);
  static const Color darkSurfaceVariant = Color(0xFF464646);

  static const Color lightScaffold = Color(0xFFFFFFFF);
  static const Color darkScaffold = Color(0xFF000000);

  static const Color darkDrawer = Color(0xFF1B1B1F);

  static const Color chartBlue = Color(0xFFAABEFF);
  static const Color chartBlueAlt = Color(0xFFA0B4E1);
  static const Color chartPink = Color(0xFFE1D2E1);

  static const double baseFontSize = 10;

  static const double gap = 10;

  static const double iconSize = 20;

  static const double radius = 10;

  static const double radiusSmall = 6;

  static const double radiusBar = 2;

  static const double radiusTiny = 3;

  static const double radiusSheet = 20;

  static const double cardLuminanceShift = 0.04;

  static const double cardBorderOpacity = 0.16;

  static const double cardBorderWidth = 0.5;

  static const double sectionTintShift = 0.03;

  static Color cardBorder(ColorScheme scheme) =>
      scheme.outlineVariant.withValues(alpha: cardBorderOpacity);

  static double lightnessOf(Color c) => HSLColor.fromColor(c).lightness;

  static Color shiftLightness(Color c, double delta) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }

  static Color cardSurfaceFrom(Color background, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color shifted = shiftLightness(
      background,
      isDark ? cardLuminanceShift : -cardLuminanceShift,
    );
    if (!isDark) return shifted;
    return lightnessOf(darkSurface) > lightnessOf(shifted) ? darkSurface : shifted;
  }

  static const int maxLenName = 64;
  static const int maxLenHost = 128;
  static const int maxLenPort = 5;
  static const int maxLenPath = 256;
  static const int maxLenUrl = 2000;
  static const int maxLenUrls = 8192;

  static const int maxLenJson = 100000;

  static const int maxLenGeneral = 64;

  static Widget? noCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) =>
      null;

  static ColorFilter saturationFilter(double s) {
    final double v = s.clamp(0.0, 1.0);
    const double r = 0.2126, g = 0.7152, b = 0.0722;
    final double ir = r * (1 - v), ig = g * (1 - v), ib = b * (1 - v);
    return ColorFilter.matrix(<double>[
      ir + v, ig, ib, 0, 0,
      ir, ig + v, ib, 0, 0,
      ir, ig, ib + v, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }

  static const List<Color> seedColors = <Color>[
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFC62828),
    Color(0xFF6A1B9A),
    Color(0xFFEF6C00),
    Color(0xFF00838F),
    Color(0xFF282828),
    Color(0xFF464646),
  ];

  static Color contrastOn(Color background) =>
      background.computeLuminance() > 0.179
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFE6E6E6);

  static Color defaultFontColor(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFFE6E6E6)
          : const Color(0xFF1A1A1A);

  static ThemeData of(
    Color seed,
    Brightness brightness, {
    Color? fontColor,
    Color? background,
    bool transparentScaffold = false,
    double? glassAlpha,
    PresetSchemeOverride? schemeOverride,
  }) {
    final ColorScheme seeded = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final bool isDark = brightness == Brightness.dark;
    final PresetSchemeOverride? ov = schemeOverride;

    final Color text =
        fontColor ?? ov?.onSurface ?? defaultFontColor(brightness);

    final bool glass = glassAlpha != null;
    final double ga = (glassAlpha ?? 1.0).clamp(0.0, 1.0);
    // 有覆盖时玻璃底取主题色阶，替代写死的 darkSurface/lightScaffold。
    final Color glassSurface =
        (ov?.surfaceLow ?? (isDark ? darkSurface : lightScaffold))
            .withValues(alpha: ga);

    final Color pageBase =
        background ?? (isDark ? darkScaffold : lightScaffold);

    final Color cardBase =
        glass ? glassSurface : cardSurfaceFrom(pageBase, brightness);

    final double dir = isDark ? cardLuminanceShift : -cardLuminanceShift;
    Color step(double ratio) =>
        glass ? cardBase : shiftLightness(cardBase, dir * ratio);

    final Color surfaceLowest =
        ov != null ? ov.surfaceLowest.withValues(alpha: ga) : step(0.0);
    final Color surfaceContainer =
        ov != null ? ov.surfaceContainer.withValues(alpha: ga) : step(0.35);
    final Color surfaceHigh =
        ov != null ? ov.surfaceHigh.withValues(alpha: ga) : step(0.7);
    final Color surfaceHighest =
        ov != null ? ov.surfaceHighest.withValues(alpha: ga) : step(1.1);

    final ColorScheme scheme = ov == null
        ? seeded
        : seeded.copyWith(
            primary: ov.primary,
            onPrimary: ov.onPrimary,
            primaryContainer: ov.primaryContainer,
            onPrimaryContainer: ov.onPrimaryContainer,
            secondary: ov.secondary,
            onSecondary: ov.onSecondary,
            secondaryContainer: ov.secondaryContainer,
            onSecondaryContainer: ov.onSecondaryContainer,
            tertiary: ov.tertiary,
            onTertiary: ov.onTertiary,
            tertiaryContainer: ov.tertiaryContainer,
            onTertiaryContainer: ov.onTertiaryContainer,
            error: ov.error,
            onError: ov.onError,
            errorContainer: ov.errorContainer,
            onErrorContainer: ov.onErrorContainer,
            onSurface: ov.onSurface,
            onSurfaceVariant: ov.onSurfaceVariant,
            outline: ov.outline,
            outlineVariant: ov.outlineVariant,
            inversePrimary: ov.inversePrimary,
            inverseSurface: ov.inverseSurface,
            onInverseSurface: ov.onInverseSurface,
          );

    final Color barBase = glass ? cardBase : shiftLightness(pageBase, dir);
    final Color sheetBase = cardBase;
    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        surface: cardBase,

        surfaceContainerLowest: surfaceLowest,

        surfaceContainerLow: cardBase,
        surfaceContainer: surfaceContainer,
        surfaceContainerHigh: surfaceHigh,
        surfaceContainerHighest: surfaceHighest,

        surfaceTint: glass ? Colors.transparent : scheme.surfaceTint,
      ),

      scaffoldBackgroundColor: transparentScaffold ? Colors.transparent : pageBase,

      appBarTheme: AppBarThemeData(
        backgroundColor: barBase,
        foregroundColor: text,
        iconTheme: IconThemeData(color: text),
        actionsIconTheme: IconThemeData(color: text),
      ),

      drawerTheme: DrawerThemeData(backgroundColor: pageBase),

      dialogTheme: DialogThemeData(backgroundColor: sheetBase),
      bottomSheetTheme:
          BottomSheetThemeData(backgroundColor: sheetBase),
      popupMenuTheme: PopupMenuThemeData(color: sheetBase),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color?>(sheetBase),
        ),
      ),
      visualDensity: VisualDensity.compact,
      splashFactory: InkRipple.splashFactory,

      cardTheme: CardThemeData(

        color: cardBase,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),

          side: BorderSide(
            color: cardBorder(scheme),
            width: cardBorderWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: text,
        displayColor: text,
        decorationColor: text,
      ),
      iconTheme: base.iconTheme.copyWith(color: text),
      primaryIconTheme: base.primaryIconTheme.copyWith(color: text),
    );
  }

  static ThemeData get light => of(seedColors.first, Brightness.light);
  static ThemeData get dark => of(seedColors.first, Brightness.dark);

  /// 图表色序列：预设带显式配色时用该套图表色，否则走全局默认（中性蓝粉 + 主题三色）。
  static List<Color> chartColors(ColorScheme cs,
      [PresetSchemeOverride? schemeOverride]) {
    final List<Color>? o = schemeOverride?.chart;
    if (o != null) return o;
    return <Color>[
      chartBlue,
      chartBlueAlt,
      chartPink,
      cs.primary,
      cs.secondary,
      cs.tertiary,
    ];
  }

  static String alphaLabel(double v) => '${(v * 100).round()}%';
}

/// 5 个语义度量色（上传 / 下载 / 活跃 / peer / 错误）的按主题定稿值。
/// 深色玻璃组并入 [PresetSchemeOverride.sems]；浅色组组件色保持 fromSeed，
/// 只通过 [ThemePreset.semanticOverride] 单独覆盖这 5 色。
class PresetSemanticColors {
  const PresetSemanticColors({
    required this.upload,
    required this.download,
    required this.active,
    required this.peer,
    required this.error,
  });

  final Color upload;
  final Color download;
  final Color active;
  final Color peer;
  final Color error;
}

/// 预设主题的显式配色覆盖：非空时整套 ColorScheme 用显式色替代 fromSeed 派生。
///
/// 深色玻璃组 6 套使用（2026-09-28 自 PT Friends 第 26/27 轮「12 套主题配色重设计」同步）：
/// surface 五阶为玻璃底色阶，落地时统一叠 [ThemePreset.glassAlpha]；
/// [sems] 为该套语义度量色；`chart` 为该套图表色序列。
/// error 四色与 inverseSurface 两色六套共用，给默认值。
class PresetSchemeOverride {
  const PresetSchemeOverride({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.inversePrimary,
    required this.surfaceLowest,
    required this.surfaceLow,
    required this.surfaceContainer,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.sems,
    required this.chart,
    this.error = const Color(0xFFFFB4BB),
    this.onError = const Color(0xFF690015),
    this.errorContainer = const Color(0xFF930020),
    this.onErrorContainer = const Color(0xFFFFDADF),
    this.inverseSurface = const Color(0xFFE9DEF2),
    this.onInverseSurface = const Color(0xFF2A2033),
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color inversePrimary;
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;

  /// 玻璃底五阶：lowest / low（卡片·栏·面板）/ container / high / highest。
  final Color surfaceLowest;
  final Color surfaceLow;
  final Color surfaceContainer;
  final Color surfaceHigh;
  final Color surfaceHighest;

  /// 语义度量色（上传 / 下载 / 活跃 / peer / 错误），最终渲染色。
  final PresetSemanticColors sems;

  /// 图表色序列（跟踪页柱状图等）。
  final List<Color> chart;
}

class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.name,
    required this.descriptor,
    required this.themeMode,
    required this.seed,
    required this.bgMode,
    required this.gradient1,
    required this.gradient2,
    this.bgImage,
    this.wallpaper = false,
    this.glass = false,
    this.builtin = false,
    this.schemeOverride,
    this.semanticOverride,
    this.glassAlpha,
  });

  final String id;
  final String name;
  final String descriptor;
  final int themeMode;
  final Color seed;
  final int bgMode;
  final Color gradient1;
  final Color gradient2;

  final String? bgImage;

  final bool wallpaper;

  final bool glass;

  final bool builtin;

  /// 显式配色覆盖；非空时 [AppTheme.of] 用它替代 fromSeed 派生整套 ColorScheme。
  final PresetSchemeOverride? schemeOverride;

  /// 仅 5 语义度量色的独立覆盖（浅色组用：组件色保持 fromSeed 机制）。
  final PresetSemanticColors? semanticOverride;

  /// 玻璃不透明度（0~1）。深色玻璃组 0.78（组件不透明度 0.22）；
  /// 为空时沿用 [ThemeController.glassPanelTransparency] 对应的旧默认。
  final double? glassAlpha;

  /// 语义色覆盖取用：独立浅色覆盖优先级与深色组内嵌值互斥，二选一。
  PresetSemanticColors? get effectiveSemantics =>
      semanticOverride ?? schemeOverride?.sems;

  BoxDecoration get preview => bgImage == null
      ? BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[gradient1, gradient2],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        )
      : BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          image: DecorationImage(
            image: AssetImage(bgImage!),
            fit: BoxFit.cover,

            colorFilter: const ColorFilter.mode(
              Color(0x14FFFFFF),
              BlendMode.srcOver,
            ),
          ),
        );
}

class CustomTheme {
  const CustomTheme({
    required this.id,
    required this.name,
    required this.themeMode,
    required this.seed,
    required this.fontColor,
    required this.bgMode,
    required this.gradient1,
    required this.gradient2,
    this.bgImage,
    required this.componentOpacity,
    required this.pageColors,
  });

  final String id;
  final String name;

  final int themeMode;

  final Color seed;

  final Color? fontColor;

  final int bgMode;
  final Color gradient1;
  final Color gradient2;
  final String? bgImage;

  final double componentOpacity;

  final Map<String, int> pageColors;

  static const int opacitySemantics = 2;

  CustomTheme copyWith({String? name, double? componentOpacity}) => CustomTheme(
        id: id,
        name: name ?? this.name,
        themeMode: themeMode,
        seed: seed,
        fontColor: fontColor,
        bgMode: bgMode,
        gradient1: gradient1,
        gradient2: gradient2,
        bgImage: bgImage,
        componentOpacity: componentOpacity ?? this.componentOpacity,
        pageColors: pageColors,
      );

  CustomTheme withIdentity({required String id, required String name}) =>
      CustomTheme(
        id: id,
        name: name,
        themeMode: themeMode,
        seed: seed,
        fontColor: fontColor,
        bgMode: bgMode,
        gradient1: gradient1,
        gradient2: gradient2,
        bgImage: bgImage,
        componentOpacity: componentOpacity,
        pageColors: pageColors,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'themeMode': themeMode,
        'seed': seed.toARGB32(),
        'fontColor': fontColor?.toARGB32(),
        'bgMode': bgMode,
        'gradient1': gradient1.toARGB32(),
        'gradient2': gradient2.toARGB32(),
        'bgImage': bgImage,
        'componentOpacity': componentOpacity,

        'opacitySemantics': opacitySemantics,
        'pageColors': pageColors,
      };

  static bool needsOpacityMigration(Map<String, dynamic> j) {
    final Object? v = j['opacitySemantics'];
    final int sem = v is num ? v.toInt() : 1;
    return sem < opacitySemantics;
  }

  static double _readOpacity(Map<String, dynamic> j) {
    final Object? v = j['componentOpacity'];
    final double raw = v is num ? v.toDouble() : 0.0;
    if (!needsOpacityMigration(j)) return raw.clamp(0.0, 1.0);

    return (1.0 - raw).clamp(0.0, 1.0);
  }

  static CustomTheme? fromJson(Map<String, dynamic> j) {
    final Object? id = j['id'];
    final Object? name = j['name'];
    final Object? seed = j['seed'];
    if (id is! String || name is! String || seed is! int) return null;
    final Object? g1 = j['gradient1'];
    final Object? g2 = j['gradient2'];
    final Object? fc = j['fontColor'];
    final Object? colors = j['pageColors'];
    return CustomTheme(
      id: id,
      name: name,
      themeMode: j['themeMode'] is int ? j['themeMode'] as int : 1,
      seed: Color(seed),
      fontColor: fc is int ? Color(fc) : null,
      bgMode: j['bgMode'] is int ? j['bgMode'] as int : 0,
      gradient1: Color(g1 is int ? g1 : seed),
      gradient2: Color(g2 is int ? g2 : seed),
      bgImage: j['bgImage'] is String ? j['bgImage'] as String : null,

      componentOpacity: _readOpacity(j),
      pageColors: <String, int>{
        if (colors is Map)
          for (final MapEntry<dynamic, dynamic> e in colors.entries)
            if (e.key is String && e.value is int)
              e.key as String: e.value as int,
      },
    );
  }

  BoxDecoration get swatch => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[gradient1, gradient2],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
        border: Border.all(color: seed, width: 2),
      );
}

const List<ThemePreset> presets = <ThemePreset>[

  ThemePreset(
    id: 'snow_plum',
    name: '粉樱',
    descriptor: '浅粉',
    themeMode: 1,
    seed: Color(0xFFC2185B),
    bgMode: 1,
    gradient1: Color(0xFFFFF5F8),
    gradient2: Color(0xFFF4C2D3),
    semanticOverride: PresetSemanticColors(
      upload: Color(0xFF216340),
      download: Color(0xFFA12B48),
      active: Color(0xFF25599D),
      peer: Color(0xFF86348D),
      error: Color(0xFF962C73),
    ),
  ),

  ThemePreset(
    id: 'green_bamboo',
    name: '青筠',
    descriptor: '浅绿',
    themeMode: 1,
    seed: Color(0xFF2E7D32),
    bgMode: 1,
    gradient1: Color(0xFFF2F9F3),
    gradient2: Color(0xFFBFE0C8),
    semanticOverride: PresetSemanticColors(
      upload: Color(0xFF237046),
      download: Color(0xFFA12B4C),
      active: Color(0xFF2962AE),
      peer: Color(0xFF86348D),
      error: Color(0xFF962C73),
    ),
  ),

  ThemePreset(
    id: 'blue_sky',
    name: '晴空',
    descriptor: '浅蓝',
    themeMode: 1,
    seed: Color(0xFF1565C0),
    bgMode: 1,
    gradient1: Color(0xFFF0F7FE),
    gradient2: Color(0xFFB7D4F1),
    semanticOverride: PresetSemanticColors(
      upload: Color(0xFF256A47),
      download: Color(0xFFA12B4C),
      active: Color(0xFF275DB0),
      peer: Color(0xFF86348D),
      error: Color(0xFF962C73),
    ),
  ),

  ThemePreset(
    id: 'orange_warm',
    name: '暖橙',
    descriptor: '浅橙',
    themeMode: 1,
    seed: Color(0xFFDD5A00),
    bgMode: 1,
    gradient1: Color(0xFFFFF4E8),
    gradient2: Color(0xFFF8C79E),
    semanticOverride: PresetSemanticColors(
      upload: Color(0xFF246647),
      download: Color(0xFFA3293D),
      active: Color(0xFF275D9B),
      peer: Color(0xFF82368C),
      error: Color(0xFF952D6D),
    ),
  ),

  ThemePreset(
    id: 'purple_mood',
    name: '紫霞',
    descriptor: '浅紫',
    themeMode: 1,
    seed: Color(0xFF6C1FA4),
    bgMode: 1,
    gradient1: Color(0xFFF5EFFB),
    gradient2: Color(0xFFD5BEEC),
    semanticOverride: PresetSemanticColors(
      upload: Color(0xFF246142),
      download: Color(0xFF972B4F),
      active: Color(0xFF255493),
      peer: Color(0xFF83328F),
      error: Color(0xFF932F75),
    ),
  ),

  ThemePreset(
    id: 'dark_sky',
    name: '云青',
    descriptor: '浅灰蓝',
    themeMode: 1,
    seed: Color(0xFF3A4A55),
    bgMode: 1,
    gradient1: Color(0xFFF0F4F6),
    gradient2: Color(0xFFC2D3DA),
    semanticOverride: PresetSemanticColors(
      upload: Color(0xFF296A4F),
      download: Color(0xFF9F2D4D),
      active: Color(0xFF296199),
      peer: Color(0xFF84368C),
      error: Color(0xFF932F72),
    ),
  ),

  // 深色玻璃组 6 套（2026-09-28 重设计落地，自 PT Friends 第 26/27 轮同步）：
  // 壁纸同相深色玻璃 + 浅字，16 色显式 ColorScheme + 5 语义色 + 图表色；
  // 组件不透明度 0.22（glassAlpha 0.78）。

  ThemePreset(
    id: 'wp_shell',
    name: '零 · 幽魂',
    descriptor: '青蓝壁纸',
    themeMode: 2,
    seed: Color(0xFF2E9BD6),
    bgMode: 2,
    gradient1: Color(0xFF0A1A24),
    gradient2: Color(0xFF2E5D7A),
    bgImage: 'assets/images/wallpapers/wp_shell.webp',
    wallpaper: true,
    glass: true,
    glassAlpha: 0.78,
    schemeOverride: PresetSchemeOverride(
      primary: Color(0xFF6FC6F2),
      onPrimary: Color(0xFF00344B),
      primaryContainer: Color(0xFF0E4A66),
      onPrimaryContainer: Color(0xFFC2E8FF),
      secondary: Color(0xFFB9C7DA),
      onSecondary: Color(0xFF232F3E),
      secondaryContainer: Color(0xFF39485E),
      onSecondaryContainer: Color(0xFFDCE4F0),
      tertiary: Color(0xFFF2938F),
      onTertiary: Color(0xFF4C0E10),
      tertiaryContainer: Color(0xFF802A2E),
      onTertiaryContainer: Color(0xFFFFDAD6),
      onSurface: Color(0xFFEDF3FA),
      onSurfaceVariant: Color(0xFFBFCADD),
      outline: Color(0xFF8FA0B8),
      outlineVariant: Color(0xFF3D4A60),
      inversePrimary: Color(0xFF1F6E8C),
      surfaceLowest: Color(0xFF141A29),
      surfaceLow: Color(0xFF1B2233),
      surfaceContainer: Color(0xFF222B40),
      surfaceHigh: Color(0xFF2A3450),
      surfaceHighest: Color(0xFF323D5C),
      sems: PresetSemanticColors(
        upload: Color(0xFF73C9A1),
        download: Color(0xFFE495AB),
        active: Color(0xFF96B0E3),
        peer: Color(0xFFD19AD6),
        error: Color(0xFFDF9AC8),
      ),
      chart: <Color>[
        Color(0xFF6FC6F2),
        Color(0xFFB9C7DA),
        Color(0xFFF2938F),
        Color(0xFF3E82B8),
      ],
    ),
  ),

  ThemePreset(
    id: 'wp_violet',
    name: '壹 · 紫焰',
    descriptor: '紫品红壁纸',
    themeMode: 2,
    seed: Color(0xFFC94FA8),
    bgMode: 2,
    gradient1: Color(0xFF150A14),
    gradient2: Color(0xFF6E3A66),
    bgImage: 'assets/images/wallpapers/wp_violet.webp',
    wallpaper: true,
    glass: true,
    glassAlpha: 0.78,
    schemeOverride: PresetSchemeOverride(
      primary: Color(0xFFF47AD9),
      onPrimary: Color(0xFF43003B),
      primaryContainer: Color(0xFF6E2462),
      onPrimaryContainer: Color(0xFFFFD7F6),
      secondary: Color(0xFFD5BCE6),
      onSecondary: Color(0xFF3B2549),
      secondaryContainer: Color(0xFF533D66),
      onSecondaryContainer: Color(0xFFF0E3FB),
      tertiary: Color(0xFF5CE0D3),
      onTertiary: Color(0xFF003733),
      tertiaryContainer: Color(0xFF0F5751),
      onTertiaryContainer: Color(0xFFA5F3EA),
      onSurface: Color(0xFFF2EAF6),
      onSurfaceVariant: Color(0xFFC9B8D4),
      outline: Color(0xFFA08FB0),
      outlineVariant: Color(0xFF4E405E),
      inversePrimary: Color(0xFF8E3A85),
      surfaceLowest: Color(0xFF1D1229),
      surfaceLow: Color(0xFF241833),
      surfaceContainer: Color(0xFF2B1F3D),
      surfaceHigh: Color(0xFF332748),
      surfaceHighest: Color(0xFF3B2F53),
      sems: PresetSemanticColors(
        upload: Color(0xFF72CA9B),
        download: Color(0xFFDF8692),
        active: Color(0xFF7CAADE),
        peer: Color(0xFFD19AD6),
        error: Color(0xFFDB94BA),
      ),
      chart: <Color>[
        Color(0xFFF47AD9),
        Color(0xFF5CE0D3),
        Color(0xFFC9B8D4),
        Color(0xFF9C6BD0),
      ],
    ),
  ),

  ThemePreset(
    id: 'wp_rain',
    name: '贰 · 雨夜',
    descriptor: '冷蓝壁纸',
    themeMode: 2,
    seed: Color(0xFF2E8EB8),
    bgMode: 2,
    gradient1: Color(0xFF0B1418),
    gradient2: Color(0xFF2C4A5A),
    bgImage: 'assets/images/wallpapers/wp_rain.webp',
    wallpaper: true,
    glass: true,
    glassAlpha: 0.78,
    schemeOverride: PresetSchemeOverride(
      primary: Color(0xFF6ADCE4),
      onPrimary: Color(0xFF00343A),
      primaryContainer: Color(0xFF0E4E58),
      onPrimaryContainer: Color(0xFFB8F1F7),
      secondary: Color(0xFFB5CCD6),
      onSecondary: Color(0xFF22343C),
      secondaryContainer: Color(0xFF374B54),
      onSecondaryContainer: Color(0xFFD5E5EC),
      tertiary: Color(0xFF82DCC0),
      onTertiary: Color(0xFF00382C),
      tertiaryContainer: Color(0xFF0F5A46),
      onTertiaryContainer: Color(0xFFB5F2E2),
      onSurface: Color(0xFFE9F2F5),
      onSurfaceVariant: Color(0xFFBACBD2),
      outline: Color(0xFF8CA6B2),
      outlineVariant: Color(0xFF39505B),
      inversePrimary: Color(0xFF2E6B8E),
      surfaceLowest: Color(0xFF121B21),
      surfaceLow: Color(0xFF18242B),
      surfaceContainer: Color(0xFF1F2D36),
      surfaceHigh: Color(0xFF263641),
      surfaceHighest: Color(0xFF2E404E),
      sems: PresetSemanticColors(
        upload: Color(0xFF72CBA1),
        download: Color(0xFFDF86A4),
        active: Color(0xFF7EB4DD),
        peer: Color(0xFFD29BD4),
        error: Color(0xFFDD92C2),
      ),
      chart: <Color>[
        Color(0xFF6ADCE4),
        Color(0xFFB5CCD6),
        Color(0xFF82DCC0),
        Color(0xFF4E93B8),
      ],
    ),
  ),

  ThemePreset(
    id: 'wp_amber',
    name: '叁 · 金辉',
    descriptor: '暖金壁纸',
    themeMode: 2,
    seed: Color(0xFFD29A3A),
    bgMode: 2,
    gradient1: Color(0xFF241F16),
    gradient2: Color(0xFF6B5A33),
    bgImage: 'assets/images/wallpapers/wp_amber.webp',
    wallpaper: true,
    glass: true,
    glassAlpha: 0.78,
    schemeOverride: PresetSchemeOverride(
      primary: Color(0xFFF0C069),
      onPrimary: Color(0xFF3E2A00),
      primaryContainer: Color(0xFF6E4A10),
      onPrimaryContainer: Color(0xFFFFDFA8),
      secondary: Color(0xFFDCC9A8),
      onSecondary: Color(0xFF3A2F1B),
      secondaryContainer: Color(0xFF55462C),
      onSecondaryContainer: Color(0xFFF6E8CE),
      tertiary: Color(0xFFF29A6B),
      onTertiary: Color(0xFF4A1C00),
      tertiaryContainer: Color(0xFF7A3A14),
      onTertiaryContainer: Color(0xFFFFDBCC),
      onSurface: Color(0xFFF7F0E3),
      onSurfaceVariant: Color(0xFFD3C6AE),
      outline: Color(0xFFB3A184),
      outlineVariant: Color(0xFF55472E),
      inversePrimary: Color(0xFFA6791C),
      surfaceLowest: Color(0xFF201A10),
      surfaceLow: Color(0xFF2A2216),
      surfaceContainer: Color(0xFF332A1C),
      surfaceHigh: Color(0xFF3D3323),
      surfaceHighest: Color(0xFF483C2A),
      sems: PresetSemanticColors(
        upload: Color(0xFF77C5A5),
        download: Color(0xFFE0909D),
        active: Color(0xFF83ADD8),
        peer: Color(0xFFCB9BD4),
        error: Color(0xFFDB94BE),
      ),
      chart: <Color>[
        Color(0xFFF0C069),
        Color(0xFFDCC9A8),
        Color(0xFFF29A6B),
        Color(0xFFA8842F),
      ],
    ),
  ),

  ThemePreset(
    id: 'wp_teal',
    name: '肆 · 青灯',
    descriptor: '青绿壁纸',
    themeMode: 2,
    seed: Color(0xFF35A26B),
    bgMode: 2,
    gradient1: Color(0xFF0C1418),
    gradient2: Color(0xFF2E6B70),
    bgImage: 'assets/images/wallpapers/wp_teal.webp',
    wallpaper: true,
    glass: true,
    glassAlpha: 0.78,
    schemeOverride: PresetSchemeOverride(
      primary: Color(0xFF7FDCAC),
      onPrimary: Color(0xFF00391F),
      primaryContainer: Color(0xFF0F5330),
      onPrimaryContainer: Color(0xFFB9F2CF),
      secondary: Color(0xFFBFD4C3),
      onSecondary: Color(0xFF2A3A2E),
      secondaryContainer: Color(0xFF405546),
      onSecondaryContainer: Color(0xFFDCEEE1),
      tertiary: Color(0xFF7FD4DC),
      onTertiary: Color(0xFF00363B),
      tertiaryContainer: Color(0xFF0E5157),
      onTertiaryContainer: Color(0xFFB2ECF2),
      onSurface: Color(0xFFEBF4EE),
      onSurfaceVariant: Color(0xFFC0D2C6),
      outline: Color(0xFF92AC9C),
      outlineVariant: Color(0xFF3A5246),
      inversePrimary: Color(0xFF1F8C93),
      surfaceLowest: Color(0xFF13201B),
      surfaceLow: Color(0xFF1A2A24),
      surfaceContainer: Color(0xFF21352D),
      surfaceHigh: Color(0xFF293F36),
      surfaceHighest: Color(0xFF314B40),
      sems: PresetSemanticColors(
        upload: Color(0xFF5EC982),
        download: Color(0xFFE59EB2),
        active: Color(0xFF88B2DD),
        peer: Color(0xFFD4A1D9),
        error: Color(0xFFDF9AC8),
      ),
      chart: <Color>[
        Color(0xFF7FDCAC),
        Color(0xFFBFD4C3),
        Color(0xFF7FD4DC),
        Color(0xFF3E9E6B),
      ],
    ),
  ),

  ThemePreset(
    id: 'wp_crimson',
    name: '伍 · 绯霓',
    descriptor: '绯红壁纸',
    themeMode: 2,
    seed: Color(0xFFC94F5E),
    bgMode: 2,
    gradient1: Color(0xFF1A0E12),
    gradient2: Color(0xFF7A3A44),
    bgImage: 'assets/images/wallpapers/wp_crimson.webp',
    wallpaper: true,
    glass: true,
    glassAlpha: 0.78,
    schemeOverride: PresetSchemeOverride(
      primary: Color(0xFFF58AA0),
      onPrimary: Color(0xFF4A0A16),
      primaryContainer: Color(0xFF7A2434),
      onPrimaryContainer: Color(0xFFFFD9DE),
      secondary: Color(0xFFDFC2C6),
      onSecondary: Color(0xFF3E2A2D),
      secondaryContainer: Color(0xFF583F44),
      onSecondaryContainer: Color(0xFFF8E0E3),
      tertiary: Color(0xFFEFA9CF),
      onTertiary: Color(0xFF4B1038),
      tertiaryContainer: Color(0xFF7E2F60),
      onTertiaryContainer: Color(0xFFFFD9F2),
      onSurface: Color(0xFFF8EDEF),
      onSurfaceVariant: Color(0xFFD6C2C6),
      outline: Color(0xFFB08F94),
      outlineVariant: Color(0xFF583F44),
      inversePrimary: Color(0xFFA03A48),
      surfaceLowest: Color(0xFF211417),
      surfaceLow: Color(0xFF2B1B1E),
      surfaceContainer: Color(0xFF332226),
      surfaceHigh: Color(0xFF3D2A2E),
      surfaceHighest: Color(0xFF483238),
      sems: PresetSemanticColors(
        upload: Color(0xFF75C79E),
        download: Color(0xFFE28389),
        active: Color(0xFF81B0DA),
        peer: Color(0xFFD69AD6),
        error: Color(0xFFDA95BD),
      ),
      chart: <Color>[
        Color(0xFFF58AA0),
        Color(0xFFDFC2C6),
        Color(0xFFEFA9CF),
        Color(0xFFB05264),
      ],
    ),
  ),
];

const ThemePreset builtinLight = ThemePreset(
  id: 'builtin_light',
  name: '明亮模式',
  descriptor: '',
  themeMode: 1,
  seed: Color(0xFF1565C0),
  bgMode: 0,
  gradient1: Color(0xFFFFFFFF),
  gradient2: Color(0xFFF0F2F5),
  builtin: true,
);

const ThemePreset builtinDark = ThemePreset(
  id: 'builtin_dark',
  name: '黑暗模式',
  descriptor: '',
  themeMode: 2,
  seed: Color(0xFF1565C0),
  bgMode: 0,
  gradient1: Color(0xFF1B1B1F),
  gradient2: Color(0xFF232329),
  builtin: true,
);

List<ThemePreset> get lightPresets =>
    presets.where((ThemePreset p) => !p.wallpaper).toList(growable: false);

List<ThemePreset> get wallpaperPresets =>
    presets.where((ThemePreset p) => p.wallpaper).toList(growable: false);
