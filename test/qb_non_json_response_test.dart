import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/utils/net_error.dart';

class _TextAdapter implements HttpClientAdapter {
  _TextAdapter(this.body, {this.statusCode = 200});

  final String body;
  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/plain'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  ServerData srv() => ServerData(
        id: 'q1',
        name: 'NAS',
        type: 'qbittorrent',
        host: '192.168.1.5',
        port: 8080,
        username: 'admin',
        password: 'wrong',
      );

  QbMethod makeQb(String body, {int statusCode = 200}) {
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://192.168.1.5:8080'));
    dio.httpClientAdapter = _TextAdapter(body, statusCode: statusCode);
    return QbMethod(dio: dio);
  }

  group('★ 非 JSON 响应不得抛类型错误', () {
    test('403 Forbidden 文本 → 转成 badResponse，且提示指向「未登录 / 会话失效」',
        () async {
      final QbMethod qb = makeQb('Forbidden', statusCode: 403);
      qb.setServer(srv());

      Object? err;
      try {
        await qb.getQbLogs();
      } catch (e) {
        err = e;
      }

      expect(err, isA<DioException>(), reason: '应当是可读的 DioException');
      expect((err! as DioException).type, DioExceptionType.badResponse);

      expect(NetError.describe(err), contains('未登录或会话已失效'));
    });

    test('sync/maindata 返回文本同样转成 badResponse（进入种子页那条路径）',
        () async {
      final QbMethod qb = makeQb('Forbidden', statusCode: 403);
      qb.setServer(srv());

      expect(
        () => qb.updateQbMaindata(rid: 3),
        throwsA(isA<DioException>()),
      );
    });

    test('torrents/info 返回文本同样转成 badResponse（不是 List 类型错误）',
        () async {
      final QbMethod qb = makeQb('Fails.', statusCode: 403);
      qb.setServer(srv());

      expect(
        () => qb.getTorrentList(),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('★ 登录必须看响应体（不能只看 HTTP 200）', () {
    test('Ok. → 登录成功', () async {
      final QbMethod qb = makeQb('Ok.');
      expect(await qb.updateQbServerCookie(srv()), isTrue);
    });

    test('Fails. + HTTP 200 → 登录失败（旧代码这里会误判成功）', () async {
      final QbMethod qb = makeQb('Fails.');
      expect(await qb.updateQbServerCookie(srv()), isFalse);
    });

    test('空响应体 → 视为成功（旧版 qB 只靠 Set-Cookie）', () async {
      final QbMethod qb = makeQb('');
      expect(await qb.updateQbServerCookie(srv()), isTrue);
    });
  });
}
