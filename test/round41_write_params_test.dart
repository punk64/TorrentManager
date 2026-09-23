import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';

ServerData srv({String id = 'qb-1', String host = '10.0.0.7'}) => ServerData(
      id: id,
      name: 'NAS-$id',
      type: 'qbittorrent',
      host: host,
      port: 8080,
      username: 'u',
      password: 'p',
    );

class _ParamStyleQbServer implements HttpClientAdapter {
  _ParamStyleQbServer(this.log, {this.rejectBody = false});

  final List<String> log;

  final bool rejectBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = o.uri.path;
    final String ct = o.contentType ?? '';
    final String body = o.data?.toString() ?? '';

    final bool bodyHas = ct.contains('x-www-form-urlencoded') && body.contains('hashes');
    final bool queryHas = o.uri.query.contains('hashes');
    int code = 200;
    String body2 = '';

    if (path.contains('/app/version')) {
      body2 = 'v5.0.5';
    } else if (path.contains('/app/webapiVersion')) {
      body2 = '2.11.2';
    } else if (path.contains('/torrents/stop') ||
        path.contains('/torrents/start')) {
      final bool accepted = rejectBody ? (queryHas && !bodyHas) : bodyHas;
      if (!accepted) {
        code = 400;
        body2 = 'Bad Request';
      }
    } else if (path.contains('/auth/login')) {
      body2 = 'Ok.';
    }

    log.add('$code ${o.method} ${o.uri.host}$path'
        ' ｜ body=${bodyHas ? 'yes' : 'no'} ｜ query=${queryHas ? 'yes' : 'no'}');
    return ResponseBody.fromString(
      body2,
      code,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/plain'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

QbMethod _qbWith(_ParamStyleQbServer server) {
  final Dio dio = Dio(BaseOptions(

    validateStatus: (int? s) => s != null && s < 500,
  ));
  dio.httpClientAdapter = server;
  return QbMethod(dio: dio);
}

int _stopCalls(List<String> log) =>
    log.where((String e) => e.contains('/torrents/stop')).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecurePrefs.useMemoryBackendForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
    Get.reset();
  });

  test('★ 只认 form body 的 qB：暂停参数走 body，不再被 400 拒', () async {
    final List<String> log = <String>[];
    final QbMethod c = _qbWith(_ParamStyleQbServer(log));
    final ServerData s = srv();
    c.setServer(s);

    await c.pauseTorrent('abc123def456');

    expect(_stopCalls(log), 1, reason: '★ 一次就成功，不该有回退重试');
    expect(
      log.any((String e) =>
          e.startsWith('200 POST') && e.contains('/torrents/stop')),
      isTrue,
      reason: '★ 参数放对位置后服务端回 200：$log',
    );
    expect(
      log.firstWhere((String e) => e.contains('/torrents/stop')),
      contains('body=yes'),
      reason: '★ hashes 必须出现在 form body 里（qB 5.x 只认这里）',
    );
    expect(
      log.firstWhere((String e) => e.contains('/torrents/stop')),
      contains('query=no'),
      reason: '★ 不该再把参数拼在 URL query 上',
    );
  });

  test('★ 继续（start）同样走 form body', () async {
    final List<String> log = <String>[];
    final QbMethod c = _qbWith(_ParamStyleQbServer(log));
    c.setServer(srv());

    await c.resumeTorrent('abc123def456');

    expect(
      log.any((String e) =>
          e.startsWith('200 POST') && e.contains('/torrents/start')),
      isTrue,
      reason: '★ 继续也必须 200：$log',
    );
  });

  test('★ 只认 query 的老式部署：400 后自动回退 query 并成功', () async {
    final List<String> log = <String>[];
    final QbMethod c = _qbWith(_ParamStyleQbServer(log, rejectBody: true));
    c.setServer(srv());

    await c.pauseTorrent('abc123def456');

    expect(_stopCalls(log), 2,
        reason: '★ 第一笔 form body 被 400 拒 → 应再补一笔 query 重试');
    expect(
      log.lastWhere((String e) => e.contains('/torrents/stop')),
      contains('query=yes'),
      reason: '★ 回退那一笔要用 query string：$log',
    );

    log.clear();
    await c.pauseTorrent('abc123def456');
    expect(_stopCalls(log), 1,
        reason: '★ 已探明的参数形式要记住，不该每次重试');
    expect(log.first, contains('query=yes'),
        reason: '★ 第二次直接用对的形式：$log');
  });

  test('★ 写入超大列表时被截断到 2 万条', () {
    final ServerController sc = ServerController(qb: QbMethod());
    sc.cacheTorrents('big', List<Torrent>.generate(
      ServerController.kCacheMaxTorrents + 500,
      (int i) => Torrent.fromJson(<String, dynamic>{
        'hash': 'h$i',
        'name': 'n$i',
        'size': i,
      }),
    ));
    expect(sc.torrentsOf('big').length, ServerController.kCacheMaxTorrents,
        reason: '★ 单台必须有条数阀：只按"最多 5 台"挡不住一台 3 万条的大库');
  });
}
