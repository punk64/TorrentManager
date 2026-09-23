























import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/prefs/server_prefs.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/utils/formatter.dart';





Dio _fakeTrDio(List<Map<String, dynamic>> argSets) {
  final Dio dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.1.10:9091',
    validateStatus: (int? s) => s != null && s < 500,
    followRedirects: false,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      final Object? body = o.data;
      if (body is String) {
        try {
          final Map<String, dynamic> m =
              jsonDecode(body) as Map<String, dynamic>;
          final Object? a = m['arguments'];
          if (a is Map) argSets.add(Map<String, dynamic>.from(a));
        } catch (_) {
          
        }
      }
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
  return dio;
}


Map<String, dynamic> _trRaw({
  String? dir = '/downloads',
  String? name = 'A.mkv',
  int downloading = 100,
  int seeding = 200,
}) =>
    <String, dynamic>{
      'id': 1,
      'hashString': 'h1',
      'name': name,
      'downloadDir': dir,
      'secondsDownloading': downloading,
      'secondsSeeding': seeding,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() => Get.reset());

  
  
  

  group('第 58 轮 G · P3-2 TR 的 contentPath / timeActive 映射', () {
    test('G1 ★ fromTr 用 `downloadDir` + `name` 拼出内容路径', () {
      final List<dynamic> got =
          TorrentController.fromTr(<Map<String, dynamic>>[_trRaw()]);
      expect(got.length, 1);
      expect((got.single as dynamic).contentPath, '/downloads/A.mkv',
          reason: '★ TR 没有 qB 那个 `content_path` 字段，只能拼 —— '
              '此前完全没映射 ⇒ 详情页「内容路径」整行隐藏、列表面板显示 `-`');
    });

    test('G2 ★ fromTr 用「下载中 + 做种中」近似活动时长', () {
      final List<dynamic> got = TorrentController.fromTr(
          <Map<String, dynamic>>[_trRaw(downloading: 100, seeding: 200)]);
      expect((got.single as dynamic).timeActive, 300,
          reason: '★ TR 没有 `time_active`（累计活动秒数）—— '
              '此前恒为 0，详情页「活动时长」永远显示 0');
    });

    test('G3 目录已带尾斜杠 → 不重复加分隔符', () {
      final List<dynamic> got = TorrentController.fromTr(
          <Map<String, dynamic>>[_trRaw(dir: '/downloads/')]);
      expect((got.single as dynamic).contentPath, '/downloads/A.mkv');

      final List<dynamic> win = TorrentController.fromTr(
          <Map<String, dynamic>>[_trRaw(dir: r'D:\Downloads\')]);
      expect((win.single as dynamic).contentPath, r'D:\Downloads\A.mkv',
          reason: 'Windows 的反斜杠结尾同样不该再加一个 `/`');
    });

    test('G4 缺目录或缺名字 → null（不拼出半截路径）', () {
      for (final Map<String, dynamic> raw in <Map<String, dynamic>>[
        _trRaw(dir: null),
        _trRaw(dir: '   '),
        _trRaw(name: null),
        _trRaw(name: ''),
      ]) {
        final List<dynamic> got =
            TorrentController.fromTr(<Map<String, dynamic>>[raw]);
        expect((got.single as dynamic).contentPath, isNull,
            reason: '拿不到完整路径时宁可留空 —— 半截路径比没有更误导');
      }
    });
  });

  
  
  

  group('第 58 轮 H · P3-3 队列开关 / P3-1 暂停文案', () {
    test('H1 ★ TR 的「启用队列限制」要同时下发 download / seed 两个开关', () async {
      final List<Map<String, dynamic>> argSets = <Map<String, dynamic>>[];
      final TrPrefsApi api = TrPrefsApi(
        client: TrMethod(dio: _fakeTrDio(argSets)),
        resolve: (ServerData s) => s,
      );

      await api.write(<String, dynamic>{PrefKey.queueingEnabled: false});

      expect(argSets, isNotEmpty, reason: '前置：确实发了一次 session-set');
      final Map<String, dynamic> args = argSets.single;
      expect(args['download-queue-enabled'], isFalse);
      expect(args['seed-queue-enabled'], isFalse,
          reason: '★ TR 有**两套独立**队列 —— 只关下载队列的话，'
              '做种队列仍然在限流（超出的种子照样排队），与开关承诺不符，'
              '而且界面上完全看不出来');
    });

    test('H2 ★ TR 的 `stopped` → 「已暂停」（与 qB 的暂停态同一套说法）', () {
      expect(Formatter.setStatus('stopped'), '已暂停',
          reason: '★ 此前映射到「未工作」/ Idle，而 qB 显示「暂停下载」—— '
              '同一件事两种说法，用户会以为 TR 那边是另一种状态');
      
      expect(Formatter.setStatus('pausedDL'), '暂停下载');
      expect(Formatter.setStatus('pausedUP'), '暂停上传');
    });
  });
}
