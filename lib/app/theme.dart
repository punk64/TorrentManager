

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
  }) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final bool isDark = brightness == Brightness.dark;
    
    
    final Color text = fontColor ?? defaultFontColor(brightness);
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    final bool glass = glassAlpha != null;
    final Color glassSurface = (isDark ? darkSurface : lightScaffold)
        .withValues(alpha: (glassAlpha ?? 1.0).clamp(0.0, 1.0));
    
    
    
    
    final Color pageBase =
        background ?? (isDark ? darkScaffold : lightScaffold);
    
    
    final Color cardBase =
        glass ? glassSurface : cardSurfaceFrom(pageBase, brightness);
    
    
    final double dir = isDark ? cardLuminanceShift : -cardLuminanceShift;
    Color step(double ratio) =>
        glass ? cardBase : shiftLightness(cardBase, dir * ratio);
    
    
    
    
    
    
    
    
    
    
    
    
    
    final Color barBase = glass ? cardBase : shiftLightness(pageBase, dir);
    final Color sheetBase = cardBase;
    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        surface: cardBase,
        
        surfaceContainerLowest: step(0.0),
        
        surfaceContainerLow: cardBase,
        surfaceContainer: step(0.35),
        surfaceContainerHigh: step(0.7),
        surfaceContainerHighest: step(1.1),
        
        
        
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

  static List<Color> chartColors(ColorScheme cs) => <Color>[
        chartBlue,
        chartBlueAlt,
        chartPink,
        cs.primary,
        cs.secondary,
        cs.tertiary,
      ];

  
  static String alphaLabel(double v) => '${(v * 100).round()}%';
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
    gradient1: Color(0xFFFCE4EE),
    gradient2: Color(0xFFF5B9CE),
  ),
  
  ThemePreset(
    id: 'green_bamboo',
    name: '青筠',
    descriptor: '浅绿',
    themeMode: 1,
    seed: Color(0xFF2E7D32),
    bgMode: 1,
    gradient1: Color(0xFFE4F3E8),
    gradient2: Color(0xFFB7DEC2),
  ),
  
  ThemePreset(
    id: 'blue_sky',
    name: '晴空',
    descriptor: '浅蓝',
    themeMode: 1,
    seed: Color(0xFF1565C0),
    bgMode: 1,
    gradient1: Color(0xFFE2EFFB),
    gradient2: Color(0xFFAECFF0),
  ),
  
  ThemePreset(
    id: 'orange_warm',
    name: '暖橙',
    descriptor: '浅橙',
    themeMode: 1,
    seed: Color(0xFFE65100),
    bgMode: 1,
    gradient1: Color(0xFFFDEEDC),
    gradient2: Color(0xFFF7C79B),
  ),
  
  ThemePreset(
    id: 'purple_mood',
    name: '紫霞',
    descriptor: '浅紫',
    themeMode: 1,
    seed: Color(0xFF6A1B9A),
    bgMode: 1,
    gradient1: Color(0xFFF0E7FA),
    gradient2: Color(0xFFD2BBEC),
  ),
  
  ThemePreset(
    id: 'dark_sky',
    name: '云青',
    descriptor: '浅灰蓝',
    themeMode: 1,
    seed: Color(0xFF37474F),
    bgMode: 1,
    gradient1: Color(0xFFE6EEF1),
    gradient2: Color(0xFFBFD2D8),
  ),

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  

  
  
  
  
  
  ThemePreset(
    id: 'wp_shell',
    name: '零 · 幽魂',
    descriptor: '青蓝壁纸',
    themeMode: 1,
    seed: Color(0xFF1F6E8C),
    bgMode: 2,
    gradient1: Color(0xFF0A1A24),
    gradient2: Color(0xFF2E5D7A),
    bgImage: 'assets/images/wallpapers/wp_shell.webp',
    wallpaper: true,
    glass: true,
  ),
  
  ThemePreset(
    id: 'wp_violet',
    name: '壹 · 紫焰',
    descriptor: '紫品红壁纸',
    themeMode: 1,
    seed: Color(0xFF8E3A85),
    bgMode: 2,
    gradient1: Color(0xFF150A14),
    gradient2: Color(0xFF6E3A66),
    bgImage: 'assets/images/wallpapers/wp_violet.webp',
    wallpaper: true,
    glass: true,
  ),
  
  ThemePreset(
    id: 'wp_rain',
    name: '贰 · 雨夜',
    descriptor: '冷蓝壁纸',
    themeMode: 1,
    seed: Color(0xFF2E6B8E),
    bgMode: 2,
    gradient1: Color(0xFF0B1418),
    gradient2: Color(0xFF2C4A5A),
    bgImage: 'assets/images/wallpapers/wp_rain.webp',
    wallpaper: true,
    glass: true,
  ),
  
  ThemePreset(
    id: 'wp_amber',
    name: '叁 · 金辉',
    descriptor: '暖金壁纸',
    themeMode: 1,
    seed: Color(0xFFA6791C),
    bgMode: 2,
    gradient1: Color(0xFF241F16),
    gradient2: Color(0xFF6B5A33),
    bgImage: 'assets/images/wallpapers/wp_amber.webp',
    wallpaper: true,
    glass: true,
  ),
  
  ThemePreset(
    id: 'wp_teal',
    name: '肆 · 青灯',
    descriptor: '青绿壁纸',
    themeMode: 1,
    seed: Color(0xFF1F8C93),
    bgMode: 2,
    gradient1: Color(0xFF0C1418),
    gradient2: Color(0xFF2E6B70),
    bgImage: 'assets/images/wallpapers/wp_teal.webp',
    wallpaper: true,
    glass: true,
  ),
  
  ThemePreset(
    id: 'wp_crimson',
    name: '伍 · 绯霓',
    descriptor: '绯红壁纸',
    themeMode: 1,
    seed: Color(0xFFA03A48),
    bgMode: 2,
    gradient1: Color(0xFF1A0E12),
    gradient2: Color(0xFF7A3A44),
    bgImage: 'assets/images/wallpapers/wp_crimson.webp',
    wallpaper: true,
    glass: true,
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
