import 'package:flutter/material.dart';

import '../app/app_version.dart';
import '../widgets/update_dialog.dart';
import 'app_log.dart';
import 'log_text.dart';
import 'app_update.dart';
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

    final String? abi = await UpdateInstaller.deviceAbi();
    final UpdateCheckResult r =
        await UpdateChecker(fetcher: fetcher, deviceAbi: abi).check();

    if (r.hasUpdate) {
      AppLog.instance.net(LogT.startupFound(
          r.latest, kAppVersion, r.apk?.name ?? '-'));
      pendingNotifier.value = r;
    } else if (r.status == UpdateCheckStatus.failed) {
      AppLog.instance.net(
          LogT.startupCheckFailed(r.reason), level: 'WARN');
    } else if (r.reason != null) {
      AppLog.instance.net(
          LogT.startupRemote(r.latest, r.reason));
    }
    return r;
  }

  static Future<void> showDetails(BuildContext context) async {
    final UpdateCheckResult? r = pendingNotifier.value;
    if (!context.mounted || r == null) return;
    await UpdateDialog.open(context, initial: r);
  }
}
