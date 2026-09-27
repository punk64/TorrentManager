import 'dart:io';

import 'package:flutter/material.dart';

import '../data/local/secure_prefs.dart';

class ThemeBackground {
  static const String _kBgKey = 'torrentmanager.theme.background';
  static const String _kMenuBgKey = 'torrentmanager.theme.menuBackground';

  static Future<String?> load() async {
    final String? local = await _readPath(_kBgKey);
    if (local != null) return local;
    return 'assets/images/drawer_menu_default.webp';
  }

  static Future<String?> loadMenu() => _readPath(_kMenuBgKey);

  static Future<void> save(String path) => _writePath(_kBgKey, path);

  static Future<void> saveMenu(String path) => _writePath(_kMenuBgKey, path);

  static Future<String?> _readPath(String key) async {
    final Object? v = await SecurePrefs.get(key);
    if (v is! String) return null;
    return v.isEmpty ? null : v;
  }

  static Future<void> _writePath(String key, String path) =>
      SecurePrefs.set(key, path);

  static BoxDecoration? build({
    String? path,
    double brightness = 0,
  }) {
    if (path == null || path.isEmpty) return null;
    final ImageProvider<Object> image = path.startsWith('assets/')
        ? AssetImage(path) as ImageProvider<Object>
        : FileImage(File(path));
    return BoxDecoration(
      image: DecorationImage(
        image: image,
        fit: BoxFit.cover,
        colorFilter: brightness == 0
            ? null
            : ColorFilter.mode(
                brightness > 0
                    ? Colors.white.withValues(alpha: brightness * 0.6)
                    : Colors.black.withValues(alpha: -brightness * 0.6),
                BlendMode.srcOver,
              ),
      ),
    );
  }
}
