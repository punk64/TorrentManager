import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/utils/crypto_box.dart';

ServerData qbSrv(String id, String host, {String? user, String? pass}) =>
    ServerData(
      id: id,
      name: 'NAS-$id',
      type: 'qbittorrent',
      host: host,
      port: 8080,
      username: user,
      password: pass,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    CryptoBox.testIterationsOverride = CryptoBox.minIterations;
  });

  tearDown(() {
    CryptoBox.testIterationsOverride = null;
  });

  group('★ 第 91 轮：导出 JSON 改为口令加密密文（剪贴板通道）', () {
    test('导出信封合法，剪贴板内容不含任何服务器敏感明文', () async {
      final ServerController sc = ServerController();
      sc.servers.assignAll(<ServerData>[
        qbSrv('a', '10.0.0.1', user: 'admin', pass: 'pw-A'),
        qbSrv('b', '192.168.1.9', user: 'root', pass: 'pw-B'),
      ]);

      final String env = await sc.buildPortableBackup('pass1234');

      expect(CryptoBox.isPortableEnvelope(env), isTrue);
      expect(env, isNot(contains('pw-A')), reason: '剪贴板不能出现密码明文');
      expect(env, isNot(contains('pw-B')));
      expect(env, isNot(contains('10.0.0.1')), reason: '剪贴板不能出现地址明文');
      expect(env, isNot(contains('admin')));
    });

    test('正确口令导入：新增服务器且账号密码入库', () async {
      final ServerController src = ServerController();
      src.servers.assignAll(<ServerData>[
        qbSrv('a', '10.0.0.1', user: 'admin', pass: 'pw-A'),
      ]);
      final String env = await src.buildPortableBackup('pass1234');

      final ServerController dst = ServerController();
      final int added = await dst.importPortableBackup(env, 'pass1234');

      expect(added, 1);
      expect(dst.servers.single.id, 'a');
      expect(dst.servers.single.username, 'admin');
      expect(dst.servers.single.password, 'pw-A');
    });

    test('同 id 导入 = 整体替换（含密码），不再保留旧密码', () async {
      final ServerController src = ServerController();
      src.servers.assignAll(<ServerData>[
        qbSrv('a', '10.0.0.9', user: 'new', pass: 'new-pw'),
      ]);
      final String env = await src.buildPortableBackup('pass1234');

      final ServerController dst = ServerController();
      dst.servers.assignAll(<ServerData>[
        qbSrv('a', '10.0.0.1', user: 'old', pass: 'old-pw'),
      ]);
      final int added = await dst.importPortableBackup(env, 'pass1234');

      expect(added, 0);
      expect(dst.servers.single.host, '10.0.0.9');
      expect(dst.servers.single.password, 'new-pw',
          reason: '密文信封本来就带密码，导入即整体替换');
    });

    test('错误口令 → CryptoBoxException，不得解出数据', () async {
      final ServerController src = ServerController();
      src.servers.assignAll(<ServerData>[qbSrv('a', '10.0.0.1', pass: 'pw')]);
      final String env = await src.buildPortableBackup('right-pass');

      final ServerController dst = ServerController();
      await expectLater(
        dst.importPortableBackup(env, 'wrong-pass'),
        throwsA(isA<CryptoBoxException>()),
      );
      expect(dst.servers, isEmpty, reason: '解密失败不得写入任何服务器');
    });

    test('旧明文 JSON → 不是合法信封，导入通道必须拒绝', () {
      const String plain =
          '[{"id":"a","name":"NAS","type":"qbittorrent","host":"10.0.0.1",'
          '"port":8080,"username":"admin"}]';
      expect(CryptoBox.isPortableEnvelope(plain), isFalse,
          reason: '明文进导入流程会直接被 bkJsonNotEnvelope 拒绝');
    });
  });
}
