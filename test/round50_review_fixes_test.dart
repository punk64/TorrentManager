


















import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/pages/torrent_info_files_page.dart';
import 'package:torrent_manager/utils/app_log.dart';
import 'package:torrent_manager/utils/crypto_box.dart';
import 'package:torrent_manager/utils/i18n_en.dart';
import 'package:torrent_manager/utils/strings.dart';

Torrent _t(
  String hash, {
  String name = '资源',
  int size = 500,
  String? dir,
}) =>
    Torrent(
      hash: hash,
      name: name,
      size: size,
      progress: 0.5,
      state: 'seeding',
      dlSpeed: 0,
      upSpeed: 0,
      numSeeds: 0,
      numLeechs: 0,
      ratio: 0,
      savePath: dir,
    );


({Dio dio, List<String> bodies}) _fakeTr() {
  final List<String> bodies = <String>[];
  final Dio dio = Dio(
    BaseOptions(baseUrl: 'http://127.0.0.1:9091/transmission/rpc'),
  );
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      bodies.add(jsonEncode(o.data));
      h.resolve(Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: <String, dynamic>{
          'result': 'success',
          'arguments': <String, dynamic>{},
        },
      ));
    },
  ));
  return (dio: dio, bodies: bodies);
}

void main() {
  
  group('N6 辅种判定：全应用唯一口径（体积 + 同目录）', () {
    test('★ 名字不同、但字节数相同 + 同目录 → 仍是辅种', () {
      
      final Torrent a = _t('h1', name: '[站A] 影片 2160p', dir: '/dl/影片');
      final Torrent b = _t('h2', name: '影片.2160p.站B', dir: '/dl/影片');
      expect(TorrentController.isCrossSeed(a, b), isTrue,
          reason: '按名字比会让真正的辅种互相认不出 —— 这正是 N6 的成因');
    });

    test('size = 0（磁力链元数据还没到）→ 不认辅种（L5 保护不回退）', () {
      final Torrent a = _t('h1', size: 0, dir: '/dl/x');
      final Torrent b = _t('h2', size: 0, dir: '/dl/x');
      expect(TorrentController.isCrossSeed(a, b), isFalse);
    });

    test('同体积但目录不同 → 不认辅种', () {
      expect(
        TorrentController.isCrossSeed(
          _t('h1', size: 500, dir: '/dl/x'),
          _t('h2', size: 500, dir: '/dl/y'),
        ),
        isFalse,
      );
    });

    test('保存路径缺失 → 不认辅种（无从判断"同目录"）', () {
      expect(
        TorrentController.isCrossSeed(
          _t('h1', size: 500),
          _t('h2', size: 500),
        ),
        isFalse,
      );
    });

    test('同一个 hash 不是"另一份"', () {
      final Torrent a = _t('h1', size: 500, dir: '/dl/x');
      expect(TorrentController.isCrossSeed(a, a), isFalse);
    });

    test('★ 查询口径 == 删除口径（N6 的核心诉求）', () {
      final List<Torrent> all = <Torrent>[
        _t('h1', name: '[A]片', size: 500, dir: '/dl/x'), 
        _t('h2', name: '[B]片', size: 500, dir: '/dl/x'), 
        _t('h3', name: '[A]片', size: 900, dir: '/dl/x'), 
        _t('h4', name: '[A]片', size: 500, dir: '/dl/y'), 
        _t('h5', name: '[A]片', size: 500), 
        _t('h6', name: '[A]片', size: 0, dir: '/dl/x'), 
      ];

      for (final Torrent t in all) {
        
        final Set<String> viaQuery = all
            .where((Torrent x) => TorrentController.isCrossSeed(t, x))
            .map((Torrent x) => x.hash)
            .toSet();
        
        final Set<String> viaDelete = TorrentController.planDelete(
          all: all,
          chosen: <Torrent>[t],
          deleteSub: true,
        ).subs.map((Torrent x) => x.hash).toSet();

        expect(viaDelete, viaQuery,
            reason: '对 ${t.hash}：删除会删的必须**正好等于**查询会列出的；'
                '否则用户看不到的任务被一并删掉（不可逆）');
      }

      
      expect(
        TorrentController.planDelete(
          all: all,
          chosen: <Torrent>[all[0]],
          deleteSub: true,
        ).subs.map((Torrent x) => x.hash).toList(),
        <String>['h2'],
      );
    });
  });

  
  group('N13 planDelete：O(n+m) 规模保护', () {
    test('★ 3000 条 + 选中半数 + 删除辅种 → 毫秒级完成', () {
      final List<Torrent> all = <Torrent>[
        for (int i = 0; i < 3000; i++)
          _t('h$i',
              size: i.isEven ? 100 : 200, dir: '/dl/${i % 40}'),
      ];
      final List<Torrent> chosen = all.take(1500).toList();

      final Stopwatch sw = Stopwatch()..start();
      final DeletePlan p = TorrentController.planDelete(
        all: all,
        chosen: chosen,
        deleteSub: true,
      );
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: '旧的 O(n×m) 写法在这一规模下要做 450 万次比较/正则编译');
      expect(p.subs, isNotEmpty);
    });
  });

  
  group('N8 TR 文件优先级：三档（无"最高"）', () {
    test('TR 没有"最高"这一档 → 界面必须隐藏', () {
      expect(FilePrio.maximal.trSupported, isFalse);
      expect(FilePrio.skip.trSupported, isTrue);
      expect(FilePrio.normal.trSupported, isTrue);
      expect(FilePrio.high.trSupported, isTrue);
    });

    test('两套取值映射（qB priority / TR priority）', () {
      expect(FilePrio.skip.value, 0);
      expect(FilePrio.skip.trValue, 0);
      expect(FilePrio.normal.value, 1);
      expect(FilePrio.normal.trValue, 0);
      expect(FilePrio.high.value, 6);
      expect(FilePrio.high.trValue, 1);
    });

    test('★ TR 的"跳过"走 files-unwanted', () async {
      final ({Dio dio, List<String> bodies}) f = _fakeTr();
      await TrMethod(dio: f.dio)
          .setFilesWanted(<int>[1], <int>[2, 3], wanted: false);
      expect(f.bodies.single, contains('files-unwanted'));
      expect(f.bodies.single, isNot(contains('files-wanted')));
    });

    test('★ TR 恢复下载走 files-wanted（否则文件永远回不来）', () async {
      final ({Dio dio, List<String> bodies}) f = _fakeTr();
      await TrMethod(dio: f.dio)
          .setFilesWanted(<int>[1], <int>[2], wanted: true);
      expect(f.bodies.single, contains('files-wanted'));
      expect(f.bodies.single, isNot(contains('files-unwanted')));
    });
  });

  
  group('N9 TR 添加种子：分类与暂停不再被丢弃', () {
    test('★ labels（分类）与 paused 都要进 torrent-add', () async {
      final ({Dio dio, List<String> bodies}) f = _fakeTr();
      await TrMethod(dio: f.dio).addTorrents(
        metainfo: 'BASE64',
        downloadDir: '/dl',
        paused: true,
        labels: <String>['电影'],
      );
      final String body = f.bodies.single;
      expect(body, contains('torrent-add'));
      expect(body, contains('labels'));
      expect(body, contains('电影'));
      expect(body, contains('paused'));
    });

    test('没填分类时不带 labels（别塞空数组）', () async {
      final ({Dio dio, List<String> bodies}) f = _fakeTr();
      await TrMethod(dio: f.dio).addTorrents(metainfo: 'BASE64');
      expect(f.bodies.single, isNot(contains('labels')));
    });
  });

  
  group('N15 VIEW 日志节流表限量', () {
    test('★ 灌入超过上限的不同 key → 节流表被清，老 key 不再被拦住', () {
      final AppLog log = AppLog.instance;
      log.clear();
      AppLog.resetViewThrottle();

      
      
      const int n = AppLog.viewKeyLimit + 1;
      for (int i = 0; i < n; i++) {
        log.view('刷新详情', key: '详情:$i:refresh');
      }
      expect(log.entries.length, n,
          reason: '每条 key 都不同 → 都该被记下来（节流只拦重复 key）');

      
      final int before = log.entries.length;
      log.view('刷新详情', key: '详情:0:refresh');
      expect(log.entries.length, before + 1,
          reason: '限量前这里会被 60s 窗口拦住 —— 键里带种子 hash，'
              '逐个翻详情页会让这张表只增不减');
    });

    test('同 key + 窗口内重复 → 仍然只记一条（限量没把节流失效）', () {
      final AppLog log = AppLog.instance;
      log.clear();
      AppLog.resetViewThrottle();
      log.view('A', key: 'k1');
      log.view('A', key: 'k1');
      expect(log.entries.length, 1);
    });
  });

  
  group('N1~N5 文案就位', () {
    test('TR 缺 trId / 无服务器 / 非 qB 导出 → 都有专门提示', () {
      expect(S.noTrId, isNotEmpty);
      expect(S.noServer, isNotEmpty);
      expect(S.btExportTrUnsupported, isNotEmpty);
      expect(S.trkEditNotFound, isNotEmpty);
    });

    test('★ 用户协议与隐私政策是两份不同文案（此前是同一个弹窗）', () {
      expect(S.termsBody, isNotEmpty);
      expect(S.privacyBody, isNotEmpty);
      expect(S.termsBody, isNot(S.privacyBody));
    });

    test('新增的界面文案都有英文译文（第 50 轮补全）', () {
      const List<String> keys = <String>[
        '跳过', '普通', '高', '最高',
        '继续', '暂停',
        '队列顺序', '标签（可选）', '添加后暂停', '未选择服务器',
      ];
      for (final String k in keys) {
        expect(kEnStrings.containsKey(k), isTrue, reason: '「$k」缺英文译文');
        expect(kEnStrings[k], isNot(k), reason: '「$k」的译文不能还是中文');
      }
    });
  });

  
  
  
  
  
  
  group('S4 迭代次数下限（防「改小 iter 干掉慢哈希」）', () {
    tearDown(() {
      CryptoBox.testIterationsOverride = null;
    });

    
    
    String retag(String env, Object? iter) {
      final Map<String, dynamic> m =
          Map<String, dynamic>.from(jsonDecode(env) as Map);
      if (iter == null) {
        m.remove('iter');
      } else {
        m['iter'] = iter;
      }
      return jsonEncode(m);
    }

    
    
    setUp(() {
      CryptoBox.testIterationsOverride = CryptoBox.minIterations;
    });

    test('★ iter 被改成 1 → 直接拒绝（修复前会照常解密）', () async {
      final String env =
          await CryptoBox.encryptWithPassphrase('s3cret', 'pw-123456');
      await expectLater(
        () => CryptoBox.decryptWithPassphrase(
            retag(env, 1), 'pw-123456'),
        throwsA(isA<CryptoBoxException>().having(
            (CryptoBoxException e) => e.message,
            'message',
            contains('加密强度不足'))),
        reason: '口令与密文都没错，只有工作量被拧到最小 —— 这种文件不能解',
      );
    });

    test('★ 边界：下限减 1 → 拒；等于下限 → 放行', () async {
      final String env =
          await CryptoBox.encryptWithPassphrase('边界', 'pw-123456');
      await expectLater(
        () => CryptoBox.decryptWithPassphrase(
            retag(env, CryptoBox.minIterations - 1), 'pw-123456'),
        throwsA(isA<CryptoBoxException>()),
      );
      expect(await CryptoBox.decryptWithPassphrase(env, 'pw-123456'), '边界');
    });

    test('iter 缺失 / 0 / 负数 → 仍归「格式损坏」，与「强度不足」分开报', () async {
      final String env = await CryptoBox.encryptWithPassphrase('x', 'pw-123456');
      for (final Object? bad in <Object?>[0, -1, null]) {
        await expectLater(
          () => CryptoBox.decryptWithPassphrase(retag(env, bad), 'pw-123456'),
          throwsA(isA<CryptoBoxException>().having(
              (CryptoBoxException e) => e.message,
              'message',
              contains('格式损坏'))),
          reason: 'iter=$bad 是文件不完整，不是"强度可疑"，文案不能混',
        );
      }
    });

    test('本机自己导出的文件永不受下限影响', () async {
      final String env =
          await CryptoBox.encryptWithPassphrase('正常内容', 'pw-123456');
      expect(await CryptoBox.decryptWithPassphrase(env, 'pw-123456'), '正常内容');
    });

    test('下限常量在合理量级（不是 0 或 1 那种摆设）', () {
      expect(CryptoBox.minIterations, greaterThanOrEqualTo(50000));
      expect(CryptoBox.minIterations, lessThanOrEqualTo(200000));
    });
  });
}
