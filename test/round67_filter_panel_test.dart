import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';

ServerData _server(String type) => ServerData(
      id: 's1',
      name: 'srv',
      type: type,
      host: '1.2.3.4',
      port: 8080,
    );

Torrent _t(String hash, String state, {double progress = 0.5}) => Torrent(
      hash: hash,
      name: 'n-$hash',
      size: 100,
      progress: progress,
      state: state,
      rawState: state,
      dlSpeed: 0,
      upSpeed: 0,
      numSeeds: 0,
      numLeechs: 0,
      ratio: 0,
    );

Torrent _tr(String hash, int status, String state) => Torrent(
      hash: hash,
      name: 'n-$hash',
      size: 100,
      progress: 0.5,
      state: state,
      rawState: '$status',
      dlSpeed: 0,
      upSpeed: 0,
      numSeeds: 0,
      numLeechs: 0,
      ratio: 0,
    );

void main() {
  tearDown(Get.reset);

  group('第 67 轮第二期 · 主状态枚举补齐', () {
    test('排队 / 校验 / 错误 各自成筛选项（旧枚举只有 6 项）', () {
      expect(TorrentFilter.queued.matches(_t('a', 'queuedDL')), isTrue);
      expect(TorrentFilter.checking.matches(_t('b', 'checkingUP')), isTrue);
      expect(TorrentFilter.error.matches(_t('c', 'missingFiles')), isTrue);

      expect(TorrentFilter.paused.matches(_t('a', 'queuedDL')), isFalse);
      expect(TorrentFilter.queued.matches(_t('b', 'checkingUP')), isFalse);
    });

    test('已完成按进度、活跃按速度（保持原语义）', () {
      expect(TorrentFilter.completed.matches(_t('a', 'stoppedUP', progress: 1)),
          isTrue);
      expect(TorrentFilter.active.matches(_t('b', 'downloading')), isFalse);
    });
  });

  group('第 67 轮第二期 · 细分态按服务器类型生成', () {
    test('qB 服务器：主状态「下载中」给出 qB 细分组（含 5.0 的 forcedMetaDL）',
        () {
      Get.put(ServerController());
      final TorrentController tc = TorrentController();
      tc.serverCtrl.current.value = _server('qbittorrent');
      tc.setFilter(TorrentFilter.downloading);

      final List<String> opts = tc.subStateOptions();
      expect(opts, contains('stalledDL'));
      expect(opts, contains('forcedDL'));
      expect(opts, contains('metaDL'));
      expect(opts, contains('forcedMetaDL'));

      expect(opts, isNot(contains('4')));
    });

    test('TR 服务器：主状态「排队」给出 TR status 数字（1/3/5）', () {
      Get.put(ServerController());
      final TorrentController tc = TorrentController();
      tc.serverCtrl.current.value = _server('transmission');
      tc.setFilter(TorrentFilter.queued);

      final List<String> opts = tc.subStateOptions();
      expect(opts, <String>['1', '3', '5']);
      expect(TorrentController.subStateLabel('1'), isNotEmpty);
      expect(TorrentController.subStateLabel('5'), isNotEmpty);
    });

    test('「已完成 / 活跃」不按状态串划分 ⇒ 无细分（面板给提示文案）', () {
      Get.put(ServerController());
      final TorrentController tc = TorrentController();
      tc.serverCtrl.current.value = _server('qbittorrent');
      tc.setFilter(TorrentFilter.completed);
      expect(tc.subStateOptions(), isEmpty);
      tc.setFilter(TorrentFilter.active);
      expect(tc.subStateOptions(), isEmpty);
    });

    test('主状态切换会清空细分（防止「下载中 + stoppedUP」这种空组合）', () {
      Get.put(ServerController());
      final TorrentController tc = TorrentController();
      tc.serverCtrl.current.value = _server('qbittorrent');
      tc.setFilter(TorrentFilter.seeding);
      tc.toggleSubState('forcedUP');
      expect(tc.subStates, <String>['forcedUP']);

      tc.setFilter(TorrentFilter.downloading);
      expect(tc.subStates, isEmpty, reason: '细分依附主状态，换主状态必须清空');

      tc.toggleSubState('stalledDL');
      tc.setFilter(TorrentFilter.downloading);
      expect(tc.subStates, <String>['stalledDL']);
    });
  });

  group('第 67 轮第二期 · 主状态 + 细分叠加过滤', () {
    test('只选主状态：命中该主状态全部细分', () {
      Get.put(ServerController());
      final TorrentController tc = TorrentController();
      tc.serverCtrl.current.value = _server('qbittorrent');
      tc.debugSetItems(<Torrent>[
        _t('a', 'downloading'),
        _t('b', 'stalledDL'),
        _t('c', 'forcedUP'),
      ]);
      tc.setFilter(TorrentFilter.downloading);
      expect(tc.visibleItems.map((Torrent t) => t.hash).toList(),
          <String>['a', 'b']);
    });

    test('叠加细分：只留命中的细分（或关系）', () {
      Get.put(ServerController());
      final TorrentController tc = TorrentController();
      tc.serverCtrl.current.value = _server('qbittorrent');
      tc.debugSetItems(<Torrent>[
        _t('a', 'downloading'),
        _t('b', 'stalledDL'),
        _t('c', 'metaDL'),
      ]);
      tc.setFilter(TorrentFilter.downloading);
      tc.toggleSubState('stalledDL');
      expect(tc.visibleItems.single.hash, 'b');

      tc.toggleSubState('metaDL');
      expect(tc.visibleItems.map((Torrent t) => t.hash).toList(),
          <String>['b', 'c']);

      tc.toggleSubState('stalledDL');
      expect(tc.visibleItems.single.hash, 'c');
    });

    test('TR 侧按 status 数字细分', () {
      Get.put(ServerController());
      final TorrentController tc = TorrentController();
      tc.serverCtrl.current.value = _server('transmission');
      tc.debugSetItems(<Torrent>[
        _tr('a', 3, 'queued'),
        _tr('b', 5, 'queued'),
        _tr('c', 4, 'downloading'),
      ]);
      tc.setFilter(TorrentFilter.queued);
      tc.toggleSubState('3');
      expect(tc.visibleItems.single.hash, 'a');
    });

    test('★ qB 4.x/5.x 暂停态改名：chip 用新名，旧名也能命中', () {
      Get.put(ServerController());
      final TorrentController tc = TorrentController();
      tc.serverCtrl.current.value = _server('qbittorrent');

      tc.debugSetItems(<Torrent>[
        _t('old', 'pausedDL'),
        _t('new', 'stoppedDL'),
      ]);
      tc.setFilter(TorrentFilter.paused);
      tc.toggleSubState('stoppedDL');

      expect(tc.visibleItems.map((Torrent t) => t.hash).toSet(),
          <String>{'old', 'new'},
          reason: '5.0 把 pausedDL 改名为 stoppedDL ⇒ 匹配必须做归一');
      expect(SubStates.normalize('pausedUP'), 'stoppedUP');
    });
  });

  group('第 67 轮第二期 · 列表缓存与顶部摘要（D2）', () {
    test('细分变化会让可见列表缓存失效（token 必须带上 subStates）', () {
      Get.put(ServerController());
      final TorrentController tc = TorrentController();
      tc.serverCtrl.current.value = _server('qbittorrent');
      tc.debugSetItems(<Torrent>[
        _t('a', 'stalledDL'),
        _t('b', 'forcedDL'),
      ]);
      tc.setFilter(TorrentFilter.downloading);
      expect(tc.visibleItems.length, 2);
      tc.toggleSubState('stalledDL');
      expect(tc.visibleItems.single.hash, 'a',
          reason: 'token 漏了 subStates 会导致列表不刷新');
    });

    test('顶部摘要：未选状态为空；选中显示主状态 + 细分', () {
      Get.put(ServerController());
      final TorrentController tc = TorrentController();
      tc.serverCtrl.current.value = _server('qbittorrent');
      expect(tc.statusSummaryText, isEmpty);
      expect(tc.hasStatusFilter, isFalse);

      tc.setFilter(TorrentFilter.seeding);
      expect(tc.statusSummaryText, TorrentFilter.seeding.label);
      expect(tc.hasStatusFilter, isTrue);

      tc.toggleSubState('forcedUP');
      expect(tc.statusSummaryText, contains(TorrentFilter.seeding.label));
      expect(tc.statusSummaryText, contains('强制做种'));

      tc.clearStatus();
      expect(tc.hasStatusFilter, isFalse);
      expect(tc.statusSummaryText, isEmpty);
    });
  });

  group('第 67 轮第二期 · 面板与列表页接线（源码级回归）', () {
    final String panel = File('lib/widgets/sort_filter_panel.dart')
        .readAsStringSync();
    final String listPage =
        File('lib/pages/torrent_list_page.dart').readAsStringSync();

    test('筛选面板新增状态区，并挂在排序区之后', () {
      expect(panel.contains('_statusSection()'), isTrue);

      expect(panel.contains('_statusGrid()'), isTrue);
      expect(panel.contains('_statusDropdown('), isFalse);
      expect(panel.contains('_subStateChips()'), isTrue);
      final int sortAt = panel.indexOf('_sortSection(),');
      final int statusAt = panel.indexOf('_statusSection(),');
      expect(sortAt, greaterThan(0));
      expect(statusAt, greaterThan(sortAt));
    });

    test('面板细分 chip 走共享的 _btn（不再自造一套样式）', () {
      expect(panel.contains('TorrentController.subStateLabel(v)'), isTrue);
      expect(panel.contains('ctrl.toggleSubState(v)'), isTrue);
    });

    test('★ D2：顶部横条不再遍历 TorrentFilter 铺一排 chip', () {
      expect(listPage.contains('for (final TorrentFilter f in TorrentFilter.values)'),
          isFalse,
          reason: '状态横条已收进面板，顶部只留「已选状态 + 清除」');
      expect(listPage.contains('ctrl.statusSummaryText'), isTrue);
      expect(listPage.contains('showSortFilterPanel(context)'), isTrue);
    });
  });
}
