import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/server_capabilities.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';

/// 假 TR 客户端：拦下 RPC，记录 `<method> <arguments json>`，并回一份可控响应。
///
/// [trackerList] 是 `torrent-get` 时返回的 trackerList 内容（V5 的读-改-写要用它）。
Dio _fakeTrDio(List<String> calls,
    {List<String> trackerList = const <String>[]}) {
  final Dio dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.1.10:9091',
    validateStatus: (int? s) => s != null && s < 500,
    followRedirects: false,
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      String method = '';
      Map<String, dynamic> args = <String, dynamic>{};
      final Object? body = o.data;
      if (body is String) {
        try {
          final Map<String, dynamic> m =
              jsonDecode(body) as Map<String, dynamic>;
          method = m['method']?.toString() ?? '';
          args = (m['arguments'] as Map<String, dynamic>?) ??
              <String, dynamic>{};
        } catch (_) {
          method = '<unparsable>';
        }
      }
      calls.add('$method ${jsonEncode(args)}');

      Map<String, dynamic> ret = <String, dynamic>{};
      if (method == 'torrent-get') {
        ret = <String, dynamic>{
          'torrents': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'trackerList': trackerList},
          ],
        };
      } else if (method == 'free-space') {
        ret = <String, dynamic>{'path': args['path'], 'size-bytes': 12345678};
      }
      h.resolve(Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: <String, dynamic>{'result': 'success', 'arguments': ret},
      ));
    },
  ));
  return dio;
}

ServerData _srv(String type, {String id = 's1'}) => ServerData(
      id: id,
      name: 'server-$id',
      type: type,
      host: '192.168.1.10',
      port: type == 'qbittorrent' ? 8080 : 9091,
    );

String _setCall(List<String> calls) => calls.firstWhere(
      (String c) => c.startsWith('torrent-set '),
      orElse: () => '',
    );

void main() {
  group('第 68 轮 · V5/V7 版本门槛（都是 4.0.0）', () {
    test('V5 trackerList：4.0+ 才有；版本未知保守走旧接口', () {
      expect(ServerCapabilities.trCanTrackerList('4.0.0'), isTrue);
      expect(ServerCapabilities.trCanTrackerList('4.1.0'), isTrue);
      expect(ServerCapabilities.trCanTrackerList('3.00'), isFalse);
      expect(ServerCapabilities.trCanTrackerList(''), isFalse,
          reason: '版本取不到 ⇒ 走 4.0 起 deprecated、但 4.x 仍可用的旧三件套，'
              '宁可走老路也不要冒然发 4.0 才有的字段');
    });

    test('V7 free-space：同样 4.0 门槛', () {
      expect(ServerCapabilities.trHasFreeSpaceMethod('4.0.0'), isTrue);
      expect(ServerCapabilities.trHasFreeSpaceMethod('4.1.0'), isTrue);
      expect(ServerCapabilities.trHasFreeSpaceMethod('3.00'), isFalse);
      expect(ServerCapabilities.trHasFreeSpaceMethod(''), isFalse);
    });

    test('能力包按服务器版本开关：TR 4.1 开、TR 3.0 关、qB 恒关', () {
      final CapabilitySet tr41 =
          ServerCapabilities.of(_srv('transmission'), appVersion: '4.1.0');
      expect(tr41.trackerList, isTrue);
      expect(tr41.freeSpaceMethod, isTrue);

      final CapabilitySet tr30 =
          ServerCapabilities.of(_srv('transmission'), appVersion: '3.00');
      expect(tr30.trackerList, isFalse);
      expect(tr30.freeSpaceMethod, isFalse);

      final CapabilitySet qb = ServerCapabilities.of(
        _srv('qbittorrent'),
        appVersion: '5.0.0',
        apiVersion: '2.11.0',
      );
      expect(qb.trackerList, isFalse,
          reason: 'qB 的 tracker 走 addTrackers/removeTrackers（按 URL），'
              '与 TR 的 trackerList 不是一回事');
      expect(qb.freeSpaceMethod, isFalse);
    });
  });

  group('第 68 轮 · V5 trackerList 读-改-写', () {
    test('新增：先读回全量再 append，最后整份写回', () async {
      final List<String> calls = <String>[];
      final TrMethod tr = TrMethod(
        dio: _fakeTrDio(calls, trackerList: <String>['udp://a', 'udp://b']),
      );

      await tr.addTrackersByList(1, <String>['udp://c']);

      expect(calls.first, startsWith('torrent-get '),
          reason: '★ trackerList 只能整份替换 ⇒ 必须先读回现状，否则会把已有 tracker 全冲掉');
      final String set = _setCall(calls);
      expect(set, contains('trackerList'));
      expect(set, contains('udp://a'));
      expect(set, contains('udp://b'));
      expect(set, contains('udp://c'));
    });

    test('删除：按下标删掉对应项，其余保留', () async {
      final List<String> calls = <String>[];
      final TrMethod tr = TrMethod(
        dio: _fakeTrDio(calls,
            trackerList: <String>['udp://a', 'udp://b', 'udp://c']),
      );

      await tr.removeTrackerByIndex(1, 1);

      final String set = _setCall(calls);
      expect(set, contains('udp://a'));
      expect(set, contains('udp://c'));
      expect(set, isNot(contains('udp://b')));
    });

    test('修改：按下标替换，其余保留', () async {
      final List<String> calls = <String>[];
      final TrMethod tr = TrMethod(
        dio: _fakeTrDio(calls, trackerList: <String>['udp://a', 'udp://b']),
      );

      await tr.editTrackerByIndex(1, 1, 'udp://new');

      final String set = _setCall(calls);
      expect(set, contains('udp://new'));
      expect(set, isNot(contains('udp://b')));
    });

    test('越界下标不发写请求（宁可不改，也不能把整份 tracker 写坏）', () async {
      final List<String> calls = <String>[];
      final TrMethod tr = TrMethod(
        dio: _fakeTrDio(calls, trackerList: <String>['udp://a']),
      );

      await tr.removeTrackerByIndex(1, 5);
      await tr.editTrackerByIndex(1, 5, 'udp://x');

      expect(calls.any((String c) => c.startsWith('torrent-set ')), isFalse);
    });

    test('旧接口路径：多 URL 按数组成组发送（不再塞成一个含换行的畸形 URL）',
        () async {
      final List<String> calls = <String>[];
      final TrMethod tr = TrMethod(dio: _fakeTrDio(calls));

      await tr.addTrackers(<int>[1], <String>['udp://a', 'udp://b']);

      final String set = _setCall(calls);
      expect(set, contains('trackerAdd'));
      expect(set, contains('udp://a'));
      expect(set, contains('udp://b'));
      expect(set, isNot(contains(r'\n')));
    });
  });

  group('第 68 轮 · V7 free-space', () {
    test('按路径查剩余空间，取 size-bytes', () async {
      final List<String> calls = <String>[];
      final TrMethod tr = TrMethod(dio: _fakeTrDio(calls));

      expect(await tr.freeSpace('/downloads'), 12345678);
      expect(calls.single, contains('free-space'));
      expect(calls.single, contains('/downloads'));
    });

    test('空路径不发请求（直接返回 null，不上服务端瞎问）', () async {
      final List<String> calls = <String>[];
      final TrMethod tr = TrMethod(dio: _fakeTrDio(calls));

      expect(await tr.freeSpace('   '), isNull);
      expect(calls, isEmpty);
    });
  });
}
