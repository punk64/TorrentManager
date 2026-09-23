import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../utils/i18n.dart';
import '../utils/strings.dart';

class LocaleController extends GetxController {
  static bool updateSystemLocale = true;

  static const String kLang = 'torrentmanager.lang';

  static RxString get langRx => L.code;

  static String get langCode => L.current;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final Object? saved = await Formatter.getGlobalData(kLang);
    if (saved is String && (saved == L.zh || saved == L.en)) {
      L.code.value = saved;
      return;
    }

    L.code.value = '';
  }

  static String systemLang() => L.systemCode();

  bool get isPinned => L.code.value.isNotEmpty;

  Future<void> setLang(String code) async {
    final String next = code == L.en ? L.en : L.zh;

    if (L.code.value.isNotEmpty && L.code.value == next) return;
    L.code.value = next;
    await Formatter.saveGlobalData(kLang, next);
    if (updateSystemLocale) {
      await Get.updateLocale(Locale(next));
    }
    AppLog.instance.op('切换语言：$next');
  }

  Future<void> toggle() => setLang(L.isEnglish ? L.zh : L.en);

  String get currentName => L.isEnglish ? S.langEn : S.langZh;
}
