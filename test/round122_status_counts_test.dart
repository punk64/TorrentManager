import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';

Torrent _t(
  String hash,
  String state, {
  double progress = 0.5,
  int upSpeed = 0,
  int dlSpeed = 0,
  int seeds = 0,
  int leechs = 0,
}) =>
    Torrent(
      hash: hash,
      name: hash,
      size: 1024,
      progress: progress,
      state: state,
      dlSpeed: dlSpeed,
      upSpeed: upSpeed,
      numSeeds: seeds,
      numLeechs: leechs,
      ratio: 1.0,
    );

void main() {
  group('① 单颗种子只落一个桶', () {
    test('downloading 只算下载中', () {
      final TorrentStatusCounts c =
          TorrentStatusCounts.of(<Torrent>[_t('a', 'downloading', upSpeed: 4096)]);
      expect(c.downloading, 1);
      expect(c.seeding, 0);
      expect(c.total, 1);
      expect(c.ribbon.reduce((int a, int b) => a + b), 1);
    });

    test('上传流量不再把下载中的种子算成做种', () {
      final TorrentStatusCounts c =
          TorrentStatusCounts.of(<Torrent>[_t('a', 'stalledDL', upSpeed: 1024)]);
      expect(c.downloading, 1);
      expect(c.seeding, 0);
    });

    test('无知状态归于 other 而非消失', () {
      final TorrentStatusCounts c =
          TorrentStatusCounts.of(<Torrent>[_t('a', 'unknown')]);
      expect(c.other, 1);
      expect(c.total, 1);
    });
  });

  group('② 校验不再与下载/做种双计', () {
    test('checkingDL 只算校验', () {
      final TorrentStatusCounts c =
          TorrentStatusCounts.of(<Torrent>[_t('a', 'checkingDL')]);
      expect(c.checking, 1);
      expect(c.downloading, 0);
    });

    test('checkingUP 只算校验', () {
      final TorrentStatusCounts c =
          TorrentStatusCounts.of(<Torrent>[_t('a', 'checkingUP', progress: 1)]);
      expect(c.checking, 1);
      expect(c.seeding, 0);
    });
  });

  group('③ TR 排队与 qB 过渡态不再漏计', () {
    test('TR 的 queued 与 stopped 各归其位', () {
      final TorrentStatusCounts c = TorrentStatusCounts.of(<Torrent>[
        _t('a', 'queued'),
        _t('b', 'stopped'),
      ]);
      expect(c.queued, 1);
      expect(c.paused, 1);
      expect(c.total, 2);
    });

    test('qB 排队仍有下载/做种去向', () {
      final TorrentStatusCounts c = TorrentStatusCounts.of(<Torrent>[
        _t('a', 'queuedDL'),
        _t('b', 'queuedUP', progress: 1),
      ]);
      expect(c.queued, 2);
      expect(c.downloading, 0);
      expect(c.seeding, 0);
    });

    test('moving 与 allocating 独立归类', () {
      final TorrentStatusCounts c = TorrentStatusCounts.of(<Torrent>[
        _t('a', 'moving'),
        _t('b', 'allocating'),
      ]);
      expect(c.moving, 1);
      expect(c.other, 1);
      expect(c.total, 2);
    });
  });

  group('④ 卡片口径闭合', () {
    test('混杂状态：ribbon 加 other 等于总数', () {
      final List<Torrent> list = <Torrent>[
        _t('a', 'downloading', upSpeed: 2048),
        _t('b', 'uploading', progress: 1, upSpeed: 1024),
        _t('c', 'queuedDL'),
        _t('d', 'stoppedUP', progress: 1),
        _t('e', 'checkingResumeData'),
        _t('f', 'error'),
        _t('g', 'moving'),
        _t('h', 'allocating'),
        _t('i', 'missingFiles'),
      ];
      final TorrentStatusCounts c = TorrentStatusCounts.of(list);
      expect(c.total, list.length);
      expect(c.ribbon.reduce((int a, int b) => a + b) + c.other, list.length);
      expect(c.rest, c.queued + c.moving + c.other);
    });

    test('ServerData 分项之和不超过总数', () {
      final ServerData s = ServerData(
        id: 's1',
        name: 'x',
        type: 'qbittorrent',
        host: 'nas',
        port: 8080,
      ).copyWith(torrents: <Torrent>[
        _t('a', 'downloading', upSpeed: 999),
        _t('b', 'pausedDL'),
      ]);
      expect(s.totalTorrents, 2);
      expect(s.totalDownloading + s.totalPausedDL, 2);
    });
  });

  group('⑤ 连接数口径统一', () {
    test('qB 无 active_peers 时不因速度为 0 而归零', () {
      final Torrent t = _t('a', 'downloading', seeds: 3, leechs: 4);
      expect(t.activePeers, -1);
      expect(t.transferPeers, 7);
    });

    test('TR 给出精确值时优先', () {
      final Torrent t = _t('a', 'downloading');
      const Torrent exact = Torrent(
        hash: 'a',
        name: 'a',
        size: 1024,
        progress: 0.5,
        state: 'downloading',
        dlSpeed: 0,
        upSpeed: 0,
        numSeeds: 0,
        numLeechs: 0,
        ratio: 1.0,
        activePeers: 11,
      );
      expect(t.transferPeers, 0);
      expect(exact.transferPeers, 11);
    });
  });
}
