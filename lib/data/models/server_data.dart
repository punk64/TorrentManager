import '../../utils/formatter.dart';
import 'torrent.dart';

class ServerData {
  final String id;
  final String name;

  final String type;
  final String host;
  final int port;

  final String? lanHost;

  final int? lanPort;

  final String? username;
  final String? password;
  final bool useHttps;

  final String? sid;

  final String? sessionId;

  final double? ratioLimit;

  final String? group;

  final bool hideAddress;

  final bool hidePort;

  final List<Torrent> torrents;

  final Set<String> selected;

  final Object? state;

  ServerData({
    required this.id,
    required this.name,
    required this.type,
    required this.host,
    required this.port,
    this.lanHost,
    this.lanPort,
    this.username,
    this.password,
    this.useHttps = false,
    this.sid,
    this.sessionId,
    this.ratioLimit,
    this.group,

    this.hideAddress = true,
    this.hidePort = true,
    this.torrents = const <Torrent>[],
    this.selected = const <String>{},
    this.state,
  });

  factory ServerData.fromJson(Map<String, dynamic> json) {
    return ServerData(
      id: Formatter.getString(json, 'id'),
      name: Formatter.getString(json, 'name'),
      type: Formatter.getString(json, 'type', def: 'qbittorrent'),
      host: Formatter.getString(json, 'host'),

      port: Formatter.getInt(json, 'port', def: 443),
      lanHost: Formatter.getStringOrNull(json, 'lanHost'),
      lanPort: json['lanPort'] == null
          ? null
          : Formatter.getInt(json, 'lanPort'),
      username: Formatter.getStringOrNull(json, 'username'),
      password: Formatter.getStringOrNull(json, 'password'),
      useHttps: Formatter.getBool(json, 'useHttps'),
      sid: Formatter.getStringOrNull(json, 'sid'),
      sessionId: Formatter.getStringOrNull(json, 'sessionId'),
      ratioLimit: json['ratioLimit'] == null
          ? null
          : Formatter.getDouble(json, 'ratioLimit'),
      group: Formatter.getStringOrNull(json, 'group'),

      hideAddress: Formatter.getBool(json, 'hideAddress', def: true),
      hidePort: Formatter.getBool(json, 'hidePort', def: true),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      'host': host,
      'port': port,
      if (lanHost != null && lanHost!.isNotEmpty) 'lanHost': lanHost,
      if (lanPort != null) 'lanPort': lanPort,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      'useHttps': useHttps,
      if (sid != null) 'sid': sid,
      if (sessionId != null) 'sessionId': sessionId,
      if (ratioLimit != null) 'ratioLimit': ratioLimit,
      if (group != null && group!.isNotEmpty) 'group': group,

      'hideAddress': hideAddress,
      'hidePort': hidePort,
    };
  }

  ServerData copyWith({
    String? name,
    String? type,
    String? host,
    int? port,
    String? lanHost,
    int? lanPort,
    String? username,
    String? password,
    bool? useHttps,
    String? group,
    bool? hideAddress,
    bool? hidePort,
    List<Torrent>? torrents,
    Set<String>? selected,
    Object? state,
  }) {
    return ServerData(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      lanHost: lanHost ?? this.lanHost,
      lanPort: lanPort ?? this.lanPort,
      username: username ?? this.username,
      password: password ?? this.password,
      useHttps: useHttps ?? this.useHttps,
      sid: sid,
      sessionId: sessionId,
      ratioLimit: ratioLimit,
      group: group ?? this.group,
      hideAddress: hideAddress ?? this.hideAddress,
      hidePort: hidePort ?? this.hidePort,
      torrents: torrents ?? this.torrents,
      selected: selected ?? this.selected,
      state: state ?? this.state,
    );
  }

  bool get isQbittorrent => type.toLowerCase() == 'qbittorrent';
  bool get isTransmission => type.toLowerCase() == 'transmission';

  String get groupName =>
      (group == null || group!.trim().isEmpty) ? '未分类' : group!.trim();

  String get scheme => useHttps ? 'https' : 'http';

  bool get hasLan =>
      lanHost != null && lanHost!.isNotEmpty && lanPort != null;

  ServerData connectionTarget({required bool viaLan}) => (viaLan && hasLan)
      ? copyWith(host: lanHost!, port: lanPort!, useHttps: false)
      : this;

  String get normalizedHost {
    String h = host.trim();
    if (h.isEmpty) return h;
    if (h.contains('://')) {
      final Uri? u = Uri.tryParse(h);
      if (u != null && u.host.isNotEmpty) return u.host;
    }
    if (h.startsWith('[')) {
      final int close = h.indexOf(']');
      return close > 0 ? h.substring(0, close + 1) : h;
    }
    final int slash = h.indexOf('/');
    if (slash >= 0) h = h.substring(0, slash);
    h = h.trim();

    if (':'.allMatches(h).length >= 2) {
      return h.startsWith('[') ? h : '[$h]';
    }
    final int colon = h.indexOf(':');
    if (colon >= 0) h = h.substring(0, colon);
    return h.trim();
  }

  String get baseUrl =>
      Uri(scheme: scheme, host: normalizedHost, port: port).toString();

  String get displayAddress {
    final String h = hideAddress ? Formatter.maskHost(normalizedHost) : normalizedHost;
    final String p = hidePort ? '***' : '$port';
    if (!hideAddress && !hidePort) return baseUrl;
    return '$scheme://$h:$p';
  }

  int get totalTorrents => torrents.length;

  int get totalDownloading =>
      torrents.where((Torrent t) => t.isDownloading).length;

  int get totalSeeding => torrents.where((Torrent t) => t.isSeeding).length;

  int get totalPausedDL => torrents.where((Torrent t) => t.isPausedDL).length;

  int get totalPausedUP => torrents.where((Torrent t) => t.isPausedUP).length;

  int get totalChecking => torrents.where((Torrent t) => t.isChecking).length;

  int get totalError => torrents.where((Torrent t) => t.isError).length;

  int get totalUploading => torrents.where((Torrent t) => t.isUploading).length;

  int get totalStalled => torrents.where((Torrent t) => t.isStalled).length;

  List<String> get selectedTorrentsHashes => selected.toList();

  String get selectedHashes => selected.join('|');

  List<String> get selectedTorrentsName => torrents
      .where((Torrent t) => selected.contains(t.hash))
      .map((Torrent t) => t.name)
      .toList();

  List<String> get newSavePath {
    final Set<String> set = <String>{};
    for (final Torrent t in torrents) {
      final String? p = t.savePath;
      if (p != null && p.trim().isNotEmpty) set.add(p.trim());
    }
    return set.toList();
  }

  List<String> get newErrorString => torrents
      .where((Torrent t) => t.isError)
      .map((Torrent t) => '${t.name}: ${t.state}')
      .toList();

  List<String> get newTrackers {
    final Set<String> set = <String>{};
    for (final Torrent t in torrents) {
      final String host = t.site;
      if (host.isNotEmpty) set.add(host);
    }
    return set.toList();
  }

  List<String> get newTags {
    final Set<String> set = <String>{};
    for (final Torrent t in torrents) {
      final String raw = t.tags ?? '';
      for (final String tag in raw.split(',')) {
        final String v = tag.trim();
        if (v.isNotEmpty) set.add(v);
      }
    }
    return set.toList();
  }

  List<String> get newCategories {
    final Set<String> set = <String>{};
    for (final Torrent t in torrents) {
      final String v = (t.category ?? '').trim();
      if (v.isNotEmpty) set.add(v);
    }
    return set.toList();
  }

  Map<String, int> get newStatus {
    final Map<String, int> map = <String, int>{};
    for (final Torrent t in torrents) {
      map[t.state] = (map[t.state] ?? 0) + 1;
    }
    return map;
  }

  int get totalDlSpeed =>
      torrents.fold(0, (int a, Torrent t) => a + t.dlSpeed);

  int get totalUpSpeed =>
      torrents.fold(0, (int a, Torrent t) => a + t.upSpeed);

  int get totalSize => torrents.fold(0, (int a, Torrent t) => a + t.size);

  int get totalUploaded => torrents.fold(0, (int a, Torrent t) => a + t.uploaded);

  int get totalDownloaded =>
      torrents.fold(0, (int a, Torrent t) => a + t.downloaded);
}
