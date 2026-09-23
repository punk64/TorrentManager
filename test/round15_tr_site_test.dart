import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/data/models/server_data.dart';

ServerData trSrv() => ServerData(
      id: 'tr-1',
      name: 'TR',
      type: 'transmission',
      host: '192.168.1.9',
      port: 9091,
    );

Map<String, dynamic> trTorrent({String comment = '', String magnet = ''}) =>
    <String, dynamic>{
      'id': 1,
      'hashString': 'a' * 40,
      'name': '示例种子',
      'status': 4,
      'sizeWhenDone': 1024,
      'percentDone': 0.5,
      'rateDownload': 0,
      'rateUpload': 0,
      'peersSendingToUs': 0,
      'peersGettingFromUs': 0,
      'uploadRatio': 0.0,
      'downloadDir': '/downloads',
      'comment': comment,
      'magnetLink': magnet,
    };

Dio fakeTrDio(Map<String, dynamic> torrent, List<dynamic> capturedFields) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://192.168.1.9:9091'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      String method = '';
      dynamic parsed;
      final dynamic d = o.data;
      if (d is Map) {
        parsed = d;
      } else if (d is String) {
        try {
          parsed = jsonDecode(d);
        } catch (_) {
        }
      }
      if (parsed is Map) method = (parsed['method'] ?? '').toString();

      if (method == 'torrent-get' && parsed is Map) {
        final dynamic args = parsed['arguments'];
        if (args is Map && args['fields'] is List) {
          capturedFields
            ..clear()
            ..addAll(args['fields'] as List<dynamic>);
        }
      }

      h.resolve(Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: <String, dynamic>{
          'result': 'success',
          'arguments': method == 'torrent-get'
              ? <String, dynamic>{
                  'torrents': <dynamic>[torrent],
                }
              : <String, dynamic>{},
        },
      ));
    },
  ));
  return dio;
}

Future<List<Torrent>> refreshTr(
    Map<String, dynamic> torrent, List<dynamic> capturedFields) async {
  final ServerData s = trSrv();
  final ServerController sc =
      Get.put(ServerController(tr: TrMethod(dio: fakeTrDio(torrent, capturedFields))));
  sc.servers.assignAll(<ServerData>[s]);
  sc.select(s);
  final TorrentController tc = TorrentController();
  await tc.refresh();
  return tc.items.toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
    Get.reset();
  });

  test('★ TR torrent-get 必须声明 comment / magnetLink（修复前二者都缺）', () async {
    final List<dynamic> fields = <dynamic>[];
    await refreshTr(trTorrent(), fields);

    expect(fields, contains('comment'),
        reason: '★ 不请求 comment → `Torrent.site` 取不到站点');
    expect(fields, contains('magnetLink'),
        reason: '★ 不请求 magnetLink → comment 为空时也无从回落');
  });

  test('★ comment 里的发布页链接 → 站点解析出来（口径：comment 优先）',
      () async {
    final List<Torrent> items = await refreshTr(
      trTorrent(
        comment: 'https://tracker.example.com/torrents/12345',

        magnet: 'magnet:?xt=urn:btih:${'a' * 40}'
            '&dn=x&tr=http%3A%2F%2Ftr2.example.org%2Fannounce',
      ),
      <dynamic>[],
    );

    expect(items, hasLength(1));
    expect(items.first.site, 'tracker.example.com',
        reason: '★ 修复前为空串（卡片「种子站点」空白）');
  });

  test('★ comment 为空时回落 magnetLink 的 &tr=（百分号编码要解码）', () async {
    final List<Torrent> items = await refreshTr(
      trTorrent(
        magnet: 'magnet:?xt=urn:btih:${'a' * 40}'
            '&dn=x&tr=http%3A%2F%2Ftr2.example.org%2Fannounce',
      ),
      <dynamic>[],
    );

    expect(items.first.site, 'tr2.example.org',
        reason: '★ 百分号编码的 `http%3A%2F%2F…` 必须先解码再取主机名');
  });

  test('comment / magnetLink 都为空时站点为空串（由上层显示成「未知站点」）',
      () async {
    final List<Torrent> items = await refreshTr(trTorrent(), <dynamic>[]);

    expect(items.first.site, isEmpty,
        reason: '取不到就返回空串，不能硬造一个站点名出来');
  });
}
