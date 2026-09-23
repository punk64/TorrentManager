





import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/pages/drawer_page.dart';
import 'package:torrent_manager/pages/share_page.dart';
import 'package:torrent_manager/utils/strings.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  
  
  
  
  setUp(() {
    
    
    
    
    SecurePrefs.useMemoryBackendForTest();
  });

  setUp(() {
    
    
    
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall call) async => null);
    Get.testMode = true;
    Get.reset();
    Get.put(ThemeController(), permanent: true);
  });

  
  
  
  
  

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(GetMaterialApp(
      home: page,
      initialBinding: AppBinding(),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('抽屉中没有登录 / 账号入口', (WidgetTester tester) async {
    await pumpPage(tester, const DrawerPage());

    expect(find.text(S.accLogin), findsNothing,
        reason: '抽屉不应再有「登陆账号」入口');
    expect(find.byIcon(Icons.login), findsNothing,
        reason: '抽屉不应再有登录图标');
    expect(find.byIcon(Icons.account_circle), findsNothing,
        reason: '抽屉不应再展示账号信息');
    
    expect(find.text(S.accExit), findsNothing);

    expect(find.text(S.groupTheme), findsWidgets);
  });

  testWidgets('分享 / 备份页没有账号入口', (WidgetTester tester) async {
    await pumpPage(tester, const SharePage());

    expect(find.byIcon(Icons.account_circle), findsNothing,
        reason: '分享页不应再有「建立 / 管理本地账号」按钮');
    expect(find.textContaining('建立本地账号'), findsNothing);
    expect(find.textContaining('管理本地账号'), findsNothing);

    
    expect(find.text('导入 JSON'), findsOneWidget);
  });
}
