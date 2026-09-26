import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/utils/app_log.dart';

Torrent _t(
  String hash, {
  int dlSpeed = 0,
  int upSpeed = 0,
  int uploaded = 0,
  int downloaded = 0,
}) =>
    Torrent(
      hash: hash,
      name: hash,
      size: 1024,
      progress: 0.5,
      state: 'downloading',
      dlSpeed: dlSpeed,
      upSpeed: upSpeed,
      numSeeds: 1,
      numLeechs: 1,
      ratio: 1.0,
      activePeers: 2,
      uploaded: uploaded,
      downloaded: downloaded,
    );

ServerData _srv(String id) => ServerData(
      id: id,
      name: id,
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'admin',
      password: 'adminadmin',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
    Get.reset();
    AppLog.instance.clear();
    Get.put(ServerController(), permanent: true);
  });

  tearDown(() {
    Get.reset();
  });

  ServerController sc() => Get.find<ServerController>();

  test('★ 有实时缓存 → available = true，数值照实给', () {
    final ServerController c = sc();
    c.servers.assignAll(<ServerData>[_srv('a')]);
    c.reportConnected('a');
    c.cacheTorrents('a', <Torrent>[
      _t('h1', dlSpeed: 1024, upSpeed: 512, downloaded: 2048, uploaded: 4096),
    ]);

    final TotalsSnapshot v = c.totalsView;
    expect(v.available, isTrue);
    expect(v.dlSpeed, 1024);
    expect(v.upSpeed, 512);
    expect(v.totals.downloadedBytes, 2048);
    expect(v.serversOnline, 1, reason: '在线数恒为实时值');
  });

  test('★ 没有服务器连接 → available = false（UI 显示 `--` 占位）', () {
    final ServerController c = sc();
    c.servers.assignAll(<ServerData>[_srv('a')]);
    c.reportConnected('a');
    c.cacheTorrents('a', <Torrent>[
      _t('h1', dlSpeed: 1024, upSpeed: 512, downloaded: 2048, uploaded: 4096),
    ]);

    c.torrentCache.clear();
    c.torrentCache.refresh();
    c.reportFailure('a', Exception('boom'));

    final TotalsSnapshot v = c.totalsView;
    expect(v.available, isFalse,
        reason: '★ 全部离线时必须标记「无数据」，让 UI 画 `--`');
    expect(v.dlSpeed, 0, reason: '占位态数值归零，由 UI 负责渲染成 `--`');
    expect(v.totals.downloadedBytes, 0);
    expect(v.counts.total, 0);
    expect(v.serversOnline, 0, reason: '在线数仍按实时显示 0/N');
    expect(v.serversTotal, 1);
  });

  test('★ 运行中断网：缓存还在、状态转 failed → 仍必须显示 `--`', () {
    final ServerController c = sc();
    c.servers.assignAll(<ServerData>[_srv('a')]);
    c.reportConnected('a');
    c.cacheTorrents('a', <Torrent>[
      _t('h1', dlSpeed: 1024, upSpeed: 512, downloaded: 2048, uploaded: 4096),
    ]);

    c.reportFailure('a', Exception('network unreachable'));

    final TotalsSnapshot v = c.totalsView;
    expect(v.available, isFalse,
        reason: '★ 全部服务器 failed 时，缓存再新也是旧数据，必须 `--`');
    expect(v.serversOnline, 0);
    expect(v.serversTotal, 1);
  });

  test('★ 只要还有一台有缓存 → 用实时值（available = true）', () {
    final ServerController c = sc();
    c.servers.assignAll(<ServerData>[_srv('a'), _srv('b')]);
    c.reportConnected('a');
    c.reportConnected('b');
    c.cacheTorrents('a', <Torrent>[_t('h1', dlSpeed: 999, downloaded: 111)]);
    c.cacheTorrents('b', <Torrent>[_t('h2', dlSpeed: 111, downloaded: 222)]);

    c.torrentCache.remove('a');
    c.torrentCache.refresh();

    final TotalsSnapshot v = c.totalsView;
    expect(v.available, isTrue);
    expect(v.dlSpeed, 111);
    expect(v.totals.downloadedBytes, 222);
  });

  test('★ 启动后还没拉到数据 → available = false（不虚构、不显示 0）', () {
    final ServerController c = sc();
    c.servers.assignAll(<ServerData>[_srv('a')]);

    final TotalsSnapshot v = c.totalsView;
    expect(v.available, isFalse);
    expect(v.dlSpeed, 0);
    expect(v.counts.total, 0);
    expect(v.serversTotal, 1);
  });

  test('★ 连上了但种子数为 0 → 仍是有效数据（显示 0，不是 `--`）', () {
    final ServerController c = sc();
    c.servers.assignAll(<ServerData>[_srv('a')]);
    c.reportConnected('a');
    c.cacheTorrents('a', <Torrent>[]);

    final TotalsSnapshot v = c.totalsView;
    expect(v.available, isTrue,
        reason: '★ 「确实连上了、确实 0 个种子」和「连不上」不是一回事');
    expect(v.dlSpeed, 0);
    expect(v.counts.total, 0);
    expect(v.serversOnline, 1);
  });
}
