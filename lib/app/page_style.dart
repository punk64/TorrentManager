import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import 'style_keys.dart';
import 'theme.dart';


IconData pageIconOf(AppPageKey key) {
  switch (key) {
    case AppPageKey.drawer:
      return Icons.menu_open;
    case AppPageKey.serverList:
      return Icons.dns;
    case AppPageKey.serverCard:
      return Icons.space_dashboard;
    case AppPageKey.torrentList:
      return Icons.list_alt;
    case AppPageKey.torrentCard:
      return Icons.view_agenda;
    case AppPageKey.torrentDetail:
      return Icons.info_outline;
    case AppPageKey.settings:
      return Icons.settings;
    case AppPageKey.log:
      return Icons.article;
    case AppPageKey.logQb:
      return Icons.receipt_long;
  }
}


















class AppPageTheme extends StatelessWidget {
  const AppPageTheme({
    super.key,
    required this.page,
    required this.child,
    this.applyCardBackground = false,
    this.pageLevel = false,
    this.fixedScrim,
  });

  final AppPageKey page;

  final Widget child;

  
  
  final bool applyCardBackground;

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  final bool pageLevel;

  
  
  
  
  
  final double? fixedScrim;

  @override
  Widget build(BuildContext context) {
    final ThemeController tc = Get.find<ThemeController>();
    return Obx(() {
      final Color? bg = tc.pageColor(page, AppStyleSlot.background);
      final Color? fg = tc.pageColor(page, AppStyleSlot.text);
      final Color? tt = tc.pageColor(page, AppStyleSlot.title);
      final ThemeData base = Theme.of(context);
      return Theme(
        data: base.copyWith(
          scaffoldBackgroundColor: bg ?? base.scaffoldBackgroundColor,
          
          
          
          
          
          
          colorScheme: bg == null
              ? base.colorScheme
              : base.colorScheme.copyWith(
                  surface: bg,
                  surfaceContainerLow: bg,
                  surfaceContainer: bg,
                  
                  
                  
                  surfaceContainerHighest: bg,
                ),
          
          
          
          appBarTheme: tt == null
              ? base.appBarTheme
              : base.appBarTheme.copyWith(
                  titleTextStyle: (base.appBarTheme.titleTextStyle ??
                          base.textTheme.titleLarge)
                      ?.copyWith(color: tt),
                ),
          cardColor: applyCardBackground && bg != null ? bg : base.cardColor,
          canvasColor:
              applyCardBackground && bg != null ? bg : base.canvasColor,
          textTheme: (fg == null && tt == null)
              ? base.textTheme
              
              
              : base.textTheme
                  .apply(
                    bodyColor: fg,
                    displayColor: fg,
                    decorationColor: fg,
                  )
                  .copyWith(
                    titleLarge: tt == null
                        ? null
                        : base.textTheme.titleLarge?.copyWith(color: tt),
                  ),
          iconTheme: fg == null
              ? base.iconTheme
              : base.iconTheme.copyWith(color: fg),
          primaryIconTheme: fg == null
              ? base.primaryIconTheme
              : base.primaryIconTheme.copyWith(color: fg),
        ),
        
        
        child: pageLevel
            ? Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  AppPageBackground(pageColor: bg, fixedScrim: fixedScrim),
                  child,
                ],
              )
            : child,
      );
    });
  }
}





Color? cardBackgroundFor(AppPageKey page, {bool selected = false}) {
  final ThemeController tc = Get.find<ThemeController>();
  final Color? own = tc.pageColor(page, AppStyleSlot.background);
  if (own == null) return null;
  return selected ? own.withValues(alpha: 0.9) : own;
}


Color? cardTextFor(AppPageKey page) =>
    Get.find<ThemeController>().pageColor(page, AppStyleSlot.text);


Color? pageTitleColorFor(AppPageKey page) =>
    Get.find<ThemeController>().pageColor(page, AppStyleSlot.title);


Color? pageTextColorFor(AppPageKey page) =>
    Get.find<ThemeController>().pageColor(page, AppStyleSlot.text);


Color? pageBackgroundFor(AppPageKey page) =>
    Get.find<ThemeController>().pageColor(page, AppStyleSlot.background);




















class AppPageBackground extends StatelessWidget {
  const AppPageBackground({super.key, this.pageColor, this.fixedScrim});

  
  
  
  
  static const Key scrimKey = ValueKey<String>('appPageBackgroundScrim');

  
  
  
  
  
  
  
  
  
  static const double fixedScrimValue = 0.62;

  
  final Color? pageColor;

  
  
  
  
  final double? fixedScrim;

  @override
  Widget build(BuildContext context) {
    final ThemeController tc = Get.find<ThemeController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      
      
      
      
      final ImageProvider<Object>? img =
          tc.renderGlobalBgDecorationImage?.image;
      if (img != null) return _globalImage(tc, img, isDark);
      
      final Decoration? deco = tc.backgroundDecoration;
      if (deco != null) {
        
        
        
        
        return _scrimmed(Container(decoration: deco), isDark);
      }
      
      return Container(
        color: pageColor ??
            (isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold),
      );
    });
  }

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  Widget _scrimmed(Widget background, bool isDark) {
    final double? fixed = fixedScrim;
    if (fixed == null) return background;
    final double a = fixed.clamp(0.0, 0.9);
    if (a <= 0) return background;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        background,
        
        IgnorePointer(
          child: ColoredBox(
            
            
            key: AppPageBackground.scrimKey,
            color: (isDark ? Colors.black : Colors.white).withValues(alpha: a),
          ),
        ),
      ],
    );
  }

  
  Widget _globalImage(
    ThemeController tc,
    ImageProvider<Object> img,
    bool isDark,
  ) {
    
    final double brightness = tc.renderGlobalBgBrightness;
    final double fade = tc.renderGlobalBgFade.clamp(0.0, 1.0);
    final double blur = tc.renderGlobalBgBlur;

    
    final Color? tint = brightness == 0
        ? null
        : (brightness > 0 ? Colors.white : Colors.black)
            .withValues(alpha: brightness.abs().clamp(0.0, 1.0));

    Widget bg = Image(
      image: img,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      color: tint,
      colorBlendMode: tint == null ? null : BlendMode.srcATop,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    
    if (fade > 0) {
      bg = ColorFiltered(
        colorFilter: AppTheme.saturationFilter(1.0 - fade),
        child: bg,
      );
    }
    if (blur > 0) {
      bg = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: bg,
      );
    }
    
    
    
    
    
    
    return _scrimmed(bg, isDark);
  }
}
