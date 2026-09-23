import 'package:flutter/material.dart';
import '../utils/i18n.dart';
import 'package:get/get.dart';

import '../app/page_style.dart';
import '../app/style_keys.dart';
import '../app/theme.dart';
import '../controllers/theme_controller.dart';
import '../utils/strings.dart';
import 'filtered_image.dart';




















class PagePreview extends StatelessWidget {
  const PagePreview({
    super.key,
    required this.page,
    this.width = 108,
    this.backgroundImage,
    this.topImage,
    this.useDefaultBackgroundIfEmpty = false,
  });

  
  static const double screenAspect = 9 / 19.5;

  
  static const double _lw = 300;
  static const double _lh = 650;

  
  final AppPageKey page;

  
  final double width;

  
  final ImageProvider? backgroundImage;

  
  final ImageProvider? topImage;

  
  
  
  
  final bool useDefaultBackgroundIfEmpty;

  
  double get height => width / screenAspect;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ThemeController tc = Get.find<ThemeController>();
      
      
      final ColorScheme cs = tc.previewTheme.colorScheme;

      final Color? userBg = tc.pageColor(page, AppStyleSlot.background);
      final Color? userText = tc.pageColor(page, AppStyleSlot.text);
      final Color? userTitle = tc.pageColor(page, AppStyleSlot.title);

      final Color pageBg = userBg ?? cs.surfaceContainerLowest;
      final Color cardBg = cardBackgroundFor(page) ?? cs.surfaceContainerLow;
      final Color bodyC = userText ?? cs.onSurface;
      final Color titleC = userTitle ?? bodyC;

      final ImageProvider<Object>? bg = backgroundImage ??
          (useDefaultBackgroundIfEmpty
              ? const AssetImage(ThemeController.defaultMenuImage)
              : null);

      
      
      final Widget content = page == AppPageKey.drawer
          ? _drawerPreview(tc, cs)
          : _realPagePreview(tc, cs, cardBg, titleC, bodyC);

      return Center(
        child: SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: Container(
              decoration: BoxDecoration(
                color: pageBg,
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              
              
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (bg != null) _background(tc, bg),
                  content,
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  
  
  Widget _background(ThemeController tc, ImageProvider<Object> img) {
    return FilteredImage(
      image: img,
      brightness: tc.globalBgBrightness.value,
      fade: tc.globalBgFade.value.clamp(0.0, 1.0),
      blur: tc.globalBgBlur.value,
      width: double.infinity,
      height: double.infinity,
      fallback: const AssetImage(ThemeController.defaultMenuImage),
    );
  }

  

  
  Widget _drawerPreview(ThemeController tc, ColorScheme cs) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: _lw,
        height: _lh,
        child: Container(
          color: cs.surfaceContainerLow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _drawerHeader(tc),
              
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 10, bottom: 4),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.palette, size: 20, color: cs.onSurface),
                    const SizedBox(width: 12),
                    Text(
                      S.groupTheme,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              _drawerTile(cs, Icons.light_mode, L.t('示例文本')),
              _drawerTile(cs, Icons.dark_mode, L.t('示例文本')),
              _drawerTile(cs, Icons.color_lens, L.t('示例文本')),
              _drawerTile(cs, Icons.expand_more, L.t('示例文本')),
            ],
          ),
        ),
      ),
    );
  }

  
  
  ImageProvider<Object> _menuImageOf(ThemeController tc) {
    if (topImage != null) return topImage!;
    final String? custom = tc.menuImagePath.value;
    final String path = (custom == null || custom.isEmpty)
        ? ThemeController.defaultMenuImage
        : custom;
    return ThemeController.imageProviderFor(path);
  }

  
  
  
  
  
  
  
  
  
  
  
  Widget _drawerHeader(ThemeController tc) {
    return SizedBox(
      height: 150,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          FilteredImage(
            image: _menuImageOf(tc),
            brightness: tc.menuBgBrightness.value,
            fade: tc.menuBgFade.value.clamp(0.0, 1.0),
            blur: tc.menuBgBlur.value,
            fallback: const AssetImage(ThemeController.defaultMenuImage),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Text(
                S.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerTile(ColorScheme cs, IconData icon, String title) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: cs.onSurface),
      title: Text(title, style: TextStyle(fontSize: 14, color: cs.onSurface)),
    );
  }

  

  
  
  
  Widget _realPagePreview(
    ThemeController tc,
    ColorScheme cs,
    Color cardBg,
    Color titleC,
    Color bodyC,
  ) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: _lw,
        height: _lh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _appBar(cs, titleC),
            Expanded(child: _body(cs, cardBg, titleC, bodyC)),
          ],
        ),
      ),
    );
  }

  
  Widget _appBar(ColorScheme cs, Color titleC) {
    final String t = specOf(page).titleLocalized;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: cs.surfaceContainerHigh,
      child: Row(
        children: <Widget>[
          Icon(Icons.menu, size: 20, color: titleC),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.isEmpty ? L.t('示例页面') : t,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: titleC),
            ),
          ),
          Icon(Icons.more_vert, size: 20, color: titleC),
        ],
      ),
    );
  }

  Widget _body(ColorScheme cs, Color cardBg, Color titleC, Color bodyC) {
    switch (page) {
      case AppPageKey.serverList:
        return _listBody(<Widget>[
          _speedBar(cs, bodyC),
          _serverCard(cs, cardBg, titleC, bodyC, Icons.dns_outlined),
          _serverCard(cs, cardBg, titleC, bodyC, Icons.storage_outlined),
        ]);
      case AppPageKey.serverCard:
        return _listBody(<Widget>[
          _serverCard(cs, cardBg, titleC, bodyC, Icons.dns_outlined,
              withStatus: true),
          _serverCard(cs, cardBg, titleC, bodyC, Icons.storage_outlined,
              withStatus: true),
        ]);
      case AppPageKey.torrentList:
        return _listBody(<Widget>[
          _searchField(cs, bodyC),
          _filterChips(cs, bodyC),
          _torrentCard(cs, cardBg, titleC, bodyC),
          _torrentCard(cs, cardBg, titleC, bodyC, withMeta: true),
        ]);
      case AppPageKey.torrentCard:
        return _listBody(<Widget>[
          _torrentCard(cs, cardBg, titleC, bodyC, withMeta: true),
          _torrentCard(cs, cardBg, titleC, bodyC, withMeta: true),
        ]);
      case AppPageKey.torrentDetail:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _tabs(cs, titleC, bodyC),
            Expanded(
              child: _listBody(<Widget>[
                _infoRow(cs, bodyC, titleC),
                _infoRow(cs, bodyC, titleC),
                _infoRow(cs, bodyC, titleC),
                _infoRow(cs, bodyC, titleC),
              ], padTop: 10),
            ),
          ],
        );
      case AppPageKey.settings:
        return _listBody(<Widget>[
          _switchRow(cs, bodyC, Icons.dark_mode_outlined),
          _switchRow(cs, bodyC, Icons.notifications_none),
          _switchRow(cs, bodyC, Icons.lock_outline),
        ], padTop: 10);
      case AppPageKey.log:
      case AppPageKey.logQb:
        return _listBody(<Widget>[
          _logRow(cs, bodyC),
          _logRow(cs, bodyC),
          _logRow(cs, bodyC),
          _logRow(cs, bodyC),
          _logRow(cs, bodyC),
        ], padTop: 10);
      case AppPageKey.drawer:
        
        return const SizedBox.shrink();
    }
  }

  
  Widget _listBody(List<Widget> children, {double padTop = 12}) {
    return SingleChildScrollView(
      
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, padTop, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children
              .expand((Widget w) => <Widget>[w, const SizedBox(height: 8)])
              .toList()
            ..removeLast(),
        ),
      ),
    );
  }

  Widget _card(Color cardBg, Widget child) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: child,
      );

  
  Widget _speedBar(ColorScheme cs, Color bodyC) => Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Icon(Icons.south, size: 14, color: cs.primary),
            Text(L.t('示例文本'), style: TextStyle(fontSize: 11, color: bodyC)),
            Icon(Icons.north, size: 14, color: cs.tertiary),
            Text(L.t('示例文本'), style: TextStyle(fontSize: 11, color: bodyC)),
          ],
        ),
      );

  Widget _serverCard(
    ColorScheme cs,
    Color cardBg,
    Color titleC,
    Color bodyC,
    IconData icon, {
    bool withStatus = false,
  }) {
    return _card(
      cardBg,
      Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(L.t('示例卡片'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: titleC)),
                const SizedBox(height: 3),
                Text(L.t('示例文本'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: bodyC)),
                if (withStatus) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(L.t('示例文本'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: bodyC)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
            ),
            child: Text(L.t('示例文本'),
                style: TextStyle(fontSize: 9, color: cs.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }

  
  Widget _searchField(ColorScheme cs, Color bodyC) => Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.search, size: 14, color: bodyC),
            const SizedBox(width: 6),
            Text(L.t('示例文本'), style: TextStyle(fontSize: 11, color: bodyC)),
          ],
        ),
      );

  
  Widget _filterChips(ColorScheme cs, Color bodyC) => Row(
        children: <Widget>[
          for (int i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: i == 0 ? cs.secondaryContainer : cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
                ),
                child: Text(L.t('示例文本'),
                    style: TextStyle(
                        fontSize: 10,
                        color: i == 0 ? cs.onSecondaryContainer : bodyC)),
              ),
            ),
        ],
      );

  Widget _torrentCard(
    ColorScheme cs,
    Color cardBg,
    Color titleC,
    Color bodyC, {
    bool withMeta = false,
  }) {
    return _card(
      cardBg,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(L.t('示例卡片'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: titleC)),
          const SizedBox(height: 6),
          
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.62,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(L.t('示例文本'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: bodyC)),
              ),
              Text(L.t('示例文本'), style: TextStyle(fontSize: 10, color: bodyC)),
            ],
          ),
          if (withMeta) ...<Widget>[
            const SizedBox(height: 3),
            Text(L.t('示例文本'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: bodyC)),
          ],
        ],
      ),
    );
  }

  
  Widget _tabs(ColorScheme cs, Color titleC, Color bodyC) => Container(
        height: 40,
        color: cs.surfaceContainerHigh,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(L.t('示例文本'),
                      style: TextStyle(
                          fontSize: 12,
                          color: i == 0 ? titleC : bodyC,
                          fontWeight:
                              i == 0 ? FontWeight.w600 : FontWeight.normal)),
                  const SizedBox(height: 4),
                  if (i == 0)
                    Container(
                        width: 36, height: 2, color: cs.primary),
                ],
              ),
          ],
        ),
      );

  
  Widget _infoRow(ColorScheme cs, Color bodyC, Color titleC) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Text(L.t('示例文本'), style: TextStyle(fontSize: 11, color: bodyC)),
            const Spacer(),
            Text(L.t('示例文本'), style: TextStyle(fontSize: 11, color: titleC)),
          ],
        ),
      );

  
  Widget _switchRow(ColorScheme cs, Color bodyC, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: bodyC),
            const SizedBox(width: 10),
            Expanded(
              child: Text(L.t('示例文本'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: bodyC)),
            ),
            const Switch(value: true, onChanged: null),
          ],
        ),
      );

  
  Widget _logRow(ColorScheme cs, Color bodyC) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(L.t('示例文本'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: bodyC)),
            ),
          ],
        ),
      );
}
