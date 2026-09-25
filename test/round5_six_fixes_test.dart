import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/pages/drawer_page.dart';
import 'package:torrent_manager/pages/server_dialog.dart';
import 'package:torrent_manager/pages/torrent_list_page.dart';
import 'package:torrent_manager/utils/strings.dart';
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

  test('★ 透明度 100% → 底衬完全透明；0% → 不启用玻璃（不透明）', () {
    final ThemeController tc = Get.put(ThemeController());

    tc.setComponentOpacity(1.0);
    expect(tc.glassEnabled, isTrue, reason: '透明度 > 0 即"玻璃开着"');
    expect(tc.glassAlpha, 0.0,
        reason: '★ 100% 透明度 → 底衬 alpha 恰好 0（全透明）；'
            '此前 0 同时是"不启用玻璃"的哨兵，于是被当成完全不透明');
    expect(tc.theme.colorScheme.surface.a, 0.0,
        reason: '★ 必须真的落到 ThemeData 上（这才是用户看到的）');

    tc.setComponentOpacity(0.0);
    expect(tc.glassEnabled, isFalse);
    expect(tc.glassAlpha, isNull, reason: '"不启用"用 null 表达，不再用 0');
    expect(tc.theme.colorScheme.surface.a, 1.0);

    tc.setComponentOpacity(0.26);
    expect(tc.glassAlpha, closeTo(0.74, 1e-9));
  });

  testWidgets('★ 明亮模式下点「自定义主题」→ 勾仍留在明亮模式上', (WidgetTester tester) async {
    final ThemeController tc = Get.put(ThemeController(), permanent: true);
    await tc.load();
    tc.applyBuiltinMode(1);

    await tester.pumpWidget(GetMaterialApp(
      initialBinding: AppBinding(),
      getPages: <GetPage<dynamic>>[
        GetPage<void>(
            name: '/theme', page: () => const Scaffold(body: Text('THEME_PAGE'))),
      ],
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(
            leading: Builder(
              builder: (BuildContext c) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(c).openDrawer(),
              ),
            ),
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text(S.themeCustom), findsOneWidget);

    await tester.tap(find.text(S.themeCustom));

    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(tc.isCustomSelected, isFalse,
        reason: '★ 只是进了页面、什么都没保存 → 勾不该移到「自定义主题」上');
    expect(tc.isBuiltinMode(1), isTrue,
        reason: '★ 勾应仍在**实际生效**的「明亮模式」上');
    expect(find.text('THEME_PAGE'), findsOneWidget, reason: '确实进了主题页');
  });

  testWidgets('★ 缺账号 / 密码时明确提醒，且不发起连接', (WidgetTester tester) async {
    Get.put(ThemeController(), permanent: true);

    await tester.pumpWidget(GetMaterialApp(
      initialBinding: AppBinding(),
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showServerDialog(ctx),
            child: const Text('OPEN'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '我的NAS');
    await tester.enterText(find.byType(TextFormField).at(1), '192.168.1.9');

    await tester.tap(find.text(S.srvSaveShort));
    await tester.pumpAndSettle();

    expect(find.text(S.srvEnterUsername), findsOneWidget,
        reason: '★ 账号栏应给出必填提示');
    expect(find.text(S.srvEnterPassword), findsOneWidget,
        reason: '★ 密码栏应给出必填提示');
    expect(find.text(S.srvSaveShort), findsOneWidget,
        reason: '★ 被拦下了 —— 对话框没关、也没去连服务器');
  });

  testWidgets('★ 视口高度为 0 的那一帧：按钮不贴顶，且在指标恢复后自愈', (WidgetTester tester) async {
    Widget host(double mediaHeight) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(400, mediaHeight)),
            child: Scaffold(
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
          ),
        );

    await tester.pumpWidget(host(0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_fabButton, findsOneWidget);
    expect(tester.getRect(_fabButton).top, greaterThan(100),
        reason: '★ 指标无效时不得把 0 当真实高度、把按钮 clamp 到顶部');

    await tester.pumpWidget(host(600));
    await tester.pump(const Duration(milliseconds: 50));
    final Rect r = tester.getRect(_fabButton);
    expect(r.top, closeTo(377, 2), reason: '★ 应自愈到"距底部约 20%"的位置');

    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('★ 拖过停靠位后松手：能越过边缘，再吸附回边缘', (WidgetTester tester) async {
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

    final TestGesture g = await tester.startGesture(tester.getRect(_fabButton).center);
    await tester.pump(const Duration(milliseconds: 16));

    for (int i = 0; i < 4; i++) {
      await g.moveBy(const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(tester.getRect(_fabButton).left, lessThan(0),
        reason: '★ 拖动范围必须大于停靠位范围（越界 ${DraggableFab.dragOvershoot}px），'
            '否则"拖到贴边松手"的吸附位移为 0 = 看起来不会吸附');

    await g.up();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(tester.getRect(_fabButton).left.abs(), lessThan(1.5),
        reason: '★ 松手后应吸附到左边缘（视觉左缘 = 0）');
  });

  testWidgets('★ 种子页 AppBar 里的服务器名居中', (WidgetTester tester) async {
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
    final double cx = tester.getRect(name).center.dx;
    final double screenCx = tester.view.physicalSize.width /
        tester.view.devicePixelRatio /
        2;
    expect((cx - screenCx).abs(), lessThan(2),
        reason: '★ 应相对**屏幕**居中；此前往在 AppBar.title 里，'
            '而 title 区域 = leading 与 actions 之间，右侧更宽 → 整体偏左');

    await tester.pump(const Duration(milliseconds: 400));
  });
}
