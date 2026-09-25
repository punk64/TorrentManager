import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/theme_controller.dart';
import '../app/adaptive.dart';

class BottomPanel {
  BottomPanel._();

  static Future<T?> show<T>({
    required Widget child,
    String? title,
    double? heightFactor,
    bool isScrollControlled = true,
    Color? background,
    BuildContext? context,
  }) {
    final BuildContext? ctx = context ?? Get.context;
    if (ctx == null) return Future<T?>.value(null);

    final ThemeController? tc =
        Get.isRegistered<ThemeController>() ? Get.find<ThemeController>() : null;
    Color? panelBg;
    if (tc != null) {
      panelBg = tc.panelColor.value.withValues(alpha: tc.panel2Alpha.value);
    }

    return showModalBottomSheet<T>(
      context: ctx,
      isScrollControlled: isScrollControlled,
      backgroundColor: background ?? panelBg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusSheet)),
      ),
      builder: (BuildContext context) {
        final double maxH =
            MediaQuery.of(context).size.height * (heightFactor ?? 0.8);

        final ThemeData base = Theme.of(context);
        final Color? fg = panelBg == null ? null : AppTheme.contrastOn(panelBg);
        return Theme(
          data: fg == null
              ? base
              : base.copyWith(
                  textTheme: base.textTheme.apply(
                    bodyColor: fg,
                    displayColor: fg,
                    decorationColor: fg,
                  ),
                  iconTheme: base.iconTheme.copyWith(color: fg),
                ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: af(context, 15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Flexible(child: child),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<T?> showCustom<T>({
    required Widget child,
    String? title,
    double? heightFactor,
  }) =>
      show<T>(child: child, title: title, heightFactor: heightFactor);
}
