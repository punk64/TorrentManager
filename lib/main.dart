import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/bindings.dart';
import 'app/page_style.dart';
import 'app/routes.dart';
import 'app/style_keys.dart';
import 'controllers/locale_controller.dart';
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
          
          
          
          
          
          
          
          
          
          
          
          
          
          
          
          
          
          
          return child ?? const SizedBox.shrink();
        },
      );
      },
    );
  }
}
