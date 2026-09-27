import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/app/theme.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/pages/torrent_add_page.dart';
import 'package:torrent_manager/widgets/app_toast.dart';
import 'package:torrent_manager/widgets/torrent_edit_fields.dart';

ServerData _qbSrv() => ServerData(
      id: 'qb-1',
      name: '家庭 NAS',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'admin',
      password: 'adminadmin',
    );

Dio fakeCatalogDio(Map<String, dynamic> categories, List<String> tags) {
  final Dio dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.1.10:8080',
    validateStatus: (int? s) => s != null && s < 500,
    followRedirects: false,
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      final String path = o.uri.path;
      Response<dynamic> ok(Object? data) =>
          Response<dynamic>(requestOptions: o, statusCode: 200, data: data);

      if (path.endsWith('/auth/login')) {
        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: 'Ok.',
          headers: Headers.fromMap(<String, List<String>>{
            'set-cookie': <String>['SID=abc; path=/'],
          }),
        ));
        return;
      }
      if (path.endsWith('/torrents/categories')) {
        h.resolve(ok(categories));
        return;
      }
      if (path.endsWith('/torrents/tags')) {
        h.resolve(ok(tags));
        return;
      }
      if (path.endsWith('/torrents/createCategory')) {
        h.resolve(ok(''));
        return;
      }
      h.resolve(ok(<String, dynamic>{}));
    },
  ));
  return dio;
}

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

  Future<String?> openCategoryDialog(
    WidgetTester tester, {
    required List<String> candidates,
    required List<String> serverCandidates,
    CategoryCreator? onCreate,
    String initial = '',
  }) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              picked = await EditDialogs.category(
                ctx,
                initial: initial,
                candidates: candidates,
                serverCandidates: serverCandidates,
                onCreate: onCreate,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));
    return picked;
  }

  Future<String?> openFailCreate(WidgetTester tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: AppToast.navigatorKey,
      theme: AppTheme.dark,
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              picked = await EditDialogs.category(
                ctx,
                initial: '',
                candidates: const <String>['电影'],
                serverCandidates: const <String>['电影'],
                onCreate: (String name, String? savePath) async => 'HTTP 409',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), '动画');
    await tester.pump();
    await tester.tap(find.textContaining('新建「动画」'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, '确定').last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('创建分类失败：HTTP 409'), findsOneWidget);
    expect(find.textContaining('新建「动画」'), findsOneWidget,
        reason: '失败后可重试，新建 chip 仍在');
    await tester.tap(find.widgetWithText(TextButton, '取消').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, '修改'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1300));
    return picked;
  }

  testWidgets('分类弹窗：搜索只过滤，不输入即选中（杜绝误建 409）',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(445 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    String? picked;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              picked = await EditDialogs.category(
                ctx,
                initial: '',
                candidates: const <String>['电影', '剧集', '纪录片'],
                serverCandidates: const <String>['电影', '剧集'],
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), '纪录片');
    await tester.pump();
    expect(find.text('电影'), findsNothing, reason: '搜索必须过滤列表');

    await tester.tap(find.widgetWithText(FilledButton, '修改'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(picked, isNull,
        reason: '搜索词不能自动成为选中值，直接确认不得误建新分类');
  });

  testWidgets('分类弹窗：批量编辑点「未分类」返回空串（可明确清空）',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(445 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    String? picked;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              picked = await EditDialogs.category(
                ctx,
                initial: '',
                candidates: const <String>['电影', '剧集'],
                serverCandidates: const <String>['电影', '剧集'],
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('未分类'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '修改'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(picked, '',
        reason: '明确点「未分类」必须返回空串，批量编辑才能清空分类');
  });

  testWidgets('分类弹窗：重选当前值不算修改（返回 null）',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(445 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    String? picked;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              picked = await EditDialogs.category(
                ctx,
                initial: '电影',
                candidates: const <String>['电影', '剧集'],
                serverCandidates: const <String>['电影', '剧集'],
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('电影'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '修改'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(picked, isNull, reason: '重选当前值等于无变化，不得触发提交');
  });

  testWidgets('分类弹窗：新建 chip 可点击 → 填保存路径 → 创建成功并选中',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(445 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    String? picked;
    final List<MapEntry<String, String?>> created = <MapEntry<String, String?>>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              picked = await EditDialogs.category(
                ctx,
                initial: '',
                candidates: const <String>['电影', '剧集'],
                serverCandidates: const <String>['电影', '剧集'],
                onCreate: (String name, String? savePath) async {
                  created.add(MapEntry<String, String?>(name, savePath));
                  return null;
                },
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), '动画');
    await tester.pump();
    await tester.tap(find.textContaining('新建「动画」'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('新建分类'), findsOneWidget,
        reason: '必须有创建确认弹窗（名字 + 可选保存路径）');
    await tester.enterText(find.byType(TextField).last, r'D:\Media\Anime');
    await tester.tap(find.widgetWithText(FilledButton, '确定').last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(created, hasLength(1), reason: '点新建 chip 必须真正调用创建回调');
    expect(created.single.key, '动画');
    expect(created.single.value, r'D:\Media\Anime');
    expect(find.text('动画'), findsOneWidget, reason: '创建成功后新分类进入列表');
    expect(find.text('新建'), findsOneWidget, reason: '新建徽章');

    await tester.tap(find.widgetWithText(FilledButton, '修改'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(picked, '动画', reason: '创建成功即选中，确认后返回新分类');
  });

  testWidgets('分类弹窗：新建失败显示错误且不选中', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(445 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final String? picked = await openFailCreate(tester);
    expect(picked, isNull, reason: '创建失败不得返回新分类');
  });

  testWidgets('分类弹窗：候选为空显示空态提示', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(445 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await openCategoryDialog(
      tester,
      candidates: const <String>[],
      serverCandidates: const <String>[],
    );
    expect(find.textContaining('未读取到分类'), findsOneWidget);
  });

  testWidgets('添加页：分类行显示服务器全量分类，入口弹统一选择器',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(445 * 2, 985 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Get.put(ThemeController(), permanent: true);
    final ServerController sc = Get.put(ServerController(
        qb: QbMethod(dio: fakeCatalogDio(
      <String, dynamic>{
        '电影': <String, dynamic>{'name': '电影', 'savePath': r'D:\Media\Movies'},
        '剧集': <String, dynamic>{'name': '剧集', 'savePath': ''},
      },
      const <String>['4K'],
    ))));
    final ServerData srv = _qbSrv();
    sc.servers.assignAll(<ServerData>[srv]);
    sc.current.value = srv;
    Get.put(TorrentController());

    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.dark,
      home: const TorrentAddPage(),
      initialBinding: AppBinding(),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.widgetWithText(ChoiceChip, '电影'), findsOneWidget,
        reason: '添加页分类行必须直接展示服务器识别到的全部分类');
    expect(find.widgetWithText(ChoiceChip, '剧集'), findsOneWidget);

    await tester
        .tap(find.widgetWithText(OutlinedButton, '种子分类'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('下载器'), findsWidgets, reason: '统一选择器带来源徽章');
    expect(find.widgetWithText(FilledButton, '确定'), findsOneWidget,
        reason: '添加页入口的确认按钮是「确定」');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pump(const Duration(milliseconds: 300));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
