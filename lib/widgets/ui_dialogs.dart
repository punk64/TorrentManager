import 'package:flutter/material.dart';

import '../app/adaptive.dart';
import '../utils/app_log.dart';
import '../utils/net_error.dart';
import '../utils/strings.dart';
import 'app_toast.dart';
import 'bottom_panel.dart';

class UiDialogs {
  static void showToast(
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    AppLog.instance.ui(_oneLine(message), isError: isError);
    AppToast.show(message, isError: isError, isWarning: isWarning);
  }

  static String _oneLine(String s) {
    final String one = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return one.length <= NetError.maxFallbackLength
        ? one
        : '${one.substring(0, NetError.maxFallbackLength)}\u2026';
  }

  static Future<T?> showCustomBottomSheet<T>({
    required Widget child,
    String? title,
    double? heightFactor,
    BuildContext? context,
  }) =>
      BottomPanel.show<T>(
        child: child,
        title: title,
        heightFactor: heightFactor,
        context: context,
      );

  static Future<void> showTerms(BuildContext context) =>
      _showLegal(context, S.termsTitle, S.termsBody);

  static Future<void> showPrivacy(BuildContext context) =>
      _showLegal(context, S.privacyTitle, S.privacyBody);

  static Future<void> showOpenSource(BuildContext context) =>
      _showLegal(context, S.openSourceTitle, S.openSourceBody);

  static Future<void> _showLegal(
    BuildContext context,
    String title,
    String body,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child:
              Text(body, style: TextStyle(fontSize: af(ctx, 12), height: 1.5)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.ok),
          ),
        ],
      ),
    );
  }

  static Future<DeleteOptions?> showDeleteTorrent(
    BuildContext context, {
    int count = 1,
    bool defaultDeleteFiles = false,
    bool defaultDeleteSub = false,
    bool defaultNoSubDeleteFiles = false,
  }) {
    bool delFiles = defaultDeleteFiles;
    bool delSub = defaultDeleteSub;
    bool noSubDel = defaultNoSubDeleteFiles;

    return showDialog<DeleteOptions>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setState) => AlertDialog(
          title: Text('${S.delete}（${S.torrentCount(count)}）'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (delFiles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    S.deleteFilesWarn(count),
                    style: TextStyle(
                      fontSize: af(ctx, 11),
                      height: 1.35,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              CheckboxListTile(
                value: delFiles,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.red,
                title: Text(
                  S.setDelTorrentWithFiles,
                  style: TextStyle(
                    fontSize: af(ctx, 12),
                    color: delFiles ? Colors.red : null,
                    fontWeight: delFiles ? FontWeight.w600 : null,
                  ),
                ),
                onChanged: (bool? v) => setState(() => delFiles = v ?? false),
              ),
              CheckboxListTile(
                value: delSub,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(S.setDelTorrentWithSub,
                    style: TextStyle(fontSize: af(ctx, 12))),
                onChanged: (bool? v) => setState(() => delSub = v ?? false),
              ),
              CheckboxListTile(
                value: noSubDel,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(S.setDelTorrentNoSubDelFiles,
                    style: TextStyle(fontSize: af(ctx, 12))),
                onChanged: (bool? v) => setState(() => noSubDel = v ?? false),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(S.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(
                DeleteOptions(
                  deleteFiles: delFiles,
                  deleteSub: delSub,
                  noSubDeleteFiles: noSubDel,
                ),
              ),
              style: delFiles
                  ? TextButton.styleFrom(foregroundColor: Colors.red)
                  : null,
              child: Text(S.confirmExecute),
            ),
          ],
        ),
      ),
    );
  }
}

class DeleteOptions {
  const DeleteOptions({
    this.deleteFiles = false,
    this.deleteSub = false,
    this.noSubDeleteFiles = false,
  });

  final bool deleteFiles;

  final bool deleteSub;

  final bool noSubDeleteFiles;

  @override
  String toString() =>
      'DeleteOptions(files=$deleteFiles, sub=$deleteSub, noSub=$noSubDeleteFiles)';
}
