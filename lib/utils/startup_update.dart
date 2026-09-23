import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_version.dart';
import 'app_log.dart';
import 'formatter.dart';
import 'strings.dart';
import 'update_check.dart';

class StartupUpdatePrompt {
  StartupUpdatePrompt._();

  static bool _done = false;

  static final ValueNotifier<UpdateCheckResult?> pendingNotifier =
      ValueNotifier<UpdateCheckResult?>(null);

  static UpdateCheckResult? get pending => pendingNotifier.value;

  static bool get done => _done;

  static void resetForTest() {
    _done = false;
    pendingNotifier.value = null;
  }

  static Future<UpdateCheckResult?> runOnce({UpdateFetcher? fetcher}) async {
    if (_done) return pendingNotifier.value;
    _done = true;

    final UpdateCheckResult r = await UpdateChecker(fetcher: fetcher).check();
    if (r.hasUpdate) {
      AppLog.instance
          .net('启动检查更新：发现新版本 V${r.latest}（本地 V$kAppVersion）');
      pendingNotifier.value = r;
    } else if (r.status == UpdateCheckStatus.failed) {
      AppLog.instance.net('启动检查更新失败（按已是最新处理）：${r.reason}',
          level: 'WARN');
    }
    return r;
  }

  static Future<void> showDetails(BuildContext context) async {
    final UpdateCheckResult? r = pendingNotifier.value;
    final String? latest = r?.latest;
    if (!context.mounted || latest == null || latest.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(S.hasUpdate),
        content: SingleChildScrollView(
          child: Text(S.startupUpdateBody(latest),
              style: const TextStyle(fontSize: 12, height: 1.5)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: kReleasesUrl));
              if (ctx.mounted) {
                Formatter.showToast(S.copyUrlHint);
              }
            },
            child: Text(S.copyReleaseLink),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.ok),
          ),
        ],
      ),
    );
  }
}
