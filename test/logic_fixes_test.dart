import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/local_store.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/utils/formatter.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';

Torrent mk({
  required String hash,
  int size = 100,
  String state = 'downloading',
  double progress = 0.5,
  String? savePath,
  String? tags,
}) =>
    Torrent(
      hash: hash,
      name: '种子$hash',
      size: size,
      progress: progress,
      state: state,
      dlSpeed: 0,
      upSpeed: 0,
      numSeeds: 0,
      numLeechs: 0,
      ratio: 0,
      savePath: savePath,
      tags: tags,
    );

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

  group('① setTime 不再把长时长显示成 ∞', () {
    test('做种 110 天应显示真实天数', () {
      final String s = Formatter.setTime(9500000);
      expect(s, isNot('∞'), reason: '∞ 只属于 ETA 语义，不属于「做种时长」');
      expect(s.startsWith('109'), isTrue, reason: '实际输出：$s');
    });

    test('恰好 100 天（8640000 秒）也不再是 ∞', () {
      expect(Formatter.setTime(8640000), isNot('∞'));
    });

    test('setEta 仍然把 8640000（qB 的"无限"）显示成 -', () {
      expect(Formatter.setEta(8640000), '-');
      expect(Formatter.setEta(0), '-');
      expect(Formatter.setEta(60), isNot('-'));
    });
  });

  group('② 暂停态不再计入「下载中 / 做种」', () {
    test('pausedDL 只算暂停，不算下载中', () {
      final Torrent t = mk(hash: 'a', state: 'pausedDL');
      expect(t.isPause, isTrue);
      expect(t.isDownloading, isFalse, reason: '暂停的下载不该计入「下载中」');
      expect(t.isPausedDL, isTrue);
    });

    test('pausedUP 只算暂停，不算做种', () {
      final Torrent t = mk(hash: 'a', state: 'pausedUP', progress: 1);
      expect(t.isSeeding, isFalse);
      expect(t.isPausedUP, isTrue);
    });

    test('stalledDL / queuedDL 仍算下载中（它们不是暂停）', () {
      expect(mk(hash: 'a', state: 'stalledDL').isDownloading, isTrue);
      expect(mk(hash: 'a', state: 'queuedDL').isDownloading, isTrue);
    });

    test('stoppedUP（TR 的暂停做种）不算做种', () {
      final Torrent t = mk(hash: 'a', state: 'stoppedUP', progress: 1);
      expect(t.isSeeding, isFalse);
    });

    test('统计互斥：同一颗种子不会同时出现在「下载中」与「暂停」两栏', () {
      final List<Torrent> list = <Torrent>[
        mk(hash: 'a', state: 'downloading'),
        mk(hash: 'b', state: 'pausedDL'),
      ];
      final ServerData s = ServerData(
        id: 's1',
        name: 'x',
        type: 'qbittorrent',
        host: 'nas',
        port: 8080,
      ).copyWith(torrents: list);
      expect(s.totalDownloading, 1);
      expect(s.totalPausedDL, 1);
      expect(s.totalDownloading + s.totalPausedDL, list.length,
          reason: '两栏相加应等于总数，否则就是重复计数');
    });
  });

  group('③ isError 认得 missingFiles', () {
    test('missingFiles 计入错误', () {
      expect(mk(hash: 'a', state: 'missingFiles').isError, isTrue);
    });

    test('error 仍计入，正常状态不计入', () {
      expect(mk(hash: 'a', state: 'error').isError, isTrue);
      expect(mk(hash: 'a', state: 'downloading').isError, isFalse);
    });
  });

  group('④ base64EncodeUtf8 与标准库一致（修 CESU-8）', () {
    test('中文', () {
      const String raw = '用户:密码';
      expect(base64EncodeUtf8(raw), base64.encode(utf8.encode(raw)));
    });

    test('emoji（surrogate pair）—— 旧实现会产出 CESU-8', () {
      const String raw = 'user😀:pass🚀';
      expect(base64EncodeUtf8(raw), base64.encode(utf8.encode(raw)));
    });
  });

  group('⑤ parseServersJson 对畸形输入不崩', () {
    test('非法 JSON → 空表', () {
      expect(LocalStore.parseServersJson('这不是 JSON'), isEmpty);
      expect(LocalStore.parseServersJson('{"a":'), isEmpty);
    });

    test('数组里混入非对象项 → 跳过而不是抛异常', () {
      final List<ServerData> r =
          LocalStore.parseServersJson('["裸字符串", {"id":"s1","name":"NAS","type":"qbittorrent"}]');
      expect(r.length, 1);
      expect(r.first.id, 's1');
    });

    test('单个对象（非数组）也能解析', () {
      final List<ServerData> r =
          LocalStore.parseServersJson('{"id":"s2","name":"X","type":"transmission"}');
      expect(r.length, 1);
      expect(r.first.name, 'X');
    });
  });

  group('⑥ normalizedHost 支持未加括号的 IPv6', () {
    ServerData withHost(String h) => ServerData(
          id: 's',
          name: 'n',
          type: 'qbittorrent',
          host: h,
          port: 8080,
        );

    test('2001:db8::1 不再被截成 2001', () {
      expect(withHost('2001:db8::1').normalizedHost, '[2001:db8::1]');
    });

    test('带方括号的 IPv6 原样保留', () {
      expect(withHost('[2001:db8::1]:8080').normalizedHost, '[2001:db8::1]');
    });

    test('普通域名 + 端口照旧只取域名', () {
      expect(withHost('nas.example.com:8080').normalizedHost,
          'nas.example.com');
    });
  });

  group('⑦ planDelete：删除对话框三个勾选项真正生效', () {
    final Torrent main = mk(hash: 'h1', size: 500, savePath: '/dl/show');

    final Torrent sub = mk(hash: 'h2', size: 500, savePath: '/dl/show/');

    final Torrent other = mk(hash: 'h3', size: 700, savePath: '/dl/show');
    final List<Torrent> all = <Torrent>[main, sub, other];
    final List<Torrent> chosen = <Torrent>[main];

    test('最朴素：只删种子、不动文件', () {
      final DeletePlan p = TorrentController.planDelete(all: all, chosen: chosen);
      expect(p.deleteFiles, isFalse);
      expect(p.subs, isEmpty);
    });

    test('勾「删除文件」→ 删文件', () {
      final DeletePlan p =
          TorrentController.planDelete(all: all, chosen: chosen, deleteFiles: true);
      expect(p.deleteFiles, isTrue);
    });

    test('★ 勾「删除辅种」→ 同目录同体积的辅种被一并删掉（体积不同的不动）', () {
      final DeletePlan p =
          TorrentController.planDelete(all: all, chosen: chosen, deleteSub: true);
      expect(p.subs.map((Torrent t) => t.hash), <String>['h2']);
      expect(p.deleteFiles, isFalse, reason: '辅种不删文件，数据由主选中项负责');
    });

    test('★ 勾「无辅种时删除文件」+ 有辅种 → 不删文件', () {
      final DeletePlan p = TorrentController.planDelete(
        all: all,
        chosen: chosen,
        deleteSub: true,
        noSubDeleteFiles: true,
      );
      expect(p.subs, isNotEmpty);
      expect(p.deleteFiles, isFalse, reason: '有辅种时删文件会破坏共享数据');
    });

    test('★ 勾「无辅种时删除文件」+ 无辅种 → 顺手删文件', () {
      final DeletePlan p = TorrentController.planDelete(
        all: <Torrent>[main, other],
        chosen: chosen,
        deleteSub: true,
        noSubDeleteFiles: true,
      );
      expect(p.subs, isEmpty);
      expect(p.deleteFiles, isTrue);
    });

    test('末尾斜杠 / 反斜杠差异不影响辅种识别', () {
      final DeletePlan p = TorrentController.planDelete(
        all: <Torrent>[
          mk(hash: 'h1', size: 500, savePath: '/dl/show/'),
          mk(hash: 'h2', size: 500, savePath: '\\dl\\show'),
        ],
        chosen: <Torrent>[mk(hash: 'h1', size: 500, savePath: '/dl/show')],
        deleteSub: true,
      );
      expect(p.subs.length, 1);
    });

    test('savePath 为空时不做辅种误判', () {
      final DeletePlan p = TorrentController.planDelete(
        all: <Torrent>[
          mk(hash: 'h1', size: 500),
          mk(hash: 'h2', size: 500),
        ],
        chosen: <Torrent>[mk(hash: 'h1', size: 500)],
        deleteSub: true,
      );
      expect(p.subs, isEmpty, reason: '路径都为空时无法判断"同目录"，不该乱删');
    });
  });

  group('⑧ 排序「做种人数」与列表显示同口径（numComplete）', () {
    test('降序时 tracker 做种总数多的排前面（而不是本地已连接数多的）', () async {
      Get.put(ServerController());
      final TorrentController c = Get.put(TorrentController());

      const Torrent bigSwarm = Torrent(
        hash: 'a',
        name: 'A',
        size: 1,
        progress: 1,
        state: 'seeding',
        dlSpeed: 0,
        upSpeed: 0,
        numSeeds: 1,
        numLeechs: 0,
        ratio: 0,
        numComplete: 50,
      );
      const Torrent smallSwarm = Torrent(
        hash: 'b',
        name: 'B',
        size: 1,
        progress: 1,
        state: 'seeding',
        dlSpeed: 0,
        upSpeed: 0,
        numSeeds: 9,
        numLeechs: 0,
        ratio: 0,
        numComplete: 5,
      );

      c.items.assignAll(<Torrent>[smallSwarm, bigSwarm]);
      c.setSortKey(TorrentSortKey.seeds);
      c.setSortDesc(true);

      expect(
        c.visibleItems.map((Torrent t) => t.hash).toList(),
        <String>['a', 'b'],
        reason: '列表显示的是 a/b(c) 里的 a(=numComplete)，排序必须比它；'
            '旧实现比 numSeeds 会得出相反顺序',
      );
    });
  });
}
