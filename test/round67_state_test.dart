import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/utils/formatter.dart';
import 'package:torrent_manager/utils/strings.dart';

Torrent tOf(String state, {double progress = 0.5}) => Torrent(
      hash: 'h1',
      name: 'n1',
      size: 100,
      progress: progress,
      state: state,
      dlSpeed: 0,
      upSpeed: 0,
      numSeeds: 0,
      numLeechs: 0,
      ratio: 0,
    );

void main() {
  group('第 67 轮 · 两级状态（主级 statusGroup / 细分级 rawState）', () {
    test('qB 主状态归类：stalledDL→下载中、forcedUP→做种中', () {
      expect(tOf('stalledDL').statusGroup, TorrentStatusGroup.downloading);
      expect(tOf('forcedDL').statusGroup, TorrentStatusGroup.downloading);
      expect(tOf('metaDL').statusGroup, TorrentStatusGroup.downloading);
      expect(tOf('stalledUP').statusGroup, TorrentStatusGroup.seeding);
      expect(tOf('forcedUP').statusGroup, TorrentStatusGroup.seeding);
      expect(tOf('uploading').statusGroup, TorrentStatusGroup.seeding);
    });

    test('★ pausedUP 主级是「暂停」而不是「做种」（旧写法含 up 会误判）', () {
      expect(tOf('pausedUP').statusGroup, TorrentStatusGroup.paused);
      expect(tOf('pausedDL').statusGroup, TorrentStatusGroup.paused);
      expect(tOf('stopped').statusGroup, TorrentStatusGroup.paused);
    });

    test('排队 / 校验 / 错误各自成组', () {
      expect(tOf('queuedDL').statusGroup, TorrentStatusGroup.queued);
      expect(tOf('checkingDL').statusGroup, TorrentStatusGroup.checking);
      expect(tOf('error').statusGroup, TorrentStatusGroup.error);
      expect(tOf('missingFiles').statusGroup, TorrentStatusGroup.error);
    });

    test('细分级 rawState：qB 回落 state、TR 保留数字串', () {

      final Torrent qb = Torrent.fromJson(<String, dynamic>{
        'hash': 'h',
        'name': 'n',
        'state': 'stalledDL',
      });
      expect(qb.rawState, 'stalledDL');
      expect(qb.statusGroup, TorrentStatusGroup.downloading);
    });
  });

  group('第 67 轮 · 状态显示（Formatter.setStatus 补 forced/stalled）', () {
    test('★ 四个新分支不再退化成「下载中 / 做种」', () {
      expect(Formatter.setStatus('forcedDL'), S.stForcedDl);
      expect(Formatter.setStatus('forcedDL'), isNot(Formatter.setStatus('downloading')));
      expect(Formatter.setStatus('forcedUP'), S.stForcedUp);
      expect(Formatter.setStatus('forcedUP'), isNot(Formatter.setStatus('seeding')));
      expect(Formatter.setStatus('stalledDL'), S.stStalledDl);
      expect(Formatter.setStatus('stalledUP'), S.stStalledUp);
    });

    test('既有状态不受影响（暂停优先于通用 up/dl）', () {
      expect(Formatter.setStatus('pausedUP'), S.stPausedUp);
      expect(Formatter.setStatus('pausedDL'), S.stPausedDl);
      expect(Formatter.setStatus('metaDL'), S.stMetaDl);
      expect(Formatter.setStatus('downloading'), isNot(S.stForcedDl));
    });
  });

  group('第 67 轮 · 筛选修正（TorrentFilter.matches）', () {
    test('★ pausedUP 不再同时命中「做种」和「暂停」', () {
      final Torrent pausedUp = tOf('pausedUP', progress: 1.0);
      expect(TorrentFilter.seeding.matches(pausedUp), isFalse,
          reason: 'pausedUP 含 up，旧实现会误命中做种');
      expect(TorrentFilter.paused.matches(pausedUp), isTrue);
    });

    test('pausedDL 不再命中「下载中」；stalledDL 命中「下载中」', () {
      expect(TorrentFilter.downloading.matches(tOf('pausedDL')), isFalse);
      expect(TorrentFilter.downloading.matches(tOf('stalledDL')), isTrue);
      expect(TorrentFilter.downloading.matches(tOf('metaDL')), isTrue);
    });

    test('已完成按进度判、活跃按速度判（保持原语义）', () {
      expect(TorrentFilter.completed.matches(tOf('pausedUP', progress: 1.0)),
          isTrue);
      expect(TorrentFilter.completed.matches(tOf('downloading')), isFalse);
      expect(TorrentFilter.active.matches(tOf('downloading')), isFalse);
    });
  });

  group('第 67 轮 · TR 解析（限速单位 / 原始状态 / 队列位置）', () {
    test('★ 限速单位统一为 bytes/s：TR 的 KB/s ×1024', () {
      final List<Torrent> out =
          TorrentController.fromTr(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 7,
          'hashString': 'abc',
          'name': 'x',
          'status': 4,
          'downloadLimit': 2048,
          'downloadLimited': true,
          'uploadLimit': 512,
          'uploadLimited': true,
        },
      ]);
      expect(out.single.dlLimit, 2048 * 1024,
          reason: '模型恒为 bytes/s，UI 显示时再 ÷1024');
      expect(out.single.upLimit, 512 * 1024);
      expect(out.single.dlLimitedEnabled, isTrue);
      expect(out.single.upLimitedEnabled, isTrue);
    });

    test('没开限速开关时 Limited=false（避免"限速值有、开关没开"的错觉）', () {
      final List<Torrent> out =
          TorrentController.fromTr(<Map<String, dynamic>>[
        <String, dynamic>{
          'hashString': 'abc',
          'status': 6,
          'downloadLimit': 0,
          'downloadLimited': false,
        },
      ]);
      expect(out.single.dlLimit, 0);
      expect(out.single.dlLimitedEnabled, isFalse);
    });

    test('原始状态与队列位置：rawState=status 数字串、priority=queuePosition', () {
      final List<Torrent> out =
          TorrentController.fromTr(<Map<String, dynamic>>[
        <String, dynamic>{
          'hashString': 'abc',
          'status': 4,
          'queuePosition': 3,
          'bandwidthPriority': 1,
          'isPrivate': true,
        },
      ]);
      expect(out.single.rawState, '4');
      expect(out.single.state, 'downloading');
      expect(out.single.priority, 3,
          reason: 'TR 的 queuePosition 与 qB 的 priority 同义 ⇒ 复用该字段');
      expect(out.single.bandwidthPriority, 1);
      expect(out.single.isPrivate, isTrue);
    });

    test('TR 没有强制做种等四项 ⇒ 恒 null（UI 据此隐藏）', () {
      final List<Torrent> out =
          TorrentController.fromTr(<Map<String, dynamic>>[
        <String, dynamic>{'hashString': 'abc', 'status': 6},
      ]);
      expect(out.single.forceStart, isNull);
      expect(out.single.sequentialDownload, isNull);
      expect(out.single.firstLastPiecePrio, isNull);
      expect(out.single.superSeeding, isNull);
    });
  });

  group('第 67 轮 · TR 接口层（字段清单收敛 + setForceStart 语义）', () {
    final String src =
        File('lib/data/transmission/tr_method.dart').readAsStringSync();

    test('★ 字段清单只有一份，且包含全部新增字段', () {
      final int start = src.indexOf('static const List<String> _trFields');
      final int end = src.indexOf('];', start);
      expect(start, greaterThan(-1));
      final String block = src.substring(start, end);

      for (final String f in <String>[
        'downloadLimit',
        'downloadLimited',
        'uploadLimit',
        'uploadLimited',
        'isPrivate',
        'bandwidthPriority',
        'leftUntilDone',
        'corruptEver',
        'errorString',
        'metadataPercentComplete',
        'downloadDirFreeSpace',
        'seedRatioMode',
        'seedRatioLimit',
        'seedIdleMode',
        'seedIdleLimit',
      ]) {
        expect(block.contains("'$f'"), isTrue,
            reason: '字段 $f 必须在共享清单里（漏了就"列表没值、详情有值"）');
      }

      final int g = src.indexOf('Future<List<Map<String, dynamic>>> torrentGet(');
      final String fn = src.substring(
          g, src.indexOf('Future<List<Map<String, dynamic>>> updateSelect(', g));
      expect(fn.contains("'fields': <String>["), isFalse,
          reason: 'torrent-get 不该再写字面量清单（曾经 lite/完整各写一份）');
      expect(fn.contains("'fields': lite ?"), isTrue,
          reason: 'torrent-get 应统一引用共享常量');
      expect(src.contains('..._trFields'), isTrue,
          reason: '完整清单应由共享清单 + trackerStats 拼出');
    });

    test('★ setForceStart 已改名（它其实只是"是否遵守全局限速"）', () {
      expect(src.contains('Future<void> setForceStart('), isFalse,
          reason: 'TR 没有强制做种，留着旧名会让 UI 误导');
      expect(src.contains('setHonorsSessionLimits'), isTrue);
      expect(src.contains('setQueuePosition'), isTrue);
      expect(src.contains('setBandwidthPriority'), isTrue);
      expect(src.contains('setIdleLimit'), isTrue);
    });
  });

  group('第 67 轮 · 编辑草稿（存 controller，不放 widget state）', () {
    test('写入 / 读取 / 单个丢弃 / 全部清空', () {
      Get.put(ServerController());
      final TorrentController tc = TorrentController();

      expect(tc.hasDraft('h1'), isFalse);
      tc.setDraft('h1', 'dlLimit', 1024);
      expect(tc.draftOf('h1', 'dlLimit'), 1024);
      expect(tc.hasDraft('h1'), isTrue);

      tc.setDraft('h1', 'tags', 'a,b');
      expect(tc.draftOf('h1', 'dlLimit'), 1024);
      expect(tc.draftOf('h1', 'tags'), 'a,b');

      tc.setDraft('h2', 'dlLimit', 2048);
      expect(tc.draftOf('h2', 'dlLimit'), 2048);
      expect(tc.draftOf('h1', 'dlLimit'), 1024);

      tc.clearDraft('h1');
      expect(tc.hasDraft('h1'), isFalse);
      expect(tc.draftOf('h1', 'dlLimit'), isNull);
      expect(tc.hasDraft('h2'), isTrue, reason: '清一个不能连带清别的');

      tc.clearAllDrafts();
      expect(tc.hasDraft('h2'), isFalse);

      tc.dispose();
    });
  });

  group('第 67 轮 · 站点主域名（Formatter.registrableDomain）', () {
    test('裁掉子域，保留主域名.根域名', () {
      expect(Formatter.registrableDomain('tracker.example.com'), 'example.com');
      expect(Formatter.registrableDomain('a.b.example.com'), 'example.com');
      expect(
          Formatter.registrableDomain(
              'https://tracker.example.com:443/announce'),
          'example.com');
    });

    test('两级后缀要多带一级（com.cn / co.uk）', () {
      expect(Formatter.registrableDomain('bt.example.com.cn'), 'example.com.cn');
      expect(Formatter.registrableDomain('a.b.example.co.uk'), 'example.co.uk');
    });

    test('punycode 还原、IPv4 与空值原样返回', () {

      expect(Formatter.registrableDomain('tracker.xn--fiqs8s.com'), '中国.com');
      expect(Formatter.registrableDomain('xn--fiqs8s.xn--fiqs8s'), '中国.中国');
      expect(Formatter.registrableDomain('1.2.3.4'), '1.2.3.4');
      expect(Formatter.registrableDomain('http://[::1]:51413/announce'),
          '[::1]');
      expect(Formatter.registrableDomain(null), '');
      expect(Formatter.registrableDomain('  '), '');
    });
  });
}
