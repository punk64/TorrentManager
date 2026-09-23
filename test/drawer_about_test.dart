import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/pages/drawer_page.dart';
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

  Future<void> pumpDrawer(WidgetTester tester) async {
    await tester.pumpWidget(GetMaterialApp(
      home: const DrawerPage(),
      initialBinding: AppBinding(),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('展开「关于」后不再有订阅说明 / 联系我们', (WidgetTester tester) async {
    await pumpDrawer(tester);

    await tester.scrollUntilVisible(
      find.text(S.groupAbout),
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text(S.groupAbout), findsOneWidget);
    await tester.tap(find.text(S.groupAbout));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('订阅说明'), findsNothing,
        reason: '「订阅说明」已按产品要求删除');
    expect(find.text('联系我们'), findsNothing,
        reason: '「联系我们」已按产品要求删除');
    expect(find.byIcon(Icons.discount), findsNothing);

    expect(find.text(S.termsTitle), findsOneWidget);
    expect(find.text(S.privacyTitle), findsOneWidget);
  });
}
