













import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/widgets/slidable_tile.dart';
import 'package:torrent_manager/pages/drawer_page.dart';
import 'package:torrent_manager/pages/log_page.dart';
import 'package:torrent_manager/pages/log_qb_page.dart';
import 'package:torrent_manager/pages/server_list_page.dart';
import 'package:torrent_manager/pages/server_setting_page.dart';
import 'package:torrent_manager/pages/share_page.dart';
import 'package:torrent_manager/pages/theme_page.dart';
import 'package:torrent_manager/pages/torrent_add_page.dart';
import 'package:torrent_manager/pages/torrent_info_files_page.dart';
import 'package:torrent_manager/pages/torrent_info_overview_page.dart';
import 'package:torrent_manager/pages/torrent_info_page.dart';
import 'package:torrent_manager/pages/torrent_info_peers_page.dart';
import 'package:torrent_manager/pages/torrent_info_trackers_page.dart';
import 'package:torrent_manager/pages/torrent_list_page.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';

class _Case {
  const _Case(this.name, this.build);
  final String name;
  final Widget Function() build;
}

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
  });

  final List<_Case> cases = <_Case>[
    _Case('ServerListPage', () => const ServerListPage()),
    _Case('TorrentListPage', () => const TorrentListPage()),
    _Case('ThemePage', () => const ThemePage()),
    _Case('SharePage', () => const SharePage()),
    _Case('LogPage', () => const LogPage()),
    _Case('LogQbPage', () => const LogQbPage()),
    _Case('ServerSettingPage', () => const ServerSettingPage()),
    _Case('TorrentAddPage', () => const TorrentAddPage()),
    _Case('TorrentInfoPage', () => const TorrentInfoPage()),
    
    _Case('InfoOverviewPage', () => const Scaffold(body: TorrentInfoOverviewPage())),
    _Case('InfoFilesPage', () => const Scaffold(body: TorrentInfoFilesPage())),
    _Case('InfoPeersPage', () => const Scaffold(body: TorrentInfoPeersPage())),
    _Case('InfoTrackersPage', () => const Scaffold(body: TorrentInfoTrackersPage())),
    
    
    
    _Case('DrawerPage', () => const DrawerPage()),
  ];

  for (final _Case c in cases) {
    testWidgets('smoke: ${c.name}', (WidgetTester tester) async {
      Get.testMode = true;
      Get.reset();
      
      Get.put(ThemeController(), permanent: true);
      Object? err;
      try {
        await tester.pumpWidget(GetMaterialApp(
          home: c.build(),
          initialBinding: AppBinding(),
        ));
        await tester.pump(const Duration(milliseconds: 300));
        err = tester.takeException();
      } catch (e) {
        err = e;
      }
      final int tiles = find.byType(ListTile).evaluate().length;
      final int switches = find.byType(SwitchListTile).evaluate().length;
      final int cupertino = find.byType(CupertinoSwitch).evaluate().length;
      final int exp = find.byType(ExpansionTile).evaluate().length;
      final int texts = find.byType(Text).evaluate().length;
      // ignore: avoid_print
      print('[SMOKE] ${c.name.padRight(20)} '
          'err=${err == null ? "none" : err.toString().split("\n").first.trim()} '
          '| Exp=$exp ListTile=$tiles Switch=$switches Cup=$cupertino Text=$texts');
    });
  }

  
  
  
  
  
  
  
  
  testWidgets('layout: 种子行有数据时不溢出', (WidgetTester tester) async {
    Get.testMode = true;
    Get.reset();
    Get.put(ThemeController(), permanent: true);

    final List<String> problems = <String>[];
    final void Function(FlutterErrorDetails)? oldOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails d) {
      final String s = d.exceptionAsString();
      
      if (s.contains('Unable to load asset')) return;
      problems.add(s);
    };

    try {
      await tester.pumpWidget(GetMaterialApp(
        home: const TorrentListPage(),
        initialBinding: AppBinding(),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      
      final TorrentController ctrl = Get.find<TorrentController>();
      ctrl.items.assignAll(<Torrent>[
        Torrent.fromJson(<String, dynamic>{
          'hash': 'h1',
          'name': '这是一个非常非常长的种子名称用来验证布局不会溢出'
              'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
          'state': 'downloading',
          'progress': 0.42,
          'size': 1234567890123,
          'dlspeed': 8123456,
          'upspeed': 2345678,
          'ratio': 1.2345,
          'num_seeds': 1234,
          'num_leechs': 4567,
          'eta': 86400,
          'added_on': 1700000000,
          'last_activity': 1700001000,
          'completion_on': 1700002000,
          'category': '电影-4K-收藏-超长分类名',
          'tags': 'a,b,c,d,e,f,g,h,i,j,k,l',
          'content_path': '/downloads/a/very/long/path/that/keeps/going/file.mkv',
          'downloaded': 987654321,
          'uploaded': 123456789,
          'dl_limit': 0,
          'up_limit': 1048576,
        }),
        Torrent.fromJson(<String, dynamic>{
          'hash': 'h2',
          'name': '短名',
          'state': 'stalledUP',
          'progress': 1.0,
          'size': 1024,
          'dlspeed': 0,
          'upspeed': 0,
          'ratio': 0,
          'num_seeds': 0,
          'num_leechs': 0,
          'eta': 8640000,
        }),
      ]);
      await tester.pump(const Duration(milliseconds: 400));
      
      await tester.tap(find.byIcon(Icons.expand_more).first);
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = oldOnError;
    }

    final List<String> overflows =
        problems.where((String s) => s.contains('overflowed')).toList();
    // ignore: avoid_print
    print('[LAYOUT] 种子行溢出数=${overflows.length} '
        '其它异常=${problems.length - overflows.length}');
    expect(overflows, isEmpty, reason: '种子行布局溢出：\n${overflows.join('\n---\n')}');

    
    
    
    
    
    final List<SlidableTile> rows =
        tester.widgetList<SlidableTile>(find.byType(SlidableTile)).toList();
    expect(rows, isNotEmpty);
    final SlidableTile row = rows.first;
    expect(row.motion, SlidableMotionKind.scroll);
    expect(row.extentRatio, 0.30,
        reason: '2026-09-17 起种子行与服务器卡片统一 0.30');
    expect(row.slotCount, 2,
        reason: '按钮宽度 = extent/2，两页必须一致');
    expect(row.startActions.length + row.endActions.length, 3,
        reason: '种子行共 3 个侧滑动作');
    expect(row.margin, isNotNull,
        reason: '行间距必须在侧滑容器**外层**，否则会漏色');
  });

  
  
  
  
  
  testWidgets('layout: 服务器卡片有数据时不溢出', (WidgetTester tester) async {
    Get.testMode = true;
    Get.reset();
    Get.put(ThemeController(), permanent: true);

    final List<String> problems = <String>[];
    final void Function(FlutterErrorDetails)? oldOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails d) {
      final String s = d.exceptionAsString();
      if (s.contains('Unable to load asset')) return;
      problems.add(s);
    };

    try {
      await tester.pumpWidget(GetMaterialApp(
        home: const ServerListPage(),
        initialBinding: AppBinding(),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      final ServerController c = Get.find<ServerController>();
      c.servers.assignAll(<ServerData>[
        ServerData(
          id: 'a',
          name: '这是一个非常非常长的服务器名称用来验证卡片布局不会溢出',
          type: 'qbittorrent',
          host: 'very-long-ddns-hostname.example.com',
          port: 55908,
          group: '家里的那台群晖',
        ),
        ServerData(
          id: 'b',
          name: 'TR',
          type: 'transmission',
          host: '192.168.1.5',
          port: 9091,
        ),
      ]);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.byType(SlidableTile), findsNWidgets(2));

      
      
      
      
      final SlidableTile card =
          tester.widget<SlidableTile>(find.byType(SlidableTile).first);
      expect(card.motion, SlidableMotionKind.scroll);
      expect(card.extentRatio, 0.30);
      expect(card.startActions.length, 2, reason: '服务器卡片每面板 2 个动作');
      expect(card.endActions.length, 2);
      expect(card.margin, isNotNull,
          reason: '行间距必须在侧滑容器**外层**，否则会漏色');
    } finally {
      FlutterError.onError = oldOnError;
    }

    final List<String> overflows =
        problems.where((String s) => s.contains('overflowed')).toList();
    // ignore: avoid_print
    print('[LAYOUT] 服务器卡片溢出数=${overflows.length} '
        '其它异常=${problems.length - overflows.length}');
    expect(overflows, isEmpty,
        reason: '服务器卡片布局溢出：\n${overflows.join('\n---\n')}');
  });
}
