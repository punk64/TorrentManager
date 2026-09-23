import 'strings.dart';

class LogLine {
  const LogLine({
    required this.time,
    required this.level,
    required this.message,
    this.source = '',
  });

  final String time;

  final String level;

  final String message;

  final String source;

  String toLine() {
    final List<String> parts = <String>[
      if (time.isNotEmpty) time,
      if (level.isNotEmpty) level,
      if (source.isNotEmpty) source,
      if (message.isNotEmpty) message,
    ];
    return parts.join(' ');
  }
}

class LogExport {
  LogExport._();

  static String buildText(List<LogLine> lines) {
    if (lines.isEmpty) return '';
    final StringBuffer sb = StringBuffer();
    for (final LogLine l in lines) {
      sb.writeln(l.toLine());
    }
    return sb.toString();
  }

  static String suggestedFileName(DateTime now, {String kind = 'app'}) {
    final String ymd = '${now.year}-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
    final String suffix = kind == 'qb' ? '-qb' : '';
    return 'torrentmanager-log$suffix-$ymd.txt';
  }

  static String copyLabel(int n) => S.logCopyCount(n);

  static String copiedMessage(int n) => S.logCopied(n);
}
