import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/bindings.dart';
import 'app/page_style.dart';
import 'app/routes.dart';
import 'app/style_keys.dart';
import 'controllers/locale_controller.dart';
import 'controllers/server_controller.dart';
import 'controllers/theme_controller.dart';
import 'utils/app_log.dart';
import 'utils/net_error.dart';
import 'pages/server_list_page.dart';
import 'utils/strings.dart';
import 'widgets/app_toast.dart';
import 'widgets/auto_refresh.dart';

void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    Get.put(ThemeController(), permanent: true);

    Get.put(LocaleController(), permanent: true);

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);

      AppLog.instance.error(
          'UI 异常: ${NetError.describe(details.exceptionAsString())}',
          source: AppLog.srcApp);
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      AppLog.instance.error('未捕获异常: ${NetError.describe(error)}');
      return true;
    };

    ServerController.prefsPrefetchEnabled = true;

    AppLog.instance.info('应用启动');
    runApp(const TorrentManagerApp());
  }, (Object error, StackTrace stack) {
    AppLog.instance.error('未捕获异常: ${NetError.describe(error)}');
    if (kDebugMode) {
      debugPrint('[TorrentManager] uncaught error: ${NetError.describe(error)}');
      debugPrint(stack.toString());
    }
  });
}

bool _screenDiagLogged = false;

class TorrentManagerApp extends StatelessWidget {
  const TorrentManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController tc = Get.find<ThemeController>();

    return Obx(
      () {
        LocaleController.langCode;

        return GetMaterialApp(

        title: S.appNameLocalized,
        debugShowCheckedModeBanner: false,

        navigatorKey: AppToast.navigatorKey,

        theme: tc.lightTheme,
        darkTheme: tc.darkTheme,
        themeMode: tc.materialMode,

        locale: Locale(LocaleController.langCode),

        home: const AppPageTheme(
          pageLevel: true,
          page: AppPageKey.serverList,
          applyCardBackground: true,
          child: ServerListPage(),
        ),
        getPages: AppPages.pages,
        initialBinding: AppBinding(),

        navigatorObservers: <NavigatorObserver>[autoRefreshRouteObserver],
        builder: (BuildContext ctx, Widget? child) {
          final MediaQueryData mq = MediaQuery.of(ctx);
          final double sysScale = mq.textScaler.scale(1);
          final double clamped = sysScale.clamp(1.0, 1.15);
          if (!_screenDiagLogged) {
            _screenDiagLogged = true;
            AppLog.instance.op(
                '屏幕诊断: width=${mq.size.width.toStringAsFixed(1)}dp '
                'height=${mq.size.height.toStringAsFixed(1)}dp '
                'dpr=${mq.devicePixelRatio} '
                'textScaler=$sysScale(钳制后$clamped) '
                '设计基准=445dp(Mate 80 Pro)');
          }
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(clamped)),
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
      },
    );
  }
}
