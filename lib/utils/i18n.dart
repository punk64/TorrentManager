import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'i18n_en.dart';

class L {
  L._();

  static const String zh = 'zh';
  static const String en = 'en';

  static final RxString code = ''.obs;

  static String get current {
    final String v = code.value;
    return v.isEmpty ? systemCode() : v;
  }

  static bool useHostLocaleInTest = false;

  static String systemCode() {
    if (!useHostLocaleInTest &&
        Platform.environment['FLUTTER_TEST'] == 'true') {
      return zh;
    }
    try {
      if (WidgetsBinding.instance.platformDispatcher.locale.languageCode ==
          en) {
        return en;
      }
    } catch (_) {
    }
    return zh;
  }

  static bool get isEnglish => current == en;

  static String t(String zhText) {
    if (current != en) return zhText;
    return kEnStrings[zhText] ?? zhText;
  }

  static String pick(String zhText, String enText) =>
      current == en ? enText : zhText;
}
