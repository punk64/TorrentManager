import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../controllers/torrent_controller.dart';
import '../data/models/torrent.dart';
import '../data/server_capabilities.dart';
import '../utils/app_log.dart';
import '../utils/file_export.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';
import '../widgets/speed_sparkline.dart';
import '../widgets/torrent_edit_fields.dart';
import '../app/adaptive.dart';

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

  final EditDraft _draft = EditDraft();

  void _markDirty(String key, bool dirty) {
    if (dirty) {
      _draft.write(key, true);
    } else {
      _draft.drop(key);
    }
    if (mounted) setState(() {});
  }

  int get _badTrackerCount {
    int n = 0;
    for (final Map<String, dynamic> m in _ctrl.trackers) {
      final int st = (m['status'] as num?)?.toInt() ?? -1;

      final bool bad = st == 4 || m['lastAnnounceSucceeded'] == false;
      if (bad) n++;
    }
    return n;
  }

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
              Text(S.pleaseSelectTorrent, style: TextStyle(fontSize: af(context, 12))),
        );
      }
      final ColorScheme cs = Theme.of(context).colorScheme;

      final String site = t.site;
      final bool checking = t.isChecking;
      final bool running = !t.isPause;
      final CapabilitySet cap = _ctrl.capabilities;

      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: <Widget>[

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: SelectableText(
                  t.name,
                  style: TextStyle(
                    fontSize: af(context, 13),
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

          EditSectionCard(
            title: S.editSectionStats,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _liveHeader(t, cs, checking: checking),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Text('最近 3 分钟',
                        style:
                            TextStyle(fontSize: af(context, 10), color: cs.onSurfaceVariant)),
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
                    fontSize: af(context, 10),
                    color: checking
                        ? Formatter.setStatusColor(t.state, cs)
                        : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _statChip(
                        '连接', t.activePeers < 0 ? '-' : '${t.activePeers}', cs),
                    const SizedBox(width: 8),
                    _statChip('做种', '${t.numComplete}', cs),
                    const SizedBox(width: 8),
                    _statChip('下载', '${t.numIncomplete}', cs),

                    if (_ctrl.capabilities.isQb && t.availability > 0) ...<Widget>[
                      const SizedBox(width: 8),
                      _statChip(
                        S.fieldHealth,
                        '${(t.availability * 100).toStringAsFixed(0)}%',
                        cs,
                      ),
                    ],
                    const Spacer(),
                    Text(
                      Formatter.getSeederCount(
                        t.numComplete,
                        t.numIncomplete,
                        t.transferPeers,
                      ),
                      style:
                          TextStyle(fontSize: af(context, 10), color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),

          EditSectionCard(
            title: S.editSectionActions,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _actionGrid(t, running: running, checking: checking),
                if (cap.forceStart ||
                    cap.sequentialDownload ||
                    cap.isQb ||
                    cap.superSeeding) ...<Widget>[
                  const SizedBox(height: 8),
                  _switchGroup(t),
                ],
              ],
            ),
          ),

          EditSectionCard(
            title: S.editSectionInfo,
            child: ReadonlyKvGrid(pairs: <List<String>>[
              <String>[S.fieldState, Formatter.setStatus(t.newState)],
              <String>[
                '校验进度',
                checking ? Formatter.setProgress(t.progress) : '—',
              ],
              <String>[S.fieldSize, Formatter.setSize(t.newSize)],
              <String>[S.fieldRatio, Formatter.setRatio(t.ratio)],
              <String>[
                S.fieldSeeders,
                Formatter.getSeederCount(
                  t.numComplete,
                  t.numIncomplete,
                  t.transferPeers,
                ),
              ],
              <String>[S.fieldEta, Formatter.setEta(t.newEta)],
              <String>[S.fieldDlSpeed, Formatter.setSpeed(t.newDownSpeed)],
              <String>[S.fieldUpSpeed, Formatter.setSpeed(t.newUpspeed)],
              <String>[S.fieldDownloaded, Formatter.setSize(t.downloaded)],
              <String>[S.fieldUploaded, Formatter.setSize(t.newUploaded)],

              <String>[
                S.fieldRemaining,
                t.amountLeft > 0 ? Formatter.setSize(t.amountLeft) : '—',
              ],

              <String>[
                S.fieldWastedShort,
                t.wasted > 0 ? Formatter.setSize(t.wasted) : '—',
              ],
            ]),
          ),

          EditSectionCard(
            title: S.editSectionLimits,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _dlLimitField(t),
                _upLimitField(t),
                _ratioLimitField(t),
                _seedTimeField(t),
              ],
            ),
          ),

          EditSectionCard(
            title: S.editSectionTimes,
            child: ReadonlyKvGrid(pairs: <List<String>>[
              <String>[S.fieldAddedOn, Formatter.setDate(t.newAddedOn)],
              <String>[
                S.fieldCompletionOn,
                Formatter.setDate(t.newCompletionOn)
              ],
              <String>[S.fieldActiveTime, Formatter.setTime(t.newTimeActive)],
              <String>['做种时长', Formatter.setTime(t.newSeedingTime)],
              <String>['最近活动', Formatter.setLastActivity(t.newLastActivity)],

              <String>[
                S.fieldTrackerShort,
                _badTrackerCount > 0
                    ? S.trackerFailed(_badTrackerCount)
                    : '${S.trackerAllOk}（${t.newTrackerCount}）',
              ],

              if (!cap.isQb)
                <String>[
                  S.fieldDiskFree,
                  t.freeSpace > 0 ? Formatter.setSize(t.freeSpace) : '—',
                ],

              if (cap.privateFlag)
                <String>[
                  S.fieldPrivate,
                  t.isPrivate == null ? '—' : (t.isPrivate! ? S.yes : S.no),
                ],
            ]),
          ),

          const Divider(height: 18),

          EditSectionCard(
            title: S.editSectionBasic,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[

                if (t.savePath != null)
                  EditActionRow(
                    label: S.fieldPath,
                    value: t.savePath!,
                    onTap: _busy ? null : () => _editPath(t),
                  ),
                if (t.contentPath != null) _kv('内容路径', t.contentPath!),

                if (cap.category)
                  EditActionRow(
                    label: S.fieldCategory,
                    value: t.categoryName,
                    onTap: _busy ? null : () => _editCategory(t),
                  ),

                EditActionRow(
                  label: S.fieldTags,
                  value: t.tags == null || t.tags!.isEmpty
                      ? S.editCategoryNone
                      : t.tags!,
                  onTap: _busy ? null : () => _editTags(t),
                ),
              ],
            ),
          ),

          EditSectionCard(
            title: S.editSectionLinks,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (site.isNotEmpty)
                  _kvCopy(S.fieldSiteName, site, maxLines: 2),
                _kvCopy(S.fieldHash, t.hash, maxLines: 2),
                if ((t.magnetUri ?? '').isNotEmpty)
                  _kvCopy(S.fieldMagnet, t.magnetUri!, mask: true, maxLines: 3),
                if ((t.comment ?? '').isNotEmpty)
                  _kvCopy(S.fieldComment, t.comment!, maxLines: 3),
              ],
            ),
          ),

          if (_ctrl.capabilities.exportTorrent) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.download, size: AppTheme.iconSize),
                label:
                    Text(S.btExportTorrent, style: TextStyle(fontSize: af(context, 11))),
                onPressed: _busy ? null : () => _exportTorrent(t),
              ),
            ),
          ],

          if (t.isError) ...<Widget>[
            const SizedBox(height: 10),
            _errorBanner(t, cs),
          ],

          if (_metaIncomplete(t)) ...<Widget>[
            const SizedBox(height: 10),
            _metadataBar(t),
          ],

          if (_draft.isNotEmpty) ...<Widget>[
            const Divider(height: 18),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                S.editUnsavedHint,
                style: TextStyle(fontSize: af(context, 10), color: Colors.deepOrange),
              ),
            ),
          ],
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
                    fontSize: af(context, 14),
                    fontWeight: FontWeight.w700,
                    color: st,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _syncHint(),
                  style: TextStyle(fontSize: af(context, 9), color: cs.onSurfaceVariant),
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
                style: TextStyle(
                  fontSize: af(context, 11),
                  fontWeight: FontWeight.w600,
                  color: _dlBlue,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '▲ ${Formatter.setSpeed(t.newUpspeed)}',
                style: TextStyle(
                  fontSize: af(context, 11),
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
          Text(label, style: TextStyle(fontSize: af(context, 9), color: c)),
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
                style: TextStyle(fontSize: af(context, 9), color: cs.onSurfaceVariant)),
            const SizedBox(width: 5),
            Text(value,
                style: TextStyle(
                    fontSize: af(context, 10), fontWeight: FontWeight.w600)),
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
            child: Text(k, style: TextStyle(fontSize: af(context, 11))),
          ),
          Expanded(
            child: SelectableText(v, style: TextStyle(fontSize: af(context, 11))),
          ),
        ],
      ),
    );
  }

  Widget _kvCopy(String k, String v, {bool mask = false, int? maxLines}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(k, style: TextStyle(fontSize: af(context, 11))),
          ),
          Expanded(
            child: SelectableText(
              v,
              maxLines: maxLines,
              style: TextStyle(fontSize: af(context, 11)),
            ),
          ),
          SizedBox(
            height: 28,
            width: 28,
            child: IconButton(
              icon: const Icon(Icons.copy, size: 14),
              tooltip: S.nameCopied,
              onPressed: () async {

                final String text = mask ? Formatter.maskUrl(v) : v;
                await Clipboard.setData(ClipboardData(text: text));
                Formatter.showToast(S.nameCopied);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(Torrent t, ColorScheme cs) {
    final String reason = (t.errorMessage ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: cs.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: 16, color: cs.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              reason.isEmpty ? '${S.fieldErrorReason}：${t.state}' : reason,
              style: TextStyle(fontSize: af(context, 11), color: cs.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metadataBar(Torrent t) {
    final double p = t.metadataPercent;
    final bool known = p >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LinearProgressIndicator(
          value: known ? p.clamp(0, 1) : null,
          minHeight: 4,
          borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
        ),
        const SizedBox(height: 3),
        Text(
          known
              ? '${S.fieldMetadata} ${(p * 100).toStringAsFixed(0)}%'
              : S.fieldMetadata,
          style: TextStyle(fontSize: af(context, 10)),
        ),
      ],
    );
  }

  bool _metaIncomplete(Torrent t) =>
      !t.isCompleted &&
      t.metadataPercent >= 0 &&
      t.metadataPercent < 1 &&
      (t.magnetUri ?? '').isNotEmpty;

  Widget _actionGrid(
    Torrent t, {
    required bool running,
    required bool checking,
  }) {
    final Color danger = Theme.of(context).colorScheme.error;
    Widget gap() => const SizedBox(width: 6);

    Widget primary({
      required IconData icon,
      required String label,
      required VoidCallback? onTap,
    }) =>
        Expanded(
          child: FilledButton.icon(
            icon: Icon(icon, size: AppTheme.iconSize),
            label: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: af(context, 11))),
            onPressed: onTap,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        );

    Widget secondary({
      required IconData icon,
      required String label,
      required VoidCallback? onTap,
      Color? color,
    }) =>
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(icon, size: AppTheme.iconSize, color: color),
            label: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: af(context, 11), color: color)),
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              side: color == null
                  ? null
                  : BorderSide(color: color.withValues(alpha: 0.55)),
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            primary(
              icon: Icons.play_arrow,
              label: '继续',
              onTap: (!running && !checking && !_busy)
                  ? () {
                      AppLog.instance
                          .act('种子详情', '按钮[继续]', target: t.name);
                      _run(t, _ctrl.resumeSelected, '已继续');
                    }
                  : null,
            ),
            gap(),
            primary(
              icon: Icons.pause,
              label: '暂停',
              onTap: (running && !checking && !_busy)
                  ? () {
                      AppLog.instance
                          .act('种子详情', '按钮[暂停]', target: t.name);
                      _run(t, _ctrl.pauseSelected, '已暂停');
                    }
                  : null,
            ),
            gap(),
            secondary(
              icon: Icons.fact_check_outlined,
              label: checking ? '$_kChecking…' : '重新校验',
              onTap: (!checking && !_busy) ? () => _recheck(t) : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            secondary(
              icon: Icons.public,
              label: '重新汇报',
              onTap: _busy ? null : () => _reannounce(t),
            ),
            gap(),
            secondary(
              icon: Icons.drive_file_rename_outline,
              label: S.renameTorrent,
              onTap: _busy ? null : () => _rename(t),
            ),
            gap(),
            secondary(
              icon: Icons.delete,
              label: S.delete,
              color: danger,
              onTap: _busy ? null : () => _delete(t),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dlLimitField(Torrent t, {bool compact = false}) => EditNumberField(
        label: S.fieldDlLimit,
        initial: t.newDlLimit ~/ 1024,
        unit: 'KB/s',
        compact: compact,
        zeroMeansUnlimited: true,
        onDirtyChanged: (bool d) => _markDirty(TorrentEditFields.kDlLimit, d),
        onSave: (int v) => _apply(
          t,
          S.fieldDlLimit,
          () => _ctrl.setLimitsOf(<String>[t.hash], dlKb: v),
        ),
      );

  Widget _upLimitField(Torrent t, {bool compact = false}) => EditNumberField(
        label: S.fieldUpLimit,
        initial: t.newUpLimit ~/ 1024,
        unit: 'KB/s',
        compact: compact,
        zeroMeansUnlimited: true,
        onDirtyChanged: (bool d) => _markDirty(TorrentEditFields.kUpLimit, d),
        onSave: (int v) => _apply(
          t,
          S.fieldUpLimit,
          () => _ctrl.setLimitsOf(<String>[t.hash], upKb: v),
        ),
      );

  Widget _ratioLimitField(Torrent t, {bool compact = false}) => EditRatioField(
        label: S.fieldRatioLimit,
        initial: t.ratioLimit,
        compact: compact,
        onDirtyChanged: (bool d) =>
            _markDirty(TorrentEditFields.kRatioLimit, d),
        onSave: (double v) => _apply(
          t,
          S.fieldRatioLimit,
          () => _ctrl.setShareLimitsOf(<String>[t.hash], ratioLimit: v),
        ),
      );

  Widget _seedTimeField(Torrent t, {bool compact = false}) => EditNumberField(
        label: S.fieldSeedingTimeLimit,
        initial: t.seedingTimeLimit < 0 ? 0 : t.seedingTimeLimit,
        unit: S.editMinutesUnit,
        compact: compact,
        zeroMeansUnlimited: true,
        onDirtyChanged: (bool d) =>
            _markDirty(TorrentEditFields.kSeedingTime, d),
        onSave: (int v) => _apply(
          t,
          S.fieldSeedingTimeLimit,
          () => _ctrl.setShareLimitsOf(
            <String>[t.hash],
            seedingTimeMin: v <= 0 ? -1 : v,
          ),
        ),
      );

  Future<void> _exportTorrent(Torrent t) async {
    if (_busy) return;
    final ServerController sc = _serverCtrl;
    final s = sc.current.value;
    if (s == null) {
      Formatter.showToast(S.noServer, isError: true);
      return;
    }
    try {
      final List<int> bytes = await sc.qb.exportTorrent(t.hash);
      if (bytes.isEmpty) {
        Formatter.showToast(S.btExportFail, isError: true);
        return;
      }

      final String? saved = await FileExport.saveBytesAs(
        fileName: '${t.name}.torrent',
        bytes: Uint8List.fromList(bytes),
        dialogTitle: S.btExportTorrent,
      );
      if (saved == null) return;
      Formatter.showToast('${S.btExportOk} $saved');
    } catch (e) {
      Formatter.showToast(
        '${S.btExportFailPrefix}${Formatter.safeErr(e)}',
        isError: true,
      );
    }
  }

  Widget _switchGroup(Torrent t) {
    final CapabilitySet cap = _ctrl.capabilities;
    final List<Widget> chips = <Widget>[
      if (cap.forceStart)
        EditSwitchChip(
          label: S.swForceStart,
          value: t.forceStart ?? false,
          onChanged: (bool v) => _apply(
            t,
            S.swForceStart,
            () => _ctrl.setForceStartOf(<String>[t.hash], v),
          ),
        ),
      if (cap.sequentialDownload)
        EditSwitchChip(
          label: S.swSequential,
          value: t.sequentialDownload ?? false,
          onChanged: (bool v) => _apply(
            t,
            S.swSequential,
            () => _ctrl.toggleSequentialOf(<String>[t.hash], target: v),
          ),
        ),
      if (cap.isQb)
        EditSwitchChip(
          label: S.swFirstLast,
          value: t.firstLastPiecePrio ?? false,
          onChanged: (bool v) => _apply(
            t,
            S.swFirstLast,
            () => _ctrl.toggleFirstLastPrioOf(<String>[t.hash], target: v),
          ),
        ),
      if (cap.superSeeding)
        EditSwitchChip(
          label: S.swSuperSeeding,
          value: t.superSeeding ?? false,
          onChanged: (bool v) => _apply(
            t,
            S.swSuperSeeding,
            () => _ctrl.setSuperSeedingOf(<String>[t.hash], v),
          ),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(S.editSectionSwitches,
            style: TextStyle(fontSize: af(context, 11), fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    );
  }

  Future<bool> _apply(
    Torrent t,
    String what,
    Future<void> Function() body,
  ) async {
    if (_busy) return false;
    setState(() => _busy = true);
    AppLog.instance.act('种子详情', '编辑[$what]', target: t.name);
    await body();
    final bool ok = _ctrl.lastActionOk.value != false;
    if (!mounted) return ok;
    setState(() => _busy = false);
    if (!ok) {
      Formatter.showToast(
        '${S.execFailed}: ${_ctrl.error.value ?? ''}',
        isError: true,
      );
    } else {
      Formatter.showToast('$what${S.editSaved}');
      unawaited(_refreshAfter(t));
    }
    return ok;
  }

  Future<void> _refreshAfter(Torrent t) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _ctrl.fetchOne(t);
  }

  Future<void> _editPath(Torrent t) async {
    final bool isQb = _ctrl.capabilities.isQb;
    final PathEditResult? r = await EditDialogs.path(
      context,
      initial: t.savePath ?? '',

      askMove: !isQb,
    );
    if (r == null) return;
    AppLog.instance.act('种子详情', '编辑[${S.fieldPath}]', target: t.name);
    await _apply(
      t,
      S.fieldPath,
      () => _ctrl.setLocationOf(<String>[t.hash], r.path, move: r.move),
    );
  }

  Future<void> _editCategory(Torrent t) async {
    final List<String> cats = _ctrl
        .facets(FilterDim.category)
        .map((FacetEntry e) => e.value)
        .toList();
    final String? v = await EditDialogs.category(
      context,
      initial: t.category ?? '',
      candidates: cats,
    );
    if (v == null) return;
    AppLog.instance.act('种子详情', '编辑[${S.fieldCategory}]', target: t.name);
    await _apply(
      t,
      S.fieldCategory,
      () => _ctrl.setCategoryOf(<String>[t.hash], v),
    );
  }

  Future<void> _editTags(Torrent t) async {
    final List<String> cand =
        _ctrl.facets(FilterDim.tags).map((FacetEntry e) => e.value).toList();
    final TagEditResult? r = await EditDialogs.tags(
      context,
      initial: t.tagList,
      candidates: cand,
    );
    if (r == null) return;
    AppLog.instance.act('种子详情', '编辑[${S.fieldTags}]', target: t.name);
    await _apply(
      t,
      S.fieldTags,
      () => _ctrl.setTagsOf(<String>[t.hash], r.tags, append: r.append),
    );
  }

  Future<void> _rename(Torrent t) async {
    final String? v = await EditDialogs.text(
      context,
      title: S.renameTorrent,
      label: S.renameTitle,
      initial: t.name,
      hint: S.renameTorrentHint,
    );
    if (v == null || v == t.name) return;
    await _apply(t, S.renameTorrent, () => _ctrl.renameTorrent(t, v));
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
