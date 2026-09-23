import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';

import 'package:torrent_manager/app/routes.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/pages/server_list_page.dart';
import 'package:torrent_manager/pages/torrent_list_page.dart';
import 'package:torrent_manager/widgets/draggable_fab.dart';

final Finder _fabButton = find.descendant(
  of: find.byType(DraggableFab),
  matching: find.byWidgetPredicate(
      (Widget w) => w is Material && w.shape is RoundedRectangleBorder),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall call) async => null);
    Get.testMode = true;
    Get.reset();
  });

  test('★ 「设置」页已删除：路由不存在，原开关固定为默认值', () {
    expect(AppPages.pages.any((GetPage<dynamic> p) => p.name == '/settings'),
        isFalse,
        reason: '★ 设置页应从路由表移除（其页面/控制器文件也已删除）');

    expect(kEnableServerGroup, isFalse);

    final ThemeController tc = Get.put(ThemeController());

    expect(tc.componentOpacity.value, 0.0, reason: '底衬默认完全不透明（透明度 0）');
  });

  testWidgets('★ 首启（无落盘）：底衬完全不透明，抽屉不会透出遮罩', (WidgetTester tester) async {
    final ThemeController tc = Get.put(ThemeController());
    await tc.load();

    expect(tc.componentOpacity.value, 0.0,
        reason: '★ 首启的透明度必须是 0（完全不透明）');
    expect(tc.glassEnabled, isFalse, reason: '透明度 0 → 不启用玻璃');
    expect(tc.glassAlpha, isNull);

    final ColorScheme cs = tc.lightTheme.colorScheme;
    expect(cs.surfaceContainerLow.a, 1.0,
        reason: '★ 必须是**不透明**的，否则抽屉会透出背后变暗的遮罩层');
    expect(cs.surfaceContainerHighest.a, 1.0);

    tc.setComponentOpacity(0.5);
    tc.restoreFactoryDefaults();
    expect(tc.componentOpacity.value, 0.0,
        reason: '★ resetVisualParams 里曾误写 1.0（旧"不透明度"语义的遗留）→ '
            '首启被它设成全透明');
  });

  testWidgets('★ 吸附态：长方形 + 只露 20%；点触发区先回圆再完全弹出', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DraggableFab(
                onPressed: () {},
                topInset: 80,
                initialYRatio: DraggableFab.listPageInitialYRatio,
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    Rect r = tester.getRect(_fabButton);
    expect(r.width, closeTo(46, 1));
    expect(r.left, closeTo(754, 1));

    tester.state<DraggableFabState>(find.byType(DraggableFab))
        .debugInsetToEdge();
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    r = tester.getRect(_fabButton);
    expect(r.width, closeTo(60, 1),
        reason: '★ 吸附态应是**带圆角的长方形**（宽 60）');
    expect(800 - r.left, closeTo(12, 0.5),
        reason: '★ 只露 20%：长方形宽 60 → 露出 12px');
    expect(r.left, closeTo(788, 1));

    await tester.tapAt(Offset(794, r.center.dy));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getRect(_fabButton).width, lessThan(50),
        reason: '★ 弹出**之前**就要恢复成正圆（用户口径）');

    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    r = tester.getRect(_fabButton);
    expect(r.width, closeTo(46, 1), reason: '完全弹出后是正圆');
    expect(r.left, closeTo(754, 1), reason: '★ 完全弹出 = 回到停靠位（完全可见）');
  });

  testWidgets('★ 种子页标题里的服务器名水平 + 垂直都居中', (WidgetTester tester) async {
    const double statusBar = 24;
    tester.view.padding = FakeViewPadding(
      top: statusBar * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);

    Get.put(ThemeController(), permanent: true);
    await tester.pumpWidget(GetMaterialApp(
      home: const TorrentListPage(),
      initialBinding: AppBinding(),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    Get.find<ServerController>().current.value = ServerData(
      id: 's1',
      name: '示例服务器',
      type: 'qbittorrent',
      host: '192.168.1.9',
      port: 8080,
      useHttps: false,
      hideAddress: false,
      hidePort: false,
    );
    await tester.pump(const Duration(milliseconds: 200));

    final Finder name = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('示例服务器'),
    );
    expect(name, findsOneWidget);
    final Rect r = tester.getRect(name);

    final double screenCx =
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2;
    expect((r.center.dx - screenCx).abs(), lessThan(2), reason: '水平居中');

    const double toolbar = kToolbarHeight;
    const double expectCy = statusBar + toolbar / 2;
    expect((r.center.dy - expectCy).abs(), lessThan(2),
        reason: '★ 垂直居中：flexibleSpace 的高度含状态栏，'
            '不压掉它名字会偏上约「状态栏/2」');

    await tester.pump(const Duration(milliseconds: 400));
  });
}
