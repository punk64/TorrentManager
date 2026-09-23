import 'dart:convert';

import '../app/theme.dart';
import 'strings.dart';

class ThemePack {
  ThemePack({
    required this.themes,
    this.version = currentVersion,
    DateTime? exportedAt,
  }) : exportedAt = exportedAt ?? DateTime.now();

  static const String appId = 'TorrentManager';

  static const String formatId = 'torrentmanager-theme-pack';

  static const int currentVersion = 1;

  final List<CustomTheme> themes;
  final int version;
  final DateTime exportedAt;

  int get count => themes.length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'app': appId,
        'format': formatId,
        'version': version,
        'exportedAt': exportedAt.toIso8601String(),
        'count': count,
        'themes': themes.map((CustomTheme t) => t.toJson()).toList(),
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  String suggestedFileName() =>
      'torrentmanager-theme-${_ymd(exportedAt)}.json';

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class ThemePackResult {
  const ThemePackResult._({
    this.pack,
    this.error,
    this.hint,
    this.skipped = const <String>[],
  });

  const ThemePackResult.ok(ThemePack pack, {List<String> skipped = const <String>[]})
      : this._(pack: pack, skipped: skipped);

  const ThemePackResult.fail(String error, {String? hint})
      : this._(error: error, hint: hint);

  final ThemePack? pack;

  final String? error;

  final String? hint;

  final List<String> skipped;

  bool get ok => pack != null;
}

class ThemeImportOutcome {
  const ThemeImportOutcome({
    required this.added,
    required this.replaced,
    this.first,
  });

  final int added;

  final int replaced;

  final CustomTheme? first;

  int get total => added + replaced;
}

class ThemeBackup {
  ThemeBackup._();

  static ThemePackResult parse(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const ThemePackResult.fail(
        '导入失败：文件不是合法的 JSON',
        hint: '文件可能已损坏、被截断，或根本不是 JSON 文本（例如误选了图片）。',
      );
    }
    if (decoded is! Map) {
      return ThemePackResult.fail(
        S.themeImportBadSource,
        hint: S.themeImportBadSourceHint,
      );
    }
    final Map<String, dynamic> j = decoded.cast<String, dynamic>();

    if (j['app'] != ThemePack.appId || j['format'] != ThemePack.formatId) {
      return ThemePackResult.fail(
        S.themeImportBadSource,
        hint: S.themeImportBadSourceHint,
      );
    }

    final Object? v = j['version'];
    final int fileVersion = v is num ? v.toInt() : 0;
    if (fileVersion > ThemePack.currentVersion) {
      return ThemePackResult.fail(
        S.themeImportTooNew(fileVersion, ThemePack.currentVersion),
        hint: S.themeImportTooNewHint,
      );
    }

    final Object? rawThemes = j['themes'];
    if (rawThemes is! List || rawThemes.isEmpty) {
      return ThemePackResult.fail(
        S.themeImportEmpty,
        hint: S.themeImportEmptyHint,
      );
    }

    final List<CustomTheme> ok = <CustomTheme>[];
    final List<String> skipped = <String>[];
    for (int i = 0; i < rawThemes.length; i++) {
      final Object? e = rawThemes[i];
      if (e is! Map) {
        skipped.add(S.themeImportItemSkipped(i + 1, '不是对象'));
        continue;
      }
      final Map<String, dynamic> m = e.cast<String, dynamic>();
      final CustomTheme? t = CustomTheme.fromJson(m);
      if (t == null) {
        skipped.add(S.themeImportItemSkipped(i + 1, _missing(m)));
        continue;
      }
      ok.add(t);
    }

    if (ok.isEmpty) {
      return ThemePackResult.fail(
        S.themeImportAllBad(rawThemes.length),
        hint: S.themeImportAllBadHint,
      );
    }

    final Object? exported = j['exportedAt'];
    return ThemePackResult.ok(
      ThemePack(
        themes: ok,
        version: fileVersion <= 0 ? ThemePack.currentVersion : fileVersion,
        exportedAt:
            exported is String ? (DateTime.tryParse(exported) ?? DateTime.now()) : DateTime.now(),
      ),
      skipped: skipped,
    );
  }

  static String _missing(Map<String, dynamic> m) {
    final List<String> miss = <String>[
      if (m['id'] is! String) 'id',
      if (m['name'] is! String) 'name',
      if (m['seed'] is! int) 'seed',
    ];
    return miss.isEmpty ? '字段类型不符' : '缺 ${miss.join('、')}';
  }
}
