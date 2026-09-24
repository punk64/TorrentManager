import 'package:flutter/material.dart';

import '../app/app_version.dart';
import '../widgets/update_dialog.dart';
import 'app_log.dart';
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

    // ★ 严格口径：拿本机 ABI 去匹配 Release 里的安装包，对不上就不算"有更新"。
    final String? abi = await UpdateInstaller.deviceAbi();
    final UpdateCheckResult r =
        await UpdateChecker(fetcher: fetcher, deviceAbi: abi).check();

    if (r.hasUpdate) {
      AppLog.instance.net('启动检查更新：发现新版本 V${r.latest}'
          '（本地 V$kAppVersion，安装包 ${r.apk?.name ?? '-'}）');
      pendingNotifier.value = r;
    } else if (r.status == UpdateCheckStatus.failed) {
      AppLog.instance.net('启动检查更新失败（按已是最新处理）：${r.reason}',
          level: 'WARN');
    } else if (r.reason != null) {
      AppLog.instance.net('启动检查更新：远端 V${r.latest} —— ${r.reason}');
    }
    return r;
  }

  /// 展示启动检查挂起的那个更新提醒。
  ///
  /// 没有挂起结果（已是最新 / 检查失败 / 还没跑过）就什么都不做 ——
  /// 「手动检查更新」请走 [UpdateDialog.open]，它会自己发一次请求。
  static Future<void> showDetails(BuildContext context) async {
    final UpdateCheckResult? r = pendingNotifier.value;
    if (!context.mounted || r == null) return;
    await UpdateDialog.open(context, initial: r);
  }
}
