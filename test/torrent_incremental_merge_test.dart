













import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/data/models/torrent.dart';

Torrent _seed() => const Torrent(
      hash: 'abc123',
      name: 'Ubuntu 24.04.iso',
      size: 5 * 1024 * 1024 * 1024,
      progress: 0.42,
      state: 'downloading',
      dlSpeed: 1024,
      upSpeed: 64,
      numSeeds: 7,
      numLeechs: 2,
      ratio: 1.25,
      savePath: '/downloads',
      category: 'linux',
      addedOn: 1700000000,
      trackerCount: 3,
    );

void main() {
  group('Torrent.updateQbData 增量合并', () {
    test('只有速度变化的增量不能抹掉名称与大小', () {
      final Torrent merged = _seed().updateQbData(<String, dynamic>{
        'dlspeed': 2048,
      });

      expect(merged.dlSpeed, 2048, reason: '增量里的字段必须生效');
      
      expect(merged.name, 'Ubuntu 24.04.iso');
      expect(merged.size, 5 * 1024 * 1024 * 1024);
      expect(merged.progress, 0.42);
      expect(merged.state, 'downloading');
    });

    test('增量缺席的其余字段全部保持原值', () {
      final Torrent a = _seed();
      final Torrent b = a.updateQbData(<String, dynamic>{'upspeed': 999});

      expect(b.upSpeed, 999);
      expect(b.hash, a.hash);
      expect(b.name, a.name);
      expect(b.size, a.size);
      expect(b.progress, a.progress);
      expect(b.state, a.state);
      expect(b.dlSpeed, a.dlSpeed);
      expect(b.numSeeds, a.numSeeds);
      expect(b.numLeechs, a.numLeechs);
      expect(b.ratio, a.ratio);
      expect(b.savePath, a.savePath);
      expect(b.category, a.category);
      expect(b.addedOn, a.addedOn);
      expect(b.trackerCount, a.trackerCount);
    });

    test('多字段增量逐个生效，未涉及的字段不动', () {
      final Torrent merged = _seed().updateQbData(<String, dynamic>{
        'progress': 1.0,
        'state': 'seeding',
        'num_seeds': 0,
        'ratio': 3.5,
      });

      expect(merged.progress, 1.0);
      expect(merged.state, 'seeding');
      expect(merged.numSeeds, 0);
      expect(merged.ratio, 3.5);
      
      expect(merged.dlSpeed, 1024);
      expect(merged.name, 'Ubuntu 24.04.iso');
    });

    test('空增量返回自身，不产生任何变化', () {
      final Torrent a = _seed();
      final Torrent b = a.updateQbData(<String, dynamic>{});
      expect(b.name, a.name);
      expect(b.size, a.size);
      expect(b.dlSpeed, a.dlSpeed);
    });

    test('Transmission 侧 id（trId）在合并后不丢失', () {
      const Torrent t = Torrent(
        hash: 'h1',
        name: 'n1',
        size: 1,
        progress: 0,
        state: 'stopped',
        dlSpeed: 0,
        upSpeed: 0,
        numSeeds: 0,
        numLeechs: 0,
        ratio: 0,
        trId: 42,
      );
      expect(t.updateQbData(<String, dynamic>{'dlspeed': 10}).trId, 42);
    });
  });

  group('缺陷复现：整对象替换会造出空白种子', () {
    test('fromJson 处理残缺增量 → 名称为空（这就是空白卡片的成因）', () {
      final Torrent blank = Torrent.fromJson(<String, dynamic>{
        'hash': 'abc123',
        'dlspeed': 2048,
      });

      
      
      
      expect(blank.name, isEmpty);
      expect(blank.size, 0);
      expect(blank.state, 'unknown');
      expect(blank.dlSpeed, 2048);
    });

    test('合并路径不会产出空白种子', () {
      final Torrent merged = _seed().updateQbData(<String, dynamic>{
        'dlspeed': 2048,
      });
      expect(merged.name, isNotEmpty);
      expect(merged.size, greaterThan(0));
      expect(merged.state, isNot('unknown'));
    });
  });
}
