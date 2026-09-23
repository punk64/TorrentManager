














import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/widgets/sort_filter_panel.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';


Torrent mk({
  required String hash,
  String name = '种子',
  int size = 0,
  double ratio = 0,
  int seeds = 0,
  int dlSpeed = 0,
  int upSpeed = 0,
  int downloaded = 0,
  int uploaded = 0,
  int addedOn = 0,
  int completionOn = 0,
  int seedingTime = 0,
  String? category,
  String? tags,
  String? savePath,
  String? comment,
  String? magnetUri,
}) =>
    Torrent(
      hash: hash,
      name: name,
      size: size,
      progress: 0,
      state: 'downloading',
      dlSpeed: dlSpeed,
      upSpeed: upSpeed,
      numSeeds: seeds,
      numLeechs: 0,
      ratio: ratio,
      downloaded: downloaded,
      uploaded: uploaded,
      addedOn: addedOn,
      completionOn: completionOn,
      seedingTime: seedingTime,
      category: category,
      tags: tags,
      savePath: savePath,
      comment: comment,
      magnetUri: magnetUri,
    );


Map<String, int> counts(List<FacetEntry> list) => <String, int>{
      for (final FacetEntry e in list) e.value: e.count,
    };

List<String> hashes(TorrentController c) =>
    c.visibleItems.map((Torrent e) => e.hash).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  
  
  
  
  setUp(() {
    
    
    
    
    SecurePrefs.useMemoryBackendForTest();
  });


  late TorrentController ctrl;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall call) async => null);
    Get.testMode = true;
    Get.reset();
    Get.put(ServerController());
    ctrl = Get.put(TorrentController());
  });

  
  

  group('默认态：添加时间 + 降序', () {
    test('排序维度默认「添加时间」，方向默认「降序」', () {
      expect(ctrl.sortKey.value, TorrentSortKey.addedOn);
      expect(ctrl.sortDesc.value, isTrue,
          reason: '产品要求默认选中降序；同时它也保证「升序/降序必有其一」');
    });

    test('默认排序下新添加的种子排在最前', () {
      ctrl.items.assignAll(<Torrent>[
        mk(hash: 'old', addedOn: 100),
        mk(hash: 'new', addedOn: 300),
        mk(hash: 'mid', addedOn: 200),
      ]);
      expect(hashes(ctrl), <String>['new', 'mid', 'old']);
    });

    test('排序维度与方向会持久化，重建控制器后恢复', () async {
      ctrl.setSortKey(TorrentSortKey.ratio);
      ctrl.setSortDesc(false);
      
      await Future<void>.delayed(const Duration(milliseconds: 20));

      Get.delete<TorrentController>(force: true);
      final TorrentController fresh = Get.put(TorrentController());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(fresh.sortKey.value, TorrentSortKey.ratio);
      expect(fresh.sortDesc.value, isFalse);
    });
  });

  group('排序方向：升序 / 降序互斥', () {
    test('降序 = 大在前，升序 = 小在前', () {
      ctrl.items.assignAll(<Torrent>[
        mk(hash: 'a', size: 100),
        mk(hash: 'b', size: 300),
        mk(hash: 'c', size: 200),
      ]);
      ctrl.setSortKey(TorrentSortKey.size);

      ctrl.setSortDesc(true);
      expect(hashes(ctrl), <String>['b', 'c', 'a']);

      ctrl.setSortDesc(false);
      expect(hashes(ctrl), <String>['a', 'c', 'b']);
    });

    test('13 个维度都能排序（不抛错、结果数量一致）', () {
      ctrl.items.assignAll(<Torrent>[
        mk(hash: 'a', size: 10, ratio: 1, seeds: 3, dlSpeed: 5, upSpeed: 6,
            downloaded: 7, uploaded: 8, addedOn: 9, completionOn: 10,
            seedingTime: 11, name: 'bbb'),
        mk(hash: 'b', size: 20, ratio: 2, seeds: 4, dlSpeed: 6, upSpeed: 7,
            downloaded: 8, uploaded: 9, addedOn: 10, completionOn: 11,
            seedingTime: 12, name: 'aaa'),
      ]);
      for (final TorrentSortKey k in TorrentSortKey.values) {
        ctrl.setSortKey(k);
        expect(hashes(ctrl).length, 2, reason: '维度 ${k.label} 排序后不能丢种子');
      }
    });

    test('同值种子顺序稳定：每次刷新不能换位（否则界面「乱跳」）', () {
      ctrl.items.assignAll(<Torrent>[
        mk(hash: 'h1', size: 100, addedOn: 5),
        mk(hash: 'h2', size: 100, addedOn: 5),
        mk(hash: 'h3', size: 100, addedOn: 5),
      ]);
      ctrl.setSortKey(TorrentSortKey.size);
      final List<String> first = hashes(ctrl);
      final List<String> second = hashes(ctrl);
      expect(second, first);
    });
  });

  group('四维筛选：组内 OR、维度间 AND', () {
    setUp(() {
      ctrl.items.assignAll(<Torrent>[
        mk(hash: 'a', category: '电影', tags: '国语,高清', savePath: '/m'),
        mk(hash: 'b', category: '动漫', tags: '国语', savePath: '/m'),
        mk(hash: 'c', category: '电影', tags: '日语', savePath: '/n'),
      ]);
    });

    test('同维度多选是 OR', () {
      ctrl.toggleFacet(FilterDim.category, '电影');
      expect(hashes(ctrl), <String>['a', 'c']);

      ctrl.toggleFacet(FilterDim.category, '动漫');
      expect(hashes(ctrl).length, 3, reason: '两个分类都选中 = 合集');
    });

    test('不同维度之间是 AND', () {
      ctrl.toggleFacet(FilterDim.category, '电影');
      ctrl.toggleFacet(FilterDim.tags, '国语');
      expect(hashes(ctrl), <String>['a'], reason: '电影 且 带国语标签');
    });

    test('再点一次取消选中', () {
      ctrl.toggleFacet(FilterDim.category, '电影');
      expect(hashes(ctrl).length, 2);
      ctrl.toggleFacet(FilterDim.category, '电影');
      expect(hashes(ctrl).length, 3);
    });

    test('清除筛选清空全部维度', () {
      ctrl.toggleFacet(FilterDim.category, '电影');
      ctrl.toggleFacet(FilterDim.tags, '国语');
      expect(ctrl.hasFacets, isTrue);

      ctrl.clearFacets();
      expect(ctrl.hasFacets, isFalse);
      expect(hashes(ctrl).length, 3);
    });
  });

  group('筛选计数：排除自身维度，随筛选实时变化', () {
    setUp(() {
      ctrl.items.assignAll(<Torrent>[
        mk(hash: 'a', category: '电影', tags: '国语'),
        mk(hash: 'b', category: '动漫', tags: '国语'),
        mk(hash: 'c', category: '电影', tags: '日语'),
      ]);
    });

    test('未筛选时按全量统计', () {
      expect(counts(ctrl.facets(FilterDim.category)),
          <String, int>{'电影': 2, '动漫': 1});
    });

    test('选中标签后分类计数实时变小（因为统计时排除了分类自身）', () {
      ctrl.toggleFacet(FilterDim.tags, '国语');
      
      expect(counts(ctrl.facets(FilterDim.category)),
          <String, int>{'电影': 1, '动漫': 1});
    });

    test('已选中项即使计数为 0 也必须保留（否则无法取消）', () {
      ctrl.toggleFacet(FilterDim.category, '动漫');
      ctrl.toggleFacet(FilterDim.tags, '日语');
      
      final Map<String, int> c = counts(ctrl.facets(FilterDim.category));
      expect(c.containsKey('动漫'), isTrue);
      expect(c['动漫'], 0);
    });

    test('多标签种子会同时计入多个标签分组', () {
      ctrl.items.assignAll(<Torrent>[
        mk(hash: 'x', tags: '国语,高清'),
      ]);
      expect(counts(ctrl.facets(FilterDim.tags)),
          <String, int>{'国语': 1, '高清': 1});
    });
  });

  group('兜底分组：未分类 / 未标记 / 未知站点', () {
    test('空值也必须能筛出来', () {
      ctrl.items.assignAll(<Torrent>[
        mk(hash: 'a'),
        mk(hash: 'b', category: '电影', tags: 'x', savePath: '/p'),
      ]);

      expect(counts(ctrl.facets(FilterDim.category))['未分类'], 1);
      expect(counts(ctrl.facets(FilterDim.tags))['未标记'], 1);
      expect(counts(ctrl.facets(FilterDim.path))['未指定'], 1);
      expect(counts(ctrl.facets(FilterDim.site))['未知站点'], 2);

      ctrl.toggleFacet(FilterDim.category, '未分类');
      expect(hashes(ctrl), <String>['a']);
    });
  });

  group('面板渲染（防「Obx 读不到 Rx → 整块空白」回归）', () {
    testWidgets('面板能渲染出排序维度 / 方向按钮 / 四个折叠区标题', (WidgetTester tester) async {
      ctrl.items.assignAll(<Torrent>[
        mk(hash: 'a', category: '电影', tags: '国语', savePath: '/m'),
      ]);

      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: SortFilterPanel())),
      );
      await tester.pump();

      expect(find.text('排序方式'), findsOneWidget);
      
      expect(find.text('添加时间'), findsOneWidget);
      expect(find.text('做种人数'), findsOneWidget);
      
      expect(find.text('升序'), findsOneWidget);
      expect(find.text('降序'), findsOneWidget);
      
      for (final FilterDim d in FilterDim.values) {
        expect(find.text(d.title), findsOneWidget, reason: '缺少「${d.title}」分组');
      }
    });

    testWidgets('点分组标题可展开，展开后按钮显示「值 (数量)」并可点选', (WidgetTester tester) async {
      ctrl.items.assignAll(<Torrent>[
        mk(hash: 'a', category: '电影'),
        mk(hash: 'b'),
      ]);

      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: SortFilterPanel())),
      );
      await tester.pump();

      expect(find.text('电影 (1)'), findsNothing, reason: '默认收起，不应有内容');

      await tester.tap(find.text('分类'));
      await tester.pump();

      expect(find.text('电影 (1)'), findsOneWidget);
      expect(find.text('未分类 (1)'), findsOneWidget);

      await tester.tap(find.text('电影 (1)'));
      await tester.pump();
      expect(ctrl.selection(FilterDim.category), contains('电影'));
    });

    testWidgets('点排序维度按钮立即生效', (WidgetTester tester) async {
      ctrl.items.assignAll(<Torrent>[mk(hash: 'a')]);

      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: SortFilterPanel())),
      );
      await tester.pump();

      await tester.tap(find.text('分享比率'));
      await tester.pump();
      expect(ctrl.sortKey.value, TorrentSortKey.ratio);

      await tester.tap(find.text('升序'));
      await tester.pump();
      expect(ctrl.sortDesc.value, isFalse);
    });
  });

  group('站点派生：中文转码', () {
    test('磁力链里的百分号编码 + punycode 中文域名会被还原', () {
      final Torrent t = mk(
        hash: 'a',
        magnetUri: 'magnet:?xt=urn:btih:AAA&tr=http%3A%2F%2Fxn--fiqs8s.example%2Fannounce',
      );
      expect(t.site, '中国.example');
    });

    test('注释里的发布页优先于磁力链', () {
      final Torrent t = mk(
        hash: 'a',
        comment: 'http://tracker.example/details.php?id=1',
        magnetUri: 'magnet:?xt=urn:btih:AAA&tr=http%3A%2F%2Fother.example%2Fa',
      );
      expect(t.site, 'tracker.example');
    });

    test('两条来源都没有时返回空串（上层显示「未知站点」）', () {
      expect(mk(hash: 'a').site, '');
    });
  });
}
