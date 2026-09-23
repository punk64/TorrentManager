import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../controllers/torrent_controller.dart';
import '../data/models/torrent.dart';
import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';
import '../widgets/speed_sparkline.dart';

class TorrentInfoOverviewPage extends StatefulWidget {
  const TorrentInfoOverviewPage({super.key});

  @override
  State<TorrentInfoOverviewPage> createState() =>
      _TorrentInfoOverviewPageState();
}

class _TorrentInfoOverviewPageState extends State<TorrentInfoOverviewPage> {
  TorrentController get _ctrl => Get.find<TorrentController>();
  ServerController get _serverCtrl => Get.find<ServerController>();

  bool _busy = false;

  static const Color _dlBlue = Color(0xFF1A73E8);
  static const Color _ulGreen = Color(0xFF0F9D58);

  static const String _kChecking = '校验中';

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final Torrent? t = _ctrl.current.value;
      if (t == null) {
        return Center(
          child:
              Text(S.pleaseSelectTorrent, style: const TextStyle(fontSize: 12)),
        );
      }
      final ColorScheme cs = Theme.of(context).colorScheme;

      final String site = t.site;
      final bool checking = t.isChecking;
      final bool running = !t.isPause;

      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: <Widget>[

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: SelectableText(
                  t.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: AppTheme.iconSize),
                tooltip: S.nameCopied,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: t.name));
                  Formatter.showToast(S.nameCopied);
                },
              ),
            ],
          ),

          const SizedBox(height: 6),
          _liveHeader(t, cs, checking: checking),

          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text('最近 3 分钟',
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              const Spacer(),
              _legend('下载', SpeedSparkline.kDlColor),
              const SizedBox(width: 10),
              _legend('上传', SpeedSparkline.kUlColor),
            ],
          ),
          const SizedBox(height: 4),
          SpeedSparkline(
            dl: List<double>.of(_ctrl.dlSamples),
            ul: List<double>.of(_ctrl.ulSamples),
          ),

          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: t.progress.clamp(0, 1),
            minHeight: 6,
            borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
          ),
          const SizedBox(height: 4),
          Text(
            checking
                ? '$_kChecking ${Formatter.setProgress(t.progress)}'
                : '${S.fieldProgress} ${Formatter.setProgress(t.progress)}'
                    ' · ${Formatter.setSize(t.newRelativeSize)}'
                    ' / ${Formatter.setSize(t.newSize)}',
            style: TextStyle(
              fontSize: 10,
              color: checking
                  ? Formatter.setStatusColor(t.state, cs)
                  : cs.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _statChip('连接', t.activePeers < 0 ? '-' : '${t.activePeers}',
                  cs),
              const SizedBox(width: 8),
              _statChip('做种', '${t.numComplete}', cs),
              const SizedBox(width: 8),
              _statChip('下载', '${t.numIncomplete}', cs),
              const Spacer(),
              Text(
                Formatter.getSeederCount(
                  t.numComplete,
                  t.numIncomplete,
                  t.transferPeers,
                ),
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ],
          ),

          const Divider(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow, size: AppTheme.iconSize),
                label: const Text('继续', style: TextStyle(fontSize: 11)),

                onPressed: (!running && !checking && !_busy)
                    ? () {
                        AppLog.instance.act('种子详情', '按钮[继续]', target: t.name);
                        _run(t, _ctrl.resumeSelected, '已继续');
                      }
                    : null,
              ),
              FilledButton.icon(
                icon: const Icon(Icons.pause, size: AppTheme.iconSize),
                label: const Text('暂停', style: TextStyle(fontSize: 11)),
                onPressed: (running && !checking && !_busy)
                    ? () {
                        AppLog.instance.act('种子详情', '按钮[暂停]', target: t.name);
                        _run(t, _ctrl.pauseSelected, '已暂停');
                      }
                    : null,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.fact_check_outlined,
                    size: AppTheme.iconSize),
                label: Text(checking ? '$_kChecking…' : '重新校验',
                    style: const TextStyle(fontSize: 11)),
                onPressed: (!checking && !_busy) ? () => _recheck(t) : null,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.public, size: AppTheme.iconSize),
                label: const Text('重新汇报', style: TextStyle(fontSize: 11)),
                onPressed: _busy ? null : () => _reannounce(t),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete, size: AppTheme.iconSize),
                label: Text(S.delete, style: const TextStyle(fontSize: 11)),
                onPressed: _busy ? null : () => _delete(t),
              ),
            ],
          ),

          const Divider(height: 18),

          _kv(S.fieldState, Formatter.setStatus(t.newState)),

          _kv('校验进度',
              checking ? Formatter.setProgress(t.progress) : '—'),
          _kv(S.fieldSize, Formatter.setSize(t.newSize)),
          _kv(S.fieldRatio, Formatter.setRatio(t.ratio)),
          _kv(
            S.fieldSeeders,

            Formatter.getSeederCount(
              t.numComplete,
              t.numIncomplete,
              t.transferPeers,
            ),
          ),
          _kv(S.fieldEta, Formatter.setEta(t.newEta)),
          _kv(S.fieldDlSpeed, Formatter.setSpeed(t.newDownSpeed)),
          _kv(S.fieldUpSpeed, Formatter.setSpeed(t.newUpspeed)),
          _kv(S.fieldDownloaded, Formatter.setSize(t.downloaded)),
          _kv(S.fieldUploaded, Formatter.setSize(t.newUploaded)),
          _kv(
            S.fieldDlLimit,
            t.newDlLimit <= 0 ? '不限速' : Formatter.setSpeed(t.newDlLimit),
          ),
          _kv(
            S.fieldUpLimit,
            t.newUpLimit <= 0 ? '不限速' : Formatter.setSpeed(t.newUpLimit),
          ),

          const Divider(height: 18),

          _kv(S.fieldAddedOn, Formatter.setDate(t.newAddedOn)),
          _kv(S.fieldCompletionOn, Formatter.setDate(t.newCompletionOn)),
          _kv(S.fieldActiveTime, Formatter.setTime(t.newTimeActive)),
          _kv('做种时长', Formatter.setTime(t.newSeedingTime)),

          _kv('最近活动', Formatter.setLastActivity(t.newLastActivity)),
          _kv('Tracker 数量', '${t.newTrackerCount}'),

          const Divider(height: 18),

          if (t.savePath != null) _kv(S.fieldPath, t.savePath!),
          if (t.category != null && t.category!.isNotEmpty)
            _kv(S.fieldCategory, t.category!),
          if (t.tags != null && t.tags!.isNotEmpty) _kv(S.fieldTags, t.tags!),
          if (site.isNotEmpty) _kv(S.fieldSiteName, site),
          _kv('哈希', t.hash),
          if (t.contentPath != null) _kv('内容路径', t.contentPath!),
        ],
      );
    });
  }

  Widget _liveHeader(Torrent t, ColorScheme cs, {required bool checking}) {
    final Color st = Formatter.setStatusColor(t.state, cs);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: st.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: st.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: st, shape: BoxShape.circle),
            child: Icon(
              Formatter.statusIcon(t.state),
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  checking ? _kChecking : Formatter.setStatus(t.state),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: st,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _syncHint(),
                  style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '▼ ${Formatter.setSpeed(t.newDownSpeed)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _dlBlue,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '▲ ${Formatter.setSpeed(t.newUpspeed)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _ulGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _syncHint() {
    final DateTime? at = _ctrl.detailSyncedAt.value;
    if (at == null) return '正在获取…';
    final int sec = DateTime.now().difference(at).inSeconds;
    if (sec <= 1) return '刚刚更新 · 每 3 秒自动刷新';
    return '$sec 秒前更新 · 每 3 秒自动刷新';
  }

  Widget _legend(String label, Color c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 2,
            color: c,
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 9, color: c)),
        ],
      );

  Widget _statChip(String label, String value, ColorScheme cs) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label,
                style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
            const SizedBox(width: 5),
            Text(value,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(k, style: const TextStyle(fontSize: 11)),
          ),
          Expanded(
            child: SelectableText(v, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Future<void> _run(
    Torrent t,
    Future<void> Function() action,
    String done,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    _ctrl
      ..clearSelection()
      ..toggleSelect(t.hash);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (_ctrl.lastActionOk.value == true) {
      Formatter.showToast('$done ${t.name}');
    } else {
      Formatter.showToast(
        '${S.execFailed}: ${_ctrl.error.value ?? ''}',
        isError: true,
      );
    }
  }

  Future<void> _recheck(Torrent t) async {
    if (_busy) return;
    AppLog.instance.act('种子详情', '按钮[重新校验]', target: t.name);
    setState(() => _busy = true);
    final s = _serverCtrl.current.value;
    final String? err = await _write(() async {
      if (s == null) return S.noServer;
      if (s.isQbittorrent) {
        await _serverCtrl.qb.recheckTorrents(t.hash);
        return null;
      }
      if (t.trId == null) return S.noTrId;
      await _serverCtrl.tr.torrentVerify(<int>[t.trId!]);
      return null;
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      Formatter.showToast('已开始校验 ${t.name}（进度见下方）');
    } else {
      Formatter.showToast('${S.execFailed}: $err', isError: true);
    }
  }

  Future<void> _reannounce(Torrent t) async {
    if (_busy) return;
    AppLog.instance.act('种子详情', '按钮[重新汇报]', target: t.name);
    setState(() => _busy = true);
    final s = _serverCtrl.current.value;
    final String? err = await _write(() async {
      if (s == null) return S.noServer;
      if (s.isQbittorrent) {
        await _serverCtrl.qb.reannounceTorrent(t.hash);
        return null;
      }
      if (t.trId == null) return S.noTrId;
      await _serverCtrl.tr.reannounceTorrent(<int>[t.trId!]);
      return null;
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      Formatter.showToast('${S.tReannounceOk}${t.name}');
    } else {
      Formatter.showToast('${S.execFailed}: $err', isError: true);
    }
  }

  Future<void> _delete(Torrent t) async {
    final DeleteOptions? opt = await Formatter.showDeleteTorrent(
      context,
      count: 1,
      defaultDeleteFiles: false,
      defaultDeleteSub: false,
      defaultNoSubDeleteFiles: false,
    );
    if (opt == null) {
      AppLog.instance.act('种子详情', '按钮[删除]·取消', target: t.name);
      return;
    }
    AppLog.instance.act('种子详情', '按钮[删除]',
        target: '${t.name}（含文件 ${opt.deleteFiles ? '是' : '否'}）');
    _ctrl
      ..clearSelection()
      ..toggleSelect(t.hash);

    await _ctrl.deleteSelected(
      deleteFiles: opt.deleteFiles,
      deleteSub: opt.deleteSub,
      noSubDeleteFiles: opt.noSubDeleteFiles,
    );
    if (_ctrl.lastActionOk.value == false) {
      if (mounted) {
        Formatter.showToast(
          '${S.execFailed}: ${_ctrl.error.value ?? ''}',
          isError: true,
        );
      }
      return;
    }
    Get.back<void>();
  }

  Future<String?> _write(Future<String?> Function() body) async {
    try {
      return await body();
    } catch (e) {
      return Formatter.safeErr(e);
    }
  }
}
