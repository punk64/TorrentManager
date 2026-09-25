import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/utils/i18n.dart';
import 'package:torrent_manager/utils/ip_geo.dart';
import 'package:torrent_manager/utils/ip_geo_sources.dart';

Map<String, dynamic> successBody(String ip) => <String, dynamic>{
      'ip': ip,
      'status': 'success',
      'success': true,
      'ret': 200,
      'response_code': '200',
      'country': 'Testland',
      'country_name': 'Testland',
      'countryName': 'Testland',
      'regionName': 'Testshire',
      'region': 'Testshire',
      'region_name': 'Testshire',
      'stateProv': 'Testshire',
      'city': 'Testville',
      'cityName': 'Testville',
      'city_name': 'Testville',
      'addr': 'Testshire Testville TestISP',
      'isp': 'TestISP',
      'isp_name': 'TestISP',
      'asn_org': 'AS64512 TEST',
      'ipAddress': ip,
      'connection': <String, dynamic>{'isp': 'TestISP'},
      'location': <String, dynamic>{'country': 'Testland', 'city': 'Testville'},
      'data': <String, dynamic>{
        'country': 'Testland',
        'prov': 'Testshire',
        'city': 'Testville',
        'isp': 'TestISP',
      },
    };

Map<String, dynamic> baiduBody(String ip) => <String, dynamic>{
      'status': '0',
      'origip': ip,
      'data': <dynamic>[
        <String, dynamic>{'location': 'Testshire Testville TestISP'},
      ],
    };

Dio makeFakeDio({
  String? respondIp,
  Map<String, int> statusByHost = const <String, int>{},
  Map<String, Map<String, dynamic>> bodyByHost =
      const <String, Map<String, dynamic>>{},
  Map<String, dynamic> Function(String host)? bodyBuilder,
  required Map<String, int> hits,
  List<String>? seenHosts,
}) {
  final RegExp ipv4Re = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})');
  final Dio dio = Dio(BaseOptions(validateStatus: (int? s) => true));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (RequestOptions o, RequestInterceptorHandler h) async {
      final String host = o.uri.host;
      hits[host] = (hits[host] ?? 0) + 1;
      seenHosts?.add(host);
      final int status = statusByHost[host] ?? statusByHost['*'] ?? 200;
      if (status != 200) {
        h.resolve(Response<dynamic>(
          requestOptions: o,
          statusCode: status,
          data: 'fake-error',
        ));
        return;
      }

      final String ip = respondIp ??
          ipv4Re.firstMatch(Uri.decodeComponent(o.uri.toString()))?.group(1) ??
          '0.0.0.0';
      final Map<String, dynamic> body = bodyByHost[host] ??
          bodyBuilder?.call(host) ??
          (host == 'opendata.baidu.com' ? baiduBody(ip) : successBody(ip));
      h.resolve(Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: jsonEncode(body),
      ));
    },
  ));
  return dio;
}

final Map<String, String> kHostToId = <String, String>{
  for (final IpGeoSource s in kZhGeoPool) s.host: s.id,
};

void main() {
  setUp(() {
    L.code.value = '';
    IpGeo.offline = false;
    IpGeo.instance.resetStateForTest();
  });

  test('★ 成功查询：结果非空且不含源自报以外的 IP 冲突', () async {
    final Map<String, int> hits = <String, int>{};
    IpGeo.instance.injectDioForTest(makeFakeDio(
      respondIp: '8.8.8.8',
      hits: hits,
    ));
    final String? r = await IpGeo.instance.lookup('8.8.8.8');
    expect(r, isNotNull, reason: '★ 池里绝大多数源都能解析统一成功响应');
    expect(r, contains('Test'), reason: '★ 结果应来自假响应字段');
  });

  test('★ 中文优先 + 洗牌均摊：中文源正常时只打中文源，且分散到多个源', () async {
    final Map<String, int> hits = <String, int>{};
    final List<String> seen = <String>[];
    IpGeo.instance.injectDioForTest(makeFakeDio(hits: hits, seenHosts: seen));
    for (int i = 0; i < 20; i++) {
      await IpGeo.instance.lookup('8.8.${i ~/ 256}.${i % 256}');
    }
    final Set<String> zhHosts =
        kZhGeoPool.map((IpGeoSource s) => s.host).toSet();
    final int total = hits.values.fold<int>(0, (int a, int b) => a + b);
    expect(total, 20, reason: '★ 每个未缓存的 IP 只发一次请求（成功即止）');
    expect(seen.every(zhHosts.contains), isTrue,
        reason: '★ 中文源可用时不应触碰英文源（英文仅作兜底）');
    expect(hits.keys.length, greaterThanOrEqualTo(3),
        reason: '★ 请求应分散到多个中文源，而不是集中打同一个');
  });

  test('★ 失败换源：全部 500 时单个 IP 最多试 8 个源（中文 4 + 英文 4），返回 null',
      () async {
    final Map<String, int> hits = <String, int>{};
    IpGeo.instance.injectDioForTest(makeFakeDio(
      respondIp: '8.8.8.8',
      statusByHost: <String, int>{'*': 500},
      hits: hits,
    ));
    final String? r = await IpGeo.instance.lookup('8.8.8.1');
    expect(r, isNull);
    final int total = hits.values.fold<int>(0, (int a, int b) => a + b);
    expect(total, 8, reason: '★ 首选池 4 源 + 备用池 4 源；失败立刻换下一个');
  });

  test('★ 429 冷却：被限流的源在冷却期内不再被选中，且查询仍能成功', () async {
    const String limitedHost = 'ip9.com.cn';
    final Map<String, int> hits = <String, int>{};
    IpGeo.instance.injectDioForTest(makeFakeDio(
      statusByHost: <String, int>{limitedHost: 429},
      hits: hits,
    ));
    String? last;
    for (int i = 0; i < 8; i++) {
      last = await IpGeo.instance.lookup('8.8.${i ~/ 256}.${i % 256}');
    }
    expect(last, isNotNull, reason: '★ 其它源正常时整体查询应成功');
    final int limitedHits = hits[limitedHost] ?? 0;
    expect(limitedHits, lessThanOrEqualTo(1),
        reason: '★ 429 之后该源冷却 30 分钟，短时间内不会再被打');
    if (limitedHits >= 1) {
      final String id = kHostToId[limitedHost]!;
      expect(IpGeo.instance.cooldownUntilForTest.containsKey(id), isTrue,
          reason: '★ 被限流的源应出现在冷却表里');
    }
  });

  test('★ 连败冷却：持续失败若干 IP 后，必须有源进入冷却', () async {
    final Map<String, int> hits = <String, int>{};
    IpGeo.instance.injectDioForTest(makeFakeDio(
      respondIp: '8.8.8.8',
      statusByHost: <String, int>{'*': 500},
      hits: hits,
    ));
    for (int i = 0; i < 15; i++) {
      await IpGeo.instance.lookup('8.8.${i ~/ 256}.${i % 256}');
    }
    final int total = hits.values.fold<int>(0, (int a, int b) => a + b);
    expect(total, greaterThanOrEqualTo(30),
        reason: '★ 15 个 IP 的失败请求应真实发出（负缓存只对同 IP 生效）');
    expect(IpGeo.instance.cooldownUntilForTest, isNotEmpty,
        reason: '★ 失败分布到中/英两池，必有源连败 3 次进冷却');
  });

  test('★ 回环校验：响应自报的 IP 与查询不一致时视为坏数据', () async {
    final Map<String, int> hits = <String, int>{};
    IpGeo.instance.injectDioForTest(makeFakeDio(
      respondIp: '9.9.9.9',
      hits: hits,
    ));
    final String? r = await IpGeo.instance.lookup('8.8.8.8');
    expect(r, isNull, reason: '★ 回环 IP 不一致 = 数据不可信，必须丢弃');
    final int total = hits.values.fold<int>(0, (int a, int b) => a + b);
    expect(total, 8, reason: '★ 坏数据按普通失败处理：中文 4 + 英文 4');
  });

  test('★ 输出净化：污染字符（双向重写符 / 控制符 / 尖括号）不进入结果', () async {
    final Map<String, dynamic> dirty = successBody('8.8.8.8');
    dirty['country'] = 'A\u202EB\u0000<img>CC';
    dirty['countryName'] = dirty['country'];
    dirty['country_name'] = dirty['country'];
    IpGeo.instance.injectDioForTest(makeFakeDio(
      respondIp: '8.8.8.8',
      bodyByHost: <String, Map<String, dynamic>>{'opendata.baidu.com': dirty},
      bodyBuilder: (String host) => dirty,
      hits: <String, int>{},
    ));
    final String? r = await IpGeo.instance.lookup('8.8.8.8');
    expect(r, isNotNull);
    expect(r, isNot(contains('<')));
    expect(r, isNot(contains('>')));
    expect(r, isNot(contains('\u202E')));
    expect(r, isNot(contains('\u0000')));
  });

  test('★ 超大响应：>32KB 直接丢弃不解析', () async {
    final Map<String, int> hits = <String, int>{};
    IpGeo.instance.injectDioForTest(makeFakeDio(
      respondIp: '8.8.8.8',
      bodyBuilder: (String host) => <String, dynamic>{
        'pad': 'x' * (IpGeo.maxBodyChars + 1024),
      },
      hits: hits,
    ));
    final String? r = await IpGeo.instance.lookup('8.8.8.8');
    expect(r, isNull);
    final int total = hits.values.fold<int>(0, (int a, int b) => a + b);
    expect(total, 8, reason: '★ 超大响应按失败处理：中文 4 + 英文 4');
  });

  test('★ IPv6 查询：不支持 IPv6 的源（pconline / baidu / ipwho.is）绝不参与',
      () async {
    final Map<String, int> hits = <String, int>{};
    final List<String> seen = <String>[];
    IpGeo.instance.injectDioForTest(makeFakeDio(
      respondIp: '2400:3200::1',
      hits: hits,
      seenHosts: seen,
    ));
    final String? r =
        await IpGeo.instance.lookup('2400:3200::1');
    expect(r, isNotNull, reason: '★ IPv6 池里有支持 IPv6 的源，应能成功');
    for (final String host in seen) {
      expect(host, isNot('whois.pconline.com.cn'),
          reason: '★ pconline 查 IPv6 会返回错误数据，必须屏蔽');
      expect(host, isNot('opendata.baidu.com'),
          reason: '★ baidu-opendata 查 IPv6 返回空结果，必须屏蔽');
      expect(host, isNot('ipwho.is'),
          reason: '★ ipwho.is 不通 IPv6，必须屏蔽');
    }
  });

  test('★ 失败负缓存：同一 IP 失败后走缓存，不再发请求', () async {
    final Map<String, int> hits = <String, int>{};
    IpGeo.instance.injectDioForTest(makeFakeDio(
      respondIp: '8.8.8.8',
      statusByHost: <String, int>{'*': 500},
      hits: hits,
    ));
    await IpGeo.instance.lookup('8.8.8.77');
    final int first = hits.values.fold<int>(0, (int a, int b) => a + b);
    final String? again = await IpGeo.instance.lookup('8.8.8.77');
    final int second = hits.values.fold<int>(0, (int a, int b) => a + b);
    expect(again, isNull);
    expect(second, first, reason: '★ 失败结果进永久负缓存，重复查询零请求');
  });

  test('★ T2 兜底：中文源全部失败时，同一轮内立即改用英文源', () async {
    final Set<String> zhHosts =
        kZhGeoPool.map((IpGeoSource s) => s.host).toSet();
    final Map<String, int> hits = <String, int>{};
    final List<String> seen = <String>[];
    IpGeo.instance.injectDioForTest(makeFakeDio(
      respondIp: '8.8.8.8',
      statusByHost: <String, int>{for (final String h in zhHosts) h: 500},
      hits: hits,
      seenHosts: seen,
    ));
    final String? r = await IpGeo.instance.lookup('8.8.8.8');
    expect(r, isNotNull, reason: '★ 中文源全失败 → 应回退英文源并成功');
    expect(seen.any((String h) => !zhHosts.contains(h)), isTrue,
        reason: '★ 必须实际命中过英文源');
  });

  test('★ 英文语言：英文池优先；英文源全失败时回退中文池', () async {
    L.code.value = L.en;
    addTearDown(() => L.code.value = '');
    final Set<String> enHosts =
        kEnGeoPool.map((IpGeoSource s) => s.host).toSet();
    final Map<String, int> hits = <String, int>{};
    final List<String> seen = <String>[];
    IpGeo.instance.injectDioForTest(makeFakeDio(
      respondIp: '8.8.8.8',
      statusByHost: <String, int>{for (final String h in enHosts) h: 500},
      hits: hits,
      seenHosts: seen,
    ));
    final String? r = await IpGeo.instance.lookup('8.8.8.8');
    expect(r, isNotNull, reason: '★ 英文源全失败 → 应回退中文源并成功');
    expect(seen.any((String h) => !enHosts.contains(h)), isTrue,
        reason: '★ 必须实际命中过中文源');
  });
}
