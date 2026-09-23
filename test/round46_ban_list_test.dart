import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:get/get.dart' hide Response, FormData;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/qb_ip_filter.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';

ServerData qbSrv(String id, String host) => ServerData(
      id: id,
      name: 'NAS-$id',
      type: 'qbittorrent',
      host: host,
      port: 8080,
    );

Dio fakeQbPrefs({
  Map<String, dynamic>? prefs,
  List<RequestOptions>? log,
}) {
  final Dio dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) {
      log?.add(o);
      final String p = o.uri.path;
      if (p.endsWith('/app/preferences')) {
        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: prefs ?? <String, dynamic>{},
        ));
        return;
      }
      if (p.contains('app/version')) {
        h.resolve(Response<dynamic>(
            requestOptions: o, statusCode: 200, data: 'v5.0.5'));
        return;
      }

      h.resolve(
          Response<dynamic>(requestOptions: o, statusCode: 200, data: 'Ok.'));
    },
  ));
  return dio;
}

Future<Map<String, dynamic>> sentPrefs(List<RequestOptions> log) async {
  final RequestOptions w = log
      .lastWhere((RequestOptions o) => o.path.contains('setPreferences'));
  final FormData fd = w.data as FormData;
  final String json =
      fd.fields.firstWhere((MapEntry<String, String> e) => e.key == 'json').value;
  return jsonDecode(json) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SecurePrefs.useMemoryBackendForTest();
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() => Get.reset());

  group('QbIpFilter · 名单按原文处理', () {
    test('拆分：换行与回车都算分隔，空行丢弃、逐条去空白', () {
      expect(
        QbIpFilter.splitEntries('1.1.1.1\r\n2.2.2.2\n\n  3.3.3.3  \n'),
        <String>['1.1.1.1', '2.2.2.2', '3.3.3.3'],
      );
    });

    test('拼回：`\\n` 分隔且**不留末尾换行**', () {
      expect(
        QbIpFilter.joinEntries(<String>['1.1.1.1', ' 2.2.2.2 ', '']),
        '1.1.1.1\n2.2.2.2',
      );
    });

    test('只改开关时，名单原文一个字都不动', () {
      const String raw = '1.1.1.1\n\n2.2.2.0/24\n';
      const QbIpFilter f = QbIpFilter(
          enabled: true, filterTrackers: false, bannedIps: raw);
      final QbIpFilter next = f.copyWith(enabled: false);
      expect(next.bannedIps, raw, reason: '文案未动 → 不该被归一化');
      expect(next.diffFrom(f).keys, <String>['ip_filter_enabled']);
    });
  });

  group('QbIpFilter · 校验（挡住明显打错的输入）', () {
    test('合法：单个 IPv4 / 网段 / IPv6 / IPv6 网段', () {
      expect(QbIpFilter.isValidEntry('1.2.3.4'), isTrue);
      expect(QbIpFilter.isValidEntry('1.2.3.0/24'), isTrue);
      expect(QbIpFilter.isValidEntry('91.219.236.0/22'), isTrue);
      expect(QbIpFilter.isValidEntry('2001:db8::1'), isTrue);
      expect(QbIpFilter.isValidEntry('2001:db8::/32'), isTrue);
    });

    test('非法：越界 / 前导零 / 乱码 / 前缀超范围', () {
      expect(QbIpFilter.isValidEntry(''), isFalse);
      expect(QbIpFilter.isValidEntry('abc'), isFalse);
      expect(QbIpFilter.isValidEntry('1.2.3.256'), isFalse);
      expect(QbIpFilter.isValidEntry('1.2.3'), isFalse);
      expect(QbIpFilter.isValidEntry('01.2.3.4'), isFalse);
      expect(QbIpFilter.isValidEntry('1.2.3.4/99'), isFalse);
      expect(QbIpFilter.isValidEntry('1.2.3.4/24/8'), isFalse);
    });
  });

  group('QbIpFilter · 增删改（草稿操作）', () {
    test('追加：重复项与空串都不生效', () {
      final List<String> a = QbIpFilter.addEntry(<String>['1.1.1.1'], '2.2.2.2');
      expect(a, <String>['1.1.1.1', '2.2.2.2']);
      expect(QbIpFilter.addEntry(a, '2.2.2.2'), a);
      expect(QbIpFilter.addEntry(a, '   '), a);
    });

    test('替换 / 删除：下标越界时原样返回，不抛异常', () {
      final List<String> a = <String>['1.1.1.1', '2.2.2.2'];
      expect(QbIpFilter.replaceEntry(a, 1, '3.3.3.3'),
          <String>['1.1.1.1', '3.3.3.3']);
      expect(QbIpFilter.replaceEntry(a, 9, '3.3.3.3'), a);
      expect(QbIpFilter.removeEntry(a, 0), <String>['2.2.2.2']);
      expect(QbIpFilter.removeEntry(a, -1), a);
    });

    test('差异摘要：条数增减（日志里那句 `N 条（+a / -b）`）', () {
      const QbIpFilter old = QbIpFilter(
          enabled: false, filterTrackers: false, bannedIps: '1.1.1.1\n2.2.2.2');
      final QbIpFilter next = old.copyWith(bannedIps: '1.1.1.1\n3.3.3.3\n4.4.4.4');
      expect(next.diffSummary(old), '3 条（+2 / -1）');
    });
  });

  group('QbMethod · 黑名单读写', () {
    test('getIpFilter：从 app/preferences 取三项，缺键不抛', () async {
      final QbMethod qb = QbMethod(
        dio: fakeQbPrefs(prefs: <String, dynamic>{
          'ip_filter_enabled': true,
          'banned_IPs': '1.1.1.1\n2.2.2.0/24',
        }),
      );
      qb.setServer(qbSrv('a', '10.0.0.1'));
      final QbIpFilter f = await qb.getIpFilter();
      expect(f.enabled, isTrue);
      expect(f.filterTrackers, isFalse, reason: '缺键 → false（不假设字段存在）');
      expect(f.count, 2);
    });

    test('setIpFilter：**只下发变化的键**（没读到的字段绝不写回）', () async {
      final List<RequestOptions> log = <RequestOptions>[];
      final QbMethod qb = QbMethod(dio: fakeQbPrefs(log: log));
      qb.setServer(qbSrv('a', '10.0.0.1'));

      const QbIpFilter base = QbIpFilter(
          enabled: false, filterTrackers: false, bannedIps: '1.1.1.1');
      await qb.setIpFilter(base.copyWith(enabled: true), base: base);

      final Map<String, dynamic> sent = await sentPrefs(log);
      expect(sent.keys.toList(), <String>['ip_filter_enabled'],
          reason: '只改了开关 → 补丁里只能出现 ip_filter_enabled');
      expect(sent['ip_filter_enabled'], isTrue);
    });

    test('setIpFilter：名单变化时下发**原文**，不做任何归一化', () async {
      final List<RequestOptions> log = <RequestOptions>[];
      final QbMethod qb = QbMethod(dio: fakeQbPrefs(log: log));
      qb.setServer(qbSrv('a', '10.0.0.1'));

      const String raw = '1.1.1.1\n\n2.2.2.2\n';
      const QbIpFilter base = QbIpFilter(
          enabled: true, filterTrackers: true, bannedIps: '1.1.1.1');
      await qb.setIpFilter(
        base.copyWith(bannedIps: raw),
        base: base,
      );

      final Map<String, dynamic> sent = await sentPrefs(log);
      expect(sent.keys.toList(), <String>['banned_IPs']);
      expect(sent['banned_IPs'], raw);
    });

    test('setIpFilter：没有任何变化时**一笔请求都不发**', () async {
      final List<RequestOptions> log = <RequestOptions>[];
      final QbMethod qb = QbMethod(dio: fakeQbPrefs(log: log));
      qb.setServer(qbSrv('a', '10.0.0.1'));

      const QbIpFilter base = QbIpFilter(
          enabled: true, filterTrackers: true, bannedIps: '1.1.1.1');
      await qb.setIpFilter(base, base: base);

      expect(
        log.where((RequestOptions o) => o.path.contains('setPreferences')),
        isEmpty,
      );
    });
  });
}
