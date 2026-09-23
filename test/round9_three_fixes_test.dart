







import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart' as dio;

import 'package:torrent_manager/app/style_keys.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/utils/net_error.dart';
import 'package:torrent_manager/widgets/page_preview.dart';

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
  });

  
  Future<void> pumpPreview(
    WidgetTester tester, {
    required AppPageKey page,
    ThemeController? tc,
  }) async {
    final ThemeController c = tc ?? Get.put(ThemeController());
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: PagePreview(page: page),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(c, isNotNull);
  }

  group('① 菜单图预览：三档滤镜必须生效', () {
    testWidgets('默认（三档均为 0）时预览里没有滤镜层', (WidgetTester tester) async {
      final ThemeController tc = Get.put(ThemeController());
      await tc.load();
      await pumpPreview(tester, page: AppPageKey.drawer, tc: tc);

      expect(find.byType(ColorFiltered), findsNothing,
          reason: '去色为 0 时不该挂 ColorFiltered');
      expect(find.byType(ImageFiltered), findsNothing,
          reason: '模糊为 0 时不该挂 ImageFiltered');
    });

    testWidgets('调「去色 / 模糊」后预览图真的套上滤镜', (WidgetTester tester) async {
      final ThemeController tc = Get.put(ThemeController());
      await tc.load();
      await pumpPreview(tester, page: AppPageKey.drawer, tc: tc);

      
      tc.setMenuBgFade(0.8);
      tc.setMenuBgBlur(6);
      await tester.pump();

      expect(find.byType(ColorFiltered), findsWidgets,
          reason: '★ 去色 > 0，抽屉预览图必须挂 ColorFiltered（旧实现完全没有）');
      expect(find.byType(ImageFiltered), findsWidgets,
          reason: '★ 模糊 > 0，抽屉预览图必须挂 ImageFiltered（旧实现完全没有）');
    });

    testWidgets('亮度不为 0 时图片带 tint（BlendMode.srcATop）',
        (WidgetTester tester) async {
      final ThemeController tc = Get.put(ThemeController());
      await tc.load();
      tc.setMenuBgBrightness(-0.5);
      await pumpPreview(tester, page: AppPageKey.drawer, tc: tc);

      final Image img = tester.widgetList<Image>(find.byType(Image)).first;
      expect(img.color, isNotNull, reason: '★ 亮度非 0 时必须有叠加色');
      expect(img.colorBlendMode, BlendMode.srcATop);
    });
  });

  group('② 分页面配色预览：真实页面结构', () {
    testWidgets('服务器页预览含「速度条」结构', (WidgetTester tester) async {
      await pumpPreview(tester, page: AppPageKey.serverList);
      expect(find.byIcon(Icons.south), findsWidgets,
          reason: '★ 服务器页顶部有总下载/总上传速度条（通用骨架没有）');
    });

    testWidgets('种子列表页预览含「搜索框 + 筛选条」结构',
        (WidgetTester tester) async {
      await pumpPreview(tester, page: AppPageKey.torrentList);
      expect(find.byIcon(Icons.search), findsWidgets,
          reason: '★ 种子列表页有搜索框（通用骨架没有）');
    });

    testWidgets('设置页预览含开关行，日志页不含', (WidgetTester tester) async {
      await pumpPreview(tester, page: AppPageKey.settings);
      expect(find.byType(Switch), findsWidgets,
          reason: '★ 设置页预览应有开关行');

      await pumpPreview(tester, page: AppPageKey.log);
      expect(find.byType(Switch), findsNothing,
          reason: '★ 日志页预览不应出现开关 —— 证明不同分区结构**确实不同**，'
              '而不是共用同一套占位骨架');
    });

    testWidgets('各分区预览都能正常渲染（不抛 overflow）',
        (WidgetTester tester) async {
      for (final AppPageKey k in AppPageKey.values) {
        await pumpPreview(tester, page: k);
        expect(tester.takeException(), isNull, reason: '$k 预览渲染异常');
      }
    });
  });

  group('③ TR 登录失败：明确状态与原因', () {
    test('未选择服务器 → 失败且带原因（不再是裸 false）', () async {
      final TrMethod tr = TrMethod();
      final TrLoginResult r = await tr.checkTrServerCookie();
      expect(r.ok, isFalse);
      expect(r.reason, isNotNull, reason: '★ 必须带回人话原因');
      expect(r.reason!.isNotEmpty, isTrue);
    });

    test('401 / 403 被归一化为「账号或密码错误」', () {
      final dio.DioException e = dio.DioException(
        requestOptions: dio.RequestOptions(path: '/transmission/rpc'),
        response: dio.Response<dynamic>(
          requestOptions: dio.RequestOptions(path: '/transmission/rpc'),
          statusCode: 401,
        ),
        type: dio.DioExceptionType.badResponse,
      );
      expect(NetError.describe(e), contains('401'));
      expect(NetError.describe(e), contains('密码'),
          reason: '★ 401 必须说清是账号密码问题，而不是笼统的 HTTP 状态');
    });

    test('鉴权失败与「连不上」在状态上报上可区分', () {
      
      final ServerController sc = ServerController();
      sc.reportAuthFailure('srv-1', '账号或密码错误（HTTP 401）');

      expect(sc.connStatus['srv-1'], ConnStatus.failed);
      expect(sc.connError['srv-1'], startsWith('登录失败'),
          reason: '★ UI 依据该前缀决定显示「重新登录」还是「重试」');

      
      sc.reportFailure('srv-2', Exception('connection refused'));
      expect(sc.connError['srv-2'], isNot(startsWith('登录失败')));
    });
  });
}
