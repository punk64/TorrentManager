import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/models/torrent.dart';

Torrent _t(String hash, int size, String? dir) => Torrent(
      hash: hash,
      name: '种子$hash',
      size: size,
      progress: 0.5,
      state: 'downloading',
      dlSpeed: 0,
      upSpeed: 0,
      numSeeds: 0,
      numLeechs: 0,
      ratio: 0,
      savePath: dir,
    );

void main() {
  final Torrent main = _t('h1', 500, '/dl/show');
  final Torrent sub = _t('h2', 500, '/dl/show/');
  final Torrent other = _t('h3', 700, '/dl/show');
  final List<Torrent> all = <Torrent>[main, sub, other];
  final List<Torrent> chosen = <Torrent>[main];

  group('第 58 轮 A · P0-1 只勾「无辅种时删除文件」不能误删文件', () {
    test('A1 ★ 有辅种 + **只勾第三项** → 必须不删文件', () {
      final DeletePlan p = TorrentController.planDelete(
        all: all,
        chosen: chosen,

        noSubDeleteFiles: true,
      );
      expect(p.deleteFiles, isFalse,
          reason: '★ 该资源有辅种（h2 同目录同体积）⇒ 删文件会破坏共享数据。'
              '修复前这里是 true：`subs` 只在 deleteSub 为真时才被填充，'
              '于是"有没有辅种"永远被判成"没有"');
    });

    test('A2 无辅种 + 只勾第三项 → 顺手删文件（这是该选项的本意）', () {
      final DeletePlan p = TorrentController.planDelete(
        all: <Torrent>[main, other],
        chosen: chosen,
        noSubDeleteFiles: true,
      );
      expect(p.deleteFiles, isTrue,
          reason: '真的没有辅种 ⇒ 不存在"误删共享数据"的风险');
    });

    test('A3 三个都不勾 → 不删文件、不删辅种', () {
      final DeletePlan p = TorrentController.planDelete(all: all, chosen: chosen);
      expect(p.deleteFiles, isFalse);
      expect(p.subs, isEmpty);
    });

    test('A4 只勾「删除辅种」→ 删辅种任务、但不删文件', () {
      final DeletePlan p = TorrentController.planDelete(
        all: all,
        chosen: chosen,
        deleteSub: true,
      );
      expect(p.subs.map((Torrent t) => t.hash), <String>['h2']);
      expect(p.deleteFiles, isFalse);
    });

    test('A5 只勾「删除文件」→ 不碰辅种', () {
      final DeletePlan p = TorrentController.planDelete(
        all: all,
        chosen: chosen,
        deleteFiles: true,
      );
      expect(p.deleteFiles, isTrue);
      expect(p.subs, isEmpty, reason: '没勾「删除辅种」就不该动别人的任务');
    });
  });

  group('第 58 轮 B · P0-2 辅种单独一批且恒不删文件', () {
    test('B1 ★ 勾「删除文件 + 删除辅种」→ 辅种那一批不得删文件', () {
      final DeletePlan p = TorrentController.planDelete(
        all: all,
        chosen: chosen,
        deleteFiles: true,
        deleteSub: true,
      );
      expect(p.subs, isNotEmpty, reason: '前置：确实识别出了辅种');

      final List<DeleteBatch> bs =
          TorrentController.planBatches(chosen: chosen, plan: p);
      expect(bs.length, 2,
          reason: '★ 主项与辅种必须是**两个**请求 —— qB / TR 的删除接口'
              '都无法对同一请求内的不同 id 分别设置 deleteFiles');

      expect(bs[0].deleteFiles, isTrue, reason: '主项：用户勾了「删除文件」');
      expect(bs[1].deleteFiles, isFalse,
          reason: '★ 辅种**一律不删文件**（planDelete 的承诺）—— '
              '修复前主项与辅种共用一个 deleteFiles，辅种的文件被一并删掉');
      expect(bs[0].items.map((Torrent t) => t.hash), <String>['h1']);
      expect(bs[1].items.map((Torrent t) => t.hash), <String>['h2']);
    });

    test('B2 没勾「删除辅种」→ 只有一批（不碰别人的任务）', () {
      final DeletePlan p = TorrentController.planDelete(
        all: all,
        chosen: chosen,
        deleteFiles: true,
      );
      final List<DeleteBatch> bs =
          TorrentController.planBatches(chosen: chosen, plan: p);
      expect(bs.length, 1);
      expect(bs.single.items.map((Torrent t) => t.hash), <String>['h1']);
      expect(bs.single.deleteFiles, isTrue);
    });

    test('B3 只勾「删除辅种」→ 两批，都不删文件', () {
      final DeletePlan p = TorrentController.planDelete(
        all: all,
        chosen: chosen,
        deleteSub: true,
      );
      final List<DeleteBatch> bs =
          TorrentController.planBatches(chosen: chosen, plan: p);
      expect(bs.length, 2);
      expect(bs.every((DeleteBatch b) => !b.deleteFiles), isTrue,
          reason: '一个「删除文件」都没勾 ⇒ 两批都不该删文件');
    });

    test('B4 ★ 只勾第三项（无辅种时删文件）→ 有辅种时辅种也不删文件', () {
      final DeletePlan p = TorrentController.planDelete(
        all: all,
        chosen: chosen,
        noSubDeleteFiles: true,
      );
      expect(p.deleteFiles, isFalse, reason: '前置：A1 已钉住');
      final List<DeleteBatch> bs =
          TorrentController.planBatches(chosen: chosen, plan: p);

      expect(bs.length, 1);
      expect(bs.single.deleteFiles, isFalse);
    });
  });
}
