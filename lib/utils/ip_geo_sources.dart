class IpGeoSource {
  const IpGeoSource({
    required this.id,
    required this.host,
    required this.buildUrl,
    required this.parse,
    this.ipv6 = false,
  });

  final String id;

  final String host;

  final String Function(String encodedIp) buildUrl;

  final List<String>? Function(Map<String, dynamic> m) parse;

  final bool ipv6;
}

String? _s(dynamic v) {
  if (v == null) return null;
  final String s = v.toString().trim();
  return s.isEmpty ? null : s;
}

List<String>? _gather(List<dynamic> parts) {
  final List<String> out = <String>[];
  for (final dynamic v in parts) {
    final String? s = _s(v);
    if (s != null) out.add(s);
  }
  return out.isEmpty ? null : out;
}

List<String>? _parseIpApi(Map<String, dynamic> m) {
  if (m['status'] != 'success') return null;
  return _gather(<dynamic>[m['country'], m['regionName'], m['city'], m['isp']]);
}

List<String>? _parseIpWhoIs(Map<String, dynamic> m) {
  if (m['success'] != true) return null;
  final dynamic conn = m['connection'];
  return _gather(<dynamic>[
    m['country'],
    m['region'],
    m['city'],
    conn is Map ? conn['isp'] : null,
  ]);
}

List<String>? _parseIpSb(Map<String, dynamic> m) {
  if (m.containsKey('error') || m.containsKey('message')) return null;
  return _gather(<dynamic>[m['country'], m['region'], m['city'], m['isp']]);
}

List<String>? _parseGeoJs(Map<String, dynamic> m) {
  return _gather(<dynamic>[m['country'], m['city'], m['organization_name']]);
}

List<String>? _parseIpLocationNet(Map<String, dynamic> m) {
  if (m['response_code'] != '200') return null;
  return _gather(<dynamic>[m['country_name'], m['isp']]);
}

List<String>? _parseIpQuery(Map<String, dynamic> m) {
  final dynamic loc = m['location'];
  final dynamic isp = m['isp'];
  if (loc is! Map) return null;
  return _gather(<dynamic>[
    loc['country'],
    loc['city'],
    isp is Map ? isp['isp'] : null,
  ]);
}

List<String>? _parseDbIp(Map<String, dynamic> m) {
  if (m.containsKey('errorCode') || m.containsKey('error')) return null;
  return _gather(<dynamic>[m['countryName'], m['stateProv'], m['city']]);
}

List<String>? _parseIfConfigCo(Map<String, dynamic> m) {
  return _gather(
      <dynamic>[m['country'], m['region_name'], m['city'], m['asn_org']]);
}

List<String>? _parseTechnikNews(Map<String, dynamic> m) {
  if (m['status'] != 'success') return null;
  return _gather(<dynamic>[m['country'], m['regionName'], m['city'], m['isp']]);
}

List<String>? _parseFreeIpApi(Map<String, dynamic> m) {
  if (_s(m['ipAddress']) == null) return null;
  return _gather(
      <dynamic>[m['countryName'], m['regionName'], m['cityName']]);
}

List<String>? _parseIpLeak(Map<String, dynamic> m) {
  return _gather(<dynamic>[
    m['country_name'],
    m['region_name'],
    m['city_name'],
    m['isp_name'],
  ]);
}

List<String>? _parseIp9(Map<String, dynamic> m) {
  if (m['ret'] != 200) return null;
  final dynamic d = m['data'];
  if (d is! Map) return null;
  return _gather(<dynamic>[d['country'], d['prov'], d['city'], d['isp']]);
}

List<String>? _parsePconline(Map<String, dynamic> m) {
  final String? addr = _s(m['addr']);
  if (addr == null) return null;
  return <String>[addr];
}

List<String>? _parseBaiduOpenData(Map<String, dynamic> m) {
  if (m['status'] != '0') return null;
  final dynamic d = m['data'];
  if (d is! List || d.isEmpty) return null;
  final dynamic first = d.first;
  if (first is! Map) return null;
  final String? loc = _s(first['location']);
  if (loc == null) return null;
  return <String>[loc];
}

final IpGeoSource _ipApiZh = IpGeoSource(
  id: 'ip-api-zh',
  host: 'ip-api.com',
  ipv6: true,
  buildUrl: (String e) =>
      'http://ip-api.com/json/$e?fields=status,country,regionName,city,isp&lang=zh-CN',
  parse: _parseIpApi,
);

final IpGeoSource _ipApiEn = IpGeoSource(
  id: 'ip-api-en',
  host: 'ip-api.com',
  ipv6: true,
  buildUrl: (String e) =>
      'http://ip-api.com/json/$e?fields=status,country,regionName,city,isp',
  parse: _parseIpApi,
);

final IpGeoSource _ip9 = IpGeoSource(
  id: 'ip9',
  host: 'ip9.com.cn',
  ipv6: true,
  buildUrl: (String e) => 'https://ip9.com.cn/get?ip=$e',
  parse: _parseIp9,
);

final IpGeoSource _pconline = IpGeoSource(
  id: 'pconline',
  host: 'whois.pconline.com.cn',
  ipv6: false,
  buildUrl: (String e) =>
      'https://whois.pconline.com.cn/ipJson.jsp?ip=$e&json=true',
  parse: _parsePconline,
);

final IpGeoSource _baidu = IpGeoSource(
  id: 'baidu-opendata',
  host: 'opendata.baidu.com',
  ipv6: false,
  buildUrl: (String e) =>
      'https://opendata.baidu.com/api.php?query=$e&resource_id=6006&oe=utf8',
  parse: _parseBaiduOpenData,
);

final IpGeoSource _ipWhoIs = IpGeoSource(
  id: 'ipwho.is',
  host: 'ipwho.is',
  ipv6: false,
  buildUrl: (String e) => 'https://ipwho.is/$e',
  parse: _parseIpWhoIs,
);

final IpGeoSource _ipWhoisApp = IpGeoSource(
  id: 'ipwhois.app',
  host: 'ipwhois.app',
  ipv6: true,
  buildUrl: (String e) => 'https://ipwhois.app/json/$e',
  parse: _parseIpWhoIs,
);

final IpGeoSource _ipSb = IpGeoSource(
  id: 'ip.sb',
  host: 'api.ip.sb',
  ipv6: true,
  buildUrl: (String e) => 'https://api.ip.sb/geoip/$e',
  parse: _parseIpSb,
);

final IpGeoSource _geoJs = IpGeoSource(
  id: 'geojs.io',
  host: 'get.geojs.io',
  ipv6: true,
  buildUrl: (String e) => 'https://get.geojs.io/v1/ip/geo/$e.json',
  parse: _parseGeoJs,
);

final IpGeoSource _ipLocationNet = IpGeoSource(
  id: 'iplocation.net',
  host: 'api.iplocation.net',
  ipv6: true,
  buildUrl: (String e) => 'https://api.iplocation.net/?ip=$e',
  parse: _parseIpLocationNet,
);

final IpGeoSource _ipQuery = IpGeoSource(
  id: 'ipquery.io',
  host: 'api.ipquery.io',
  ipv6: true,
  buildUrl: (String e) => 'https://api.ipquery.io/$e',
  parse: _parseIpQuery,
);

final IpGeoSource _dbIp = IpGeoSource(
  id: 'db-ip',
  host: 'api.db-ip.com',
  ipv6: true,
  buildUrl: (String e) => 'https://api.db-ip.com/v2/free/$e',
  parse: _parseDbIp,
);

final IpGeoSource _ifConfigCo = IpGeoSource(
  id: 'ifconfig.co',
  host: 'ifconfig.co',
  ipv6: true,
  buildUrl: (String e) => 'https://ifconfig.co/json?ip=$e',
  parse: _parseIfConfigCo,
);

final IpGeoSource _technikNews = IpGeoSource(
  id: 'techniknews',
  host: 'api.techniknews.net',
  ipv6: true,
  buildUrl: (String e) => 'https://api.techniknews.net/ipgeo/$e',
  parse: _parseTechnikNews,
);

final IpGeoSource _freeIpApi = IpGeoSource(
  id: 'freeipapi',
  host: 'freeipapi.com',
  ipv6: true,
  buildUrl: (String e) => 'https://freeipapi.com/api/json/$e',
  parse: _parseFreeIpApi,
);

final IpGeoSource _ipLeak = IpGeoSource(
  id: 'ipleak.net',
  host: 'ipleak.net',
  ipv6: true,
  buildUrl: (String e) => 'https://ipleak.net/json/$e',
  parse: _parseIpLeak,
);

final List<IpGeoSource> kZhGeoPool = <IpGeoSource>[
  _ipApiZh,
  _ip9,
  _pconline,
  _baidu,
];

final List<IpGeoSource> kEnGeoPool = <IpGeoSource>[
  _ipApiEn,
  _ipWhoIs,
  _ipSb,
  _geoJs,
  _ipWhoisApp,
  _ipLocationNet,
  _ipQuery,
  _dbIp,
  _ifConfigCo,
  _technikNews,
  _freeIpApi,
  _ipLeak,
];
