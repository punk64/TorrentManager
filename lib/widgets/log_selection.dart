import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../data/models/qb_log.dart';
import '../utils/app_log.dart';
import '../utils/file_export.dart';
import '../utils/formatter.dart';
import '../utils/log_export.dart';
import '../utils/strings.dart';
import '../app/adaptive.dart';

class LogSelectionAppBar extends StatelessWidget
    implements PreferredSizeWidget {
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
      title:
          Text(S.logSelectedCount(count), style: TextStyle(fontSize: af(context, 15))),
      actions: <Widget>[
        TextButton(
          onPressed: onToggleAll,
          child: Text(
            allSelected ? S.cancel : S.logSelectAll,
            style: TextStyle(fontSize: af(context, 13)),
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
                      style: TextStyle(fontSize: af(context, 12)),
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
                      style: TextStyle(fontSize: af(context, 12)),
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
                  itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'invert',
                      child: Text(S.logInvert,
                          style: TextStyle(fontSize: af(context, 13))),
                    ),
                    PopupMenuItem<String>(
                      value: 'all',
                      child: Text(exportAllLabel ?? S.logExportAll,
                          style: TextStyle(fontSize: af(context, 13))),
                    ),
                    PopupMenuItem<String>(
                      value: 'clear',
                      child: Text(S.logClear,
                          style: TextStyle(fontSize: af(context, 13))),
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
  final String name0 = name.trim();
  try {

    final String? saved = await FileExport.saveTextAs(
      fileName: name0,
      content: LogExport.buildText(lines),
    );
    if (saved == null || saved.isEmpty) {
      Formatter.showToast(S.logExportCancelled);
      return false;
    }
    final int n = lines.length;
    if (masked) {
      Formatter.showToast('${S.logExportOk(n)}$name0');
    } else {
      Formatter.showToast(S.logExportPrivacyOff(n), isWarning: true);
    }
    AppLog.instance.op('导出日志：$name0（$n 条，${masked ? '已打码' : '未打码'}）');
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
  final TextEditingController ctrl = TextEditingController(text: suggested);
  return showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text('导出日志', style: TextStyle(fontSize: af(context, 14))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: AppTheme.maxLenGeneral,
            buildCounter: AppTheme.noCounter,
            style: TextStyle(fontSize: af(context, 13)),
            decoration: InputDecoration(
              labelText: S.logExportFileName,
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '下一步会弹出系统「另存为」，请选择保存位置（如「下载」文件夹）',
            style: TextStyle(fontSize: af(context, 10), color: Colors.grey.shade600),
          ),
        ],
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
