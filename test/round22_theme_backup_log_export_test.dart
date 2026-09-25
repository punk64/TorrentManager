import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/app/theme.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/pages/drawer_page.dart';
import 'package:torrent_manager/pages/log_page.dart';
import 'package:torrent_manager/utils/app_log.dart';
import 'package:torrent_manager/utils/log_export.dart';
import 'package:torrent_manager/utils/strings.dart';
import 'package:torrent_manager/utils/theme_backup.dart';
import 'package:torrent_manager/widgets/log_selection.dart';

CustomTheme _theme(String id, String name) => CustomTheme(
      id: id,
      name: name,
      themeMode: 2,
      seed: const Color(0xFF6A1B9A),
      fontColor: const Color(0xFFE6E6E6),
      bgMode: 1,
      gradient1: const Color(0xFF120A1A),
      gradient2: const Color(0xFF3A2A4A),
      bgImage: null,
      componentOpacity: 0.26,
      pageColors: <String, int>{'server': 0xFF123456, 'torrent': 0xFF654321},
    );

void _expectSameTheme(CustomTheme a, CustomTheme b) {
  expect(a.id, b.id);
  expect(a.name, b.name);
  expect(a.themeMode, b.themeMode);
  expect(a.seed.toARGB32(), b.seed.toARGB32());
  expect(a.fontColor?.toARGB32(), b.fontColor?.toARGB32());
  expect(a.bgMode, b.bgMode);
  expect(a.gradient1.toARGB32(), b.gradient1.toARGB32());
  expect(a.gradient2.toARGB32(), b.gradient2.toARGB32());
  expect(a.bgImage, b.bgImage);
  expect(a.componentOpacity, closeTo(b.componentOpacity, 1e-9));
  expect(a.pageColors, b.pageColors);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
    Get.reset();
    AppLog.instance.clear();
  });

  group('主题包 信封 / round-trip', () {
    test('导出 → 导入，参数逐字段完全相等', () {
      final ThemePack pack = ThemePack(
        themes: <CustomTheme>[_theme('c1', '夜航'), _theme('c2', '墨玉')],
        exportedAt: DateTime(2026, 9, 20, 17, 5),
      );
      final ThemePackResult r = ThemeBackup.parse(pack.encode());

      expect(r.ok, isTrue, reason: '合法信封必须解析成功');
      expect(r.error, isNull);
      expect(r.skipped, isEmpty);
      final ThemePack got = r.pack!;
      expect(got.version, ThemePack.currentVersion);
      expect(got.themes.length, 2);
      expect(got.exportedAt, DateTime(2026, 9, 20, 17, 5));
      for (int i = 0; i < 2; i++) {
        _expectSameTheme(pack.themes[i], got.themes[i]);
      }
    });

    test('信封带 app / format / version / count 四个标识', () {
      final ThemePack pack = ThemePack(
        themes: <CustomTheme>[_theme('c1', '甲')],
        exportedAt: DateTime(2026, 9, 20),
      );
      final Map<String, dynamic> j =
          jsonDecode(pack.encode()) as Map<String, dynamic>;
      expect(j['app'], 'TorrentManager');
      expect(j['format'], 'torrentmanager-theme-pack');
      expect(j['version'], 1);
      expect(j['count'], 1);
      expect(j['themes'], isA<List<dynamic>>());
    });

    test('文件名为 torrentmanager-theme-YYYY-MM-DD.json', () {
      final ThemePack pack =
          ThemePack(themes: const <CustomTheme>[], exportedAt: DateTime(2026, 9, 5));
      expect(pack.suggestedFileName(), 'torrentmanager-theme-2026-09-05.json');
    });

    test('逐条被跳过的原因精确到缺失字段', () {
      final String text = jsonEncode(<String, dynamic>{
        'app': 'TorrentManager',
        'format': 'torrentmanager-theme-pack',
        'version': 1,
        'themes': <dynamic>[
          _theme('c1', '甲').toJson(),
          <String, dynamic>{'id': 'c2', 'name': '乙'},
        ],
      });
      final ThemePackResult r = ThemeBackup.parse(text);
      expect(r.ok, isTrue);
      expect(r.pack!.themes.length, 1);
      expect(r.skipped.length, 1);
      expect(r.skipped.first, contains('seed'));
      expect(r.skipped.first, contains('第 2 套'));
    });
  });

  group('坏数据 四类', () {
    test('① 非 JSON → 具体到"不是合法的 JSON"', () {
      final ThemePackResult r = ThemeBackup.parse('这不是 json{{');
      expect(r.ok, isFalse);
      expect(r.error, contains('不是合法的 JSON'));
      expect(r.hint, isNotNull);
    });

    test('② 标识不符（外来的 JSON 数组）→ 不是 TorrentManager 主题配置', () {
      final ThemePackResult r =
          ThemeBackup.parse(jsonEncode(<Object>['随便', '一个', '数组']));
      expect(r.ok, isFalse);
      expect(r.error, S.themeImportBadSource);

      final ThemePackResult r2 = ThemeBackup.parse(
          jsonEncode(<String, dynamic>{'app': 'Other', 'format': 'x'}));
      expect(r2.error, S.themeImportBadSource);
    });

    test('③ 版本比应用新 → 明确报出文件版本与应用版本', () {
      final String text = jsonEncode(<String, dynamic>{
        'app': 'TorrentManager',
        'format': 'torrentmanager-theme-pack',
        'version': 3,
        'themes': <dynamic>[_theme('c1', '甲').toJson()],
      });
      final ThemePackResult r = ThemeBackup.parse(text);
      expect(r.ok, isFalse);
      expect(r.error, S.themeImportTooNew(3, ThemePack.currentVersion));
      expect(r.error, contains('v3'));
    });

    test('④ themes 为空 → 文件里没有任何主题', () {
      final String text = jsonEncode(<String, dynamic>{
        'app': 'TorrentManager',
        'format': 'torrentmanager-theme-pack',
        'version': 1,
        'themes': <dynamic>[],
      });
      final ThemePackResult r = ThemeBackup.parse(text);
      expect(r.ok, isFalse);
      expect(r.error, S.themeImportEmpty);
    });

    test('全部条目都坏 → 整体失败（而不是"导入 0 套"）', () {
      final String text = jsonEncode(<String, dynamic>{
        'app': 'TorrentManager',
        'format': 'torrentmanager-theme-pack',
        'version': 1,
        'themes': <dynamic>[
          <String, dynamic>{'name': '甲'},
          <String, dynamic>{'id': 1, 'seed': 'x'},
        ],
      });
      final ThemePackResult r = ThemeBackup.parse(text);
      expect(r.ok, isFalse);
      expect(r.error, S.themeImportAllBad(2));
    });
  });

  group('日志文本拼装 / 隐私开关', () {
    test('每行含 时间 / 等级 / 来源 / 正文', () {
      LogLine l = LogLine(
        time: '2026-09-20 16:41:02',
        level: S.info,
        source: 'APP',
        message: '已连接服务器',
      );
      expect(l.toLine(), '2026-09-20 16:41:02 信息 APP 已连接服务器');

      final String text = LogExport.buildText(<LogLine>[
        l,
        LogLine(time: '2026-09-20 16:41:31', level: S.warning, message: '超时'),
      ]);

      expect(text, contains('16:41:02 信息 APP 已连接服务器\n'));
      expect(text, contains('16:41:31 警告 超时\n'));
      expect(text.endsWith('\n'), isTrue);
    });

    test('空列表 → 空文本', () {
      expect(LogExport.buildText(const <LogLine>[]), '');
    });

    test('文件名区分应用日志 / 服务器日志', () {
      final DateTime d = DateTime(2026, 9, 20);
      expect(LogExport.suggestedFileName(d), 'torrentmanager-log-2026-09-20.txt');
      expect(
        LogExport.suggestedFileName(d, kind: 'qb'),
        'torrentmanager-log-qb-2026-09-20.txt',
      );
    });

    test('隐私开关决定落盘内容：关 → 原文，开 → 打码', () {
      final LogEntry e = LogEntry(
        'INFO',
        '已连接服务器 192.168.1.8:8080 与 tracker.example.com:443',
      );
      final LogLine raw = appLogLine(e, S.info, false);
      final LogLine masked = appLogLine(e, S.info, true);

      expect(raw.message, contains('192.168.1.8:8080'));
      expect(raw.message, contains('tracker.example.com'));

      expect(masked.message, isNot(contains('192.168.1.8')));
      expect(masked.message, contains('***.***.***.***'));
      expect(masked.message, isNot(contains('example.com')));

      expect(masked.time, raw.time);
      expect(masked.level, raw.level);
      expect(masked.source, raw.source);
    });
  });

  group('配色 S1', () {
    test('浅色：卡片比页面背景暗 4 个百分点', () {
      final ThemeData t =
          AppTheme.of(const Color(0xFF1565C0), Brightness.light);
      final double bg = AppTheme.lightnessOf(t.scaffoldBackgroundColor);
      final double card = AppTheme.lightnessOf(t.colorScheme.surfaceContainerLow);
      expect(bg - card, closeTo(AppTheme.cardLuminanceShift, 0.005));
    });

    test('暗色：卡片比页面背景亮，且不低于改版前的层次', () {
      final ThemeData t = AppTheme.of(const Color(0xFF1565C0), Brightness.dark);
      final double bg = AppTheme.lightnessOf(t.scaffoldBackgroundColor);
      final double card = AppTheme.lightnessOf(t.colorScheme.surfaceContainerLow);
      expect(card - bg, greaterThanOrEqualTo(AppTheme.cardLuminanceShift - 0.005));

      expect(card, greaterThan(bg));
    });

    test('卡片描边：0.5px + outlineVariant @16%', () {
      for (final Brightness b in Brightness.values) {
        final ThemeData t = AppTheme.of(const Color(0xFF1565C0), b);
        final RoundedRectangleBorder shape =
            t.cardTheme.shape! as RoundedRectangleBorder;
        final BorderSide side = shape.side;
        expect(side.width, AppTheme.cardBorderWidth);
        expect(side.color.a, closeTo(AppTheme.cardBorderOpacity, 0.01));
        expect(side.style, BorderStyle.solid);
      }
    });

    test('玻璃主题（壁纸）也带描边，卡片色仍走半透明', () {
      final ThemeData t = AppTheme.of(
        const Color(0xFF1F6E8C),
        Brightness.light,
        glassAlpha: 0.26,
      );
      final RoundedRectangleBorder shape =
          t.cardTheme.shape! as RoundedRectangleBorder;
      expect(shape.side.width, AppTheme.cardBorderWidth);

      expect(t.colorScheme.surfaceContainerLow.a, closeTo(0.26, 0.01));
    });

    test('卡内分区底纹强度 3%（不再比卡片本身更抢眼）', () {
      expect(AppTheme.sectionTintShift, lessThan(AppTheme.cardLuminanceShift));
    });
  });

  group('日志页 多选模式', () {
    Future<void> pumpLog(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(GetMaterialApp(
        initialBinding: AppBinding(),
        home: const LogPage(),
      ));
      await tester.pump();
    }

    testWidgets('长按进入选择态：AppBar 变体 + 底部操作条同时出现', (WidgetTester tester) async {
      AppLog.instance.info('第一条日志');
      AppLog.instance.info('第二条日志');
      await pumpLog(tester);

      expect(find.byType(LogSelectionBar), findsNothing);

      await tester.longPress(find.text('第一条日志'));
      await tester.pump();

      expect(find.byType(LogSelectionBar), findsOneWidget);
      expect(find.text(S.logSelectedCount(1)), findsOneWidget);
      expect(find.text(S.logCopyCount(1)), findsOneWidget);

      await tester.tap(find.text(S.logSelectAll));
      await tester.pump();
      expect(find.text(S.logSelectedCount(2)), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.byType(LogSelectionBar), findsNothing);
      expect(find.text('日志'), findsOneWidget);
    });

    testWidgets('复制所选 → 写进剪贴板且自动退出选择态', (WidgetTester tester) async {
      AppLog.instance.info('待复制的日志内容');
      await pumpLog(tester);

      String? clip;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          clip = (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
        }
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.longPress(find.text('待复制的日志内容'));
      await tester.pump();
      await tester.tap(find.text(S.logCopyCount(1)));
      await tester.pump();

      expect(clip, isNotNull, reason: '复制必须真的写进剪贴板');
      expect(clip, contains('待复制的日志内容'));
      expect(clip, contains(S.info));

      expect(find.byType(LogSelectionBar), findsNothing);
    });
  });

  group('导入落库与抽屉入口', () {
    testWidgets('导入落库：换新 id、「保留两者」改名、「覆盖」保留原 id 与位置',
        (WidgetTester tester) async {
      Get.put(ThemeController(), permanent: true);
      final ThemeController tc = Get.find<ThemeController>();

      final ThemeImportOutcome first =
          await tc.applyImportedThemes(<CustomTheme>[_theme('fromFile', '夜航')],
              overwrite: false);
      expect(first.total, 1);
      expect(tc.customThemes.length, 1);
      final String localId = tc.customThemes.first.id;
      expect(localId, isNot('fromFile'), reason: '必须换新 id，否则会与本机既有主题撞号');
      expect(tc.customThemes.first.name, '夜航');

      final ThemeImportOutcome second = await tc.applyImportedThemes(
          <CustomTheme>[_theme('fromFile2', '夜航')],
          overwrite: false);
      expect(second.added, 1);
      expect(tc.customThemes.length, 2);
      expect(tc.customThemes.last.name, '夜航${S.themeImportNameSuffix}');

      final ThemeImportOutcome third = await tc.applyImportedThemes(
          <CustomTheme>[_theme('fromFile3', '夜航')],
          overwrite: true);
      expect(third.replaced, 1);
      expect(tc.customThemes.length, 2, reason: '覆盖不该新增条目');
      expect(tc.customThemes.first.id, localId, reason: '覆盖必须保留原 id');
      expect(tc.customThemes.first.name, '夜航');

      expect(tc.conflictingNames(<CustomTheme>[_theme('z', '夜航')]), <String>['夜航']);
      expect(tc.conflictingNames(<CustomTheme>[_theme('z', '没这个名字')]), isEmpty);
    });

    testWidgets('抽屉主题分组出现导入 / 导出两行，且排在「自定义主题」之后',
        (WidgetTester tester) async {
      Get.put(ThemeController(), permanent: true);
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(GetMaterialApp(
        initialBinding: AppBinding(),
        home: const DrawerPage(),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.ensureVisible(find.text(S.themeImport));
      await tester.pumpAndSettle();

      expect(find.text(S.themeImport), findsOneWidget);
      expect(find.text(S.themeImportSub), findsOneWidget);
      expect(find.text(S.themeExport), findsOneWidget);

      expect(find.text(S.themeExportEmpty), findsOneWidget);

      final double yCustom = tester.getTopLeft(find.text(S.themeCustom)).dy;
      final double yImport = tester.getTopLeft(find.text(S.themeImport)).dy;
      final double yExport = tester.getTopLeft(find.text(S.themeExport)).dy;
      expect(yImport, greaterThan(yCustom));
      expect(yExport, greaterThan(yImport));

      final ListTile exportTile = tester.widget<ListTile>(find.ancestor(
        of: find.text(S.themeExport),
        matching: find.byType(ListTile),
      ));
      expect(exportTile.onTap, isNull);
      expect(exportTile.enabled, isFalse);
    });
  });
}
