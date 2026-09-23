import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../data/models/qb_log.dart';
import '../utils/app_log.dart';
import '../utils/file_export.dart';
import '../utils/formatter.dart';
import '../utils/log_export.dart';
import '../utils/strings.dart';



















class LogSelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LogSelectionAppBar({
    super.key,
    required this.count,
    required this.allSelected,
    required this.onClose,
    required this.onToggleAll,
  });

  final int count;
  final bool allSelected;
  final VoidCallback onClose;
  final VoidCallback onToggleAll;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close, size: AppTheme.iconSize),
        tooltip: S.cancel,
        onPressed: onClose,
      ),
      title: Text(S.logSelectedCount(count), style: const TextStyle(fontSize: 15)),
      actions: <Widget>[
        TextButton(
          onPressed: onToggleAll,
          child: Text(
            allSelected ? S.cancel : S.logSelectAll,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}






class LogSelectionBar extends StatelessWidget {
  const LogSelectionBar({
    super.key,
    required this.count,
    required this.onCopy,
    required this.onExportSelected,
    required this.onInvert,
    required this.onExportAll,
    required this.onClear,
    this.exportAllLabel,
  });

  
  static const double barHeight = 56;

  
  static const double listBottomPadding = 76;

  final int count;
  final VoidCallback onCopy;
  final VoidCallback onExportSelected;
  final VoidCallback onInvert;
  final VoidCallback onExportAll;
  final VoidCallback onClear;

  
  
  
  
  
  
  final String? exportAllLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool none = count == 0;
    return Material(
      color: cs.surfaceContainerHigh,
      
      
      
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.cardBorder(cs))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: barHeight,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextButton.icon(
                    onPressed: none ? null : onCopy,
                    icon: const Icon(Icons.content_copy, size: 18),
                    label: Text(
                      S.logCopyCount(count),
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: none ? null : onExportSelected,
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: Text(
                      S.logExportSelected,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '',
                  icon: const Icon(Icons.more_vert, size: AppTheme.iconSize),
                  onSelected: (String v) {
                    switch (v) {
                      case 'invert':
                        onInvert();
                        break;
                      case 'all':
                        onExportAll();
                        break;
                      case 'clear':
                        onClear();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext ctx) =>
                      <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'invert',
                      child: Text(S.logInvert, style: const TextStyle(fontSize: 13)),
                    ),
                    PopupMenuItem<String>(
                      value: 'all',
                      child: Text(exportAllLabel ?? S.logExportAll,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    PopupMenuItem<String>(
                      value: 'clear',
                      child: Text(S.logClear, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}







LogLine appLogLine(LogEntry e, String label, bool masked) => LogLine(
      time: e.formattedTime,
      level: label,
      source: e.source,
      message: masked ? Formatter.maskLogText(e.message) : e.message,
    );


LogLine qbLogLine(QbLog l, String label, bool masked) => LogLine(
      time: Formatter.setDate(l.timestamp),
      level: label,
      message: masked ? Formatter.maskLogText(l.message) : l.message,
    );




Future<void> copyLogLines(List<LogLine> lines) async {
  if (lines.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: LogExport.buildText(lines)));
  Formatter.showToast(LogExport.copiedMessage(lines.length));
}











Future<bool> exportLogLines(
  BuildContext context, {
  required List<LogLine> lines,
  required bool masked,
  String kind = 'app',
}) async {
  if (lines.isEmpty) {
    Formatter.showToast('${S.logExportFailedPrefix}没有可导出的日志', isError: true);
    return false;
  }
  final String? name = await askExportFileName(
    context,
    LogExport.suggestedFileName(DateTime.now(), kind: kind),
  );
  if (name == null || name.trim().isEmpty) {
    Formatter.showToast(S.logExportCancelled);
    return false;
  }
  try {
    final String path = await FileExport.writeText(
      fileName: name.trim(),
      content: LogExport.buildText(lines),
    );
    final String fileName = path.split(RegExp(r'[/\\]')).last;
    final int n = lines.length;
    if (masked) {
      Formatter.showToast('${S.logExportOk(n)}$fileName');
    } else {
      
      Formatter.showToast(S.logExportPrivacyOff(n), isWarning: true);
    }
    AppLog.instance.op('导出日志：$fileName（$n 条，${masked ? '已打码' : '未打码'}）');
    return true;
  } catch (e) {
    Formatter.showToast(
      '${S.logExportFailedPrefix}${Formatter.safeErr(e)}',
      isError: true,
    );
    return false;
  }
}


Future<String?> askExportFileName(BuildContext context, String suggested) {
  final TextEditingController ctrl =
      TextEditingController(text: suggested);
  return showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('导出日志', style: TextStyle(fontSize: 14)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: AppTheme.maxLenGeneral,
        buildCounter: AppTheme.noCounter,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: S.logExportFileName,
          isDense: true,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(S.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text),
          child: Text(S.ok),
        ),
      ],
    ),
  ).whenComplete(ctrl.dispose);
}
