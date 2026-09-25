class QbIpFilter {
  const QbIpFilter({
    required this.enabled,
    required this.filterTrackers,
    required this.bannedIps,
  });

  static const QbIpFilter empty = QbIpFilter(
    enabled: false,
    filterTrackers: false,
    bannedIps: '',
  );

  static const String keyEnabled = 'ip_filter_enabled';
  static const String keyTrackers = 'ip_filter_trackers';
  static const String keyBanned = 'banned_IPs';

  static const int maxEntries = 5000;

  final bool enabled;
  final bool filterTrackers;

  final String bannedIps;

  factory QbIpFilter.fromPrefs(Map<String, dynamic> prefs) => QbIpFilter(
        enabled: asBool(prefs[keyEnabled]),
        filterTrackers: asBool(prefs[keyTrackers]),
        bannedIps: prefs[keyBanned]?.toString() ?? '',
      );

  List<String> get entries => splitEntries(bannedIps);

  int get count => entries.length;

  Map<String, dynamic> diffFrom(QbIpFilter old) {
    final Map<String, dynamic> out = <String, dynamic>{};
    if (enabled != old.enabled) out[keyEnabled] = enabled;
    if (filterTrackers != old.filterTrackers) out[keyTrackers] = filterTrackers;
    if (bannedIps != old.bannedIps) out[keyBanned] = bannedIps;
    return out;
  }

  QbIpFilter copyWith({
    bool? enabled,
    bool? filterTrackers,
    String? bannedIps,
  }) =>
      QbIpFilter(
        enabled: enabled ?? this.enabled,
        filterTrackers: filterTrackers ?? this.filterTrackers,
        bannedIps: bannedIps ?? this.bannedIps,
      );

  String diffSummary(QbIpFilter old) {
    final List<String> a = entries;
    final List<String> b = old.entries;
    final List<String> added =
        a.where((String e) => !b.contains(e)).toList(growable: false);
    final List<String> removed =
        b.where((String e) => !a.contains(e)).toList(growable: false);
    return '${a.length} 条（+${added.length} / -${removed.length}）';
  }

  static bool asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.toLowerCase() == 'true';
    return false;
  }

  static List<String> splitEntries(String raw) => raw
      .split(RegExp(r'[\r\n]+'))
      .map((String e) => e.trim())
      .where((String e) => e.isNotEmpty)
      .toList(growable: false);

  static String joinEntries(Iterable<String> entries) => entries
      .map((String e) => e.trim())
      .where((String e) => e.isNotEmpty)
      .join('\n');

  static List<String> addEntry(Iterable<String> entries, String value) {
    final String v = value.trim();
    final List<String> out = List<String>.of(entries);
    if (v.isEmpty || out.contains(v)) return out;
    out.add(v);
    return out;
  }

  static List<String> replaceEntry(
    List<String> entries,
    int index,
    String value,
  ) {
    final String v = value.trim();
    if (index < 0 || index >= entries.length || v.isEmpty) return entries;
    final List<String> out = List<String>.of(entries);
    out[index] = v;
    return out;
  }

  static List<String> removeEntry(List<String> entries, int index) {
    if (index < 0 || index >= entries.length) return entries;
    final List<String> out = List<String>.of(entries);
    out.removeAt(index);
    return out;
  }

  static bool isValidEntry(String raw) {
    final String s = raw.trim();
    if (s.isEmpty) return false;
    final List<String> parts = s.split('/');
    if (parts.length > 2) return false;
    final String addr = parts[0];
    final int? prefix = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (parts.length == 2 && prefix == null) return false;

    final bool v6 = addr.contains(':');
    if (v6) {
      if (prefix != null && (prefix < 0 || prefix > 128)) return false;
      final bool ok = RegExp(r'^[0-9a-fA-F:]+$').hasMatch(addr) &&
          addr.split(':').length >= 3;
      return ok;
    }
    final List<String> octets = addr.split('.');
    if (octets.length != 4) return false;
    for (final String o in octets) {
      final int? n = int.tryParse(o);
      if (n == null || n < 0 || n > 255) return false;
      if (o.length > 1 && o.startsWith('0')) return false;
    }
    if (prefix != null && (prefix < 0 || prefix > 32)) return false;
    return true;
  }
}
