import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/utils/lan_detector.dart';

ServerData _trSrv() => ServerData(
      id: 'tr-1',
      name: 'tr101',
      type: 'transmission',
      host: 'tr.example.com',
      port: 9091,
      useHttps: false,
      lanHost: '192.168.1.20',
      lanPort: 9091,
      username: 'u',
      password: 'p',
    );

ServerData _qbSrv() => ServerData(
      id: 'qb-1',
      name: '家庭 NAS',
      type: 'qbittorrent',
      host: 'nas.example.com',
      port: 8080,
      useHttps: true,
      lanHost: '192.168.1.10',
      lanPort: 8080,
    );

TrMethod _fakeTr(List<String?> dirs) {
  int i = 0;
  final dio.Dio d = dio.Dio(dio.BaseOptions(baseUrl: 'http://placeholder'));
  d.interceptors.add(dio.InterceptorsWrapper(
    onRequest: (dio.RequestOptions o, dio.RequestInterceptorHandler h) {
      final String? dir = i < dirs.length ? dirs[i++] : null;
      h.resolve(dio.Response<Map<String, dynamic>>(
        requestOptions: o,
        statusCode: 200,
        data: dir == null
            ? <String, dynamic>{'result': 'boom'}
            : <String, dynamic>{
                'result': 'success',
                'arguments': <String, dynamic>{'config-dir': dir},
              },
      ));
    },
  ));
  return TrMethod(dio: d);
}

Future<void> _runProbe(ServerController sc, ServerData s) async {
  sc.select(s);
  final Future<void>? f = sc.lanProbeOf(s.id);
  if (f != null) await f;
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

void main() {
  tearDown(() {
    LanDetector.overrideProbe = null;
    LanDetector.overrideTcp = null;
  });

  test('★ 保险①-1：config-dir 一致 → 确认是同一台，照旧走局域网', () async {
    LanDetector.overrideProbe = (_) async => true;

    final ServerController sc = ServerController();
    sc.trProbeFactory = () => _fakeTr(<String?>['/cfg/A', '/cfg/A']);
    final ServerData s = _trSrv();
    sc.servers.assignAll(<ServerData>[s]);

    await _runProbe(sc, s);

    expect(sc.lanUsing[s.id], isTrue);
  });

  test('★ 保险①-2：config-dir 不同 → 不是同一台，弃用局域网走公网', () async {
    LanDetector.overrideProbe = (_) async => true;

    final ServerController sc = ServerController();
    sc.trProbeFactory = () => _fakeTr(<String?>['/cfg/A', '/cfg/B']);
    final ServerData s = _trSrv();
    sc.servers.assignAll(<ServerData>[s]);

    await _runProbe(sc, s);

    expect(sc.lanUsing[s.id], isFalse,
        reason: '★ 端口能连上但对面是另一台 TR ⇒ 必须走公网，'
            '否则卡片数据会来自错误的那台（用户实测：35 个 vs 5661 个）');
  });

  test('★ 保险①-3：取不到 config-dir / 报错 → 按"是同一台"处理（不误伤）',
      () async {
    LanDetector.overrideProbe = (_) async => true;

    final ServerController sc = ServerController();
    sc.trProbeFactory = () => _fakeTr(<String?>['/cfg/A', null]);
    final ServerData s = _trSrv();
    sc.servers.assignAll(<ServerData>[s]);

    await _runProbe(sc, s);

    expect(sc.lanUsing[s.id], isTrue,
        reason: '校验能力不具备时保持旧行为，不能反过来把正常场景判死');
  });

  test('★ 保险①-4：qBittorrent 不做这项校验（没有对等的实例标识）', () async {
    LanDetector.overrideProbe = (_) async => true;

    int made = 0;
    final ServerController sc = ServerController();
    sc.trProbeFactory = () {
      made++;
      return _fakeTr(<String?>['/cfg/A', '/cfg/B']);
    };
    final ServerData s = _qbSrv();
    sc.servers.assignAll(<ServerData>[s]);

    await _runProbe(sc, s);

    expect(made, 0, reason: 'qB 侧暂不校验，别白跑两次请求');
    expect(sc.lanUsing[s.id], isTrue);
  });

  test('★ 保险①-5：局域网根本连不上 → 连校验都不用做', () async {
    LanDetector.overrideProbe = (_) async => false;

    int made = 0;
    final ServerController sc = ServerController();
    sc.trProbeFactory = () {
      made++;
      return _fakeTr(<String?>['/cfg/A', '/cfg/B']);
    };
    final ServerData s = _trSrv();
    sc.servers.assignAll(<ServerData>[s]);

    await _runProbe(sc, s);

    expect(made, 0);
    expect(sc.lanUsing[s.id], isFalse);
  });
}
