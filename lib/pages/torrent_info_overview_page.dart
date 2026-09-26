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
import '../widgets/piece_heatmap.dart';
import '../widgets/progress_ring.dart';
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

  bool _openStats = true;
  bool _openLimits = true;
  bool _openPlace = true;
  bool _openTimes = true;
  bool _openMeta = false;

  /// null = 跟随当前值推导；true = 强制展示自定义输入
  bool? _ratioCustom;
  bool? _seedCustom;

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

  bool _extraBool(String key, [bool def = false]) {
    final dynamic v = _ctrl.detailExtras[key];
    return v is bool ? v : def;
  }

  int? _extraInt(String key) => (_ctrl.detailExtras[key] as num?)?.toInt();

  String? _extraStr(String key) {
    final dynamic v = _ctrl.detailExtras[key];
    if (v == null) return null;
    final String s = v.toString();
    return s.isEmpty ? null : s;
  }

  int? _pieceCountOf(bool isQb) =>
      _extraInt(isQb ? 'piece_count' : 'pieceCount');

  int? _pieceSizeOf(bool isQb) => _extraInt(isQb ? 'piece_size' : 'pieceSize');

  int? _createdOnOf(bool isQb) =>
      _extraInt(isQb ? 'creation_date' : 'dateCreated');

  String? _createdByOf(bool isQb) =>
      _extraStr(isQb ? 'created_by' : 'creator');

  List<int>? get _pieceStates {
    final dynamic v = _ctrl.detailExtras['piece_states'];
    if (v is List && v.isNotEmpty) {
      return v.map((dynamic e) => (e as num?)?.toInt() ?? 0).toList();
    }
    return null;
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

      final bool checking = t.isChecking;
      final bool running = !t.isPause;
      final CapabilitySet cap = _ctrl.capabilities;
      final bool isQb = cap.isQb;

      return ListView(
        padding: EdgeInsets.fromLTRB(af(context, 12), af(context, 10), af(context, 12), af(context, 24)),
        children: <Widget>[

          _heroCard(t, cs, checking: checking),

          if (t.isError) ...<Widget>[
            SizedBox(height: af(context, 8)),
            _errorBanner(t, cs),
          ],

          if (_metaIncomplete(t)) ...<Widget>[
            SizedBox(height: af(context, 8)),
            _metadataBar(t),
          ],

          SizedBox(height: af(context, 10)),
          _actionArea(t, running: running, checking: checking),
          if (cap.forceStart ||
              cap.sequentialDownload ||
              isQb ||
              cap.superSeeding ||
              (cap.bandwidthPriority && _ctrl.detailExtras['honorsSessionLimits'] is bool)) ...<Widget>[
            SizedBox(height: af(context, 8)),
            _switchGroup(t),
          ],

          SizedBox(height: af(context, 10)),
          _foldCard(S.editSectionStats, _openStats, () => setState(() => _openStats = !_openStats),
            _statsBody(t, cs, isQb: isQb, cap: cap)),

          _foldCard(S.editSectionLimits, _openLimits, () => setState(() => _openLimits = !_openLimits),
            _limitsBody(t)),

          _foldCard(S.editSectionBasic, _openPlace, () => setState(() => _openPlace = !_openPlace),
            _placeBody(t, cap)),

          _foldCard(S.editSectionTimes, _openTimes, () => setState(() => _openTimes = !_openTimes),
            _timesBody(t, isQb: isQb, cap: cap)),

          _foldCard(S.editSectionLinks, _openMeta, () => setState(() => _openMeta = !_openMeta),
            _metaBody(t, isQb: isQb, cap: cap)),

          if (_draft.isNotEmpty) ...<Widget>[
            const Divider(height: 18),
            Padding(
              padding: EdgeInsets.only(bottom: af(context, 8)),
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

  // ─────────────────────────── 英雄卡 ───────────────────────────

  Widget _heroCard(Torrent t, ColorScheme cs, {required bool checking}) {
    final Color st = Formatter.setStatusColor(t.state, cs);
    final double progress = t.progress.clamp(0.0, 1.0);
    return Container(
      padding: EdgeInsets.all(af(context, 12)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[st.withValues(alpha: 0.12), st.withValues(alpha: 0.02)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: st.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: af(context, 9),
                height: af(context, 9),
                decoration: BoxDecoration(
                  color: st,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: st.withValues(alpha: 0.35), blurRadius: 6, spreadRadius: 2),
                  ],
                ),
              ),
              SizedBox(width: af(context, 7)),
              Text(
                checking ? _kChecking : Formatter.setStatus(t.state),
                style: TextStyle(
                  fontSize: af(context, 12),
                  fontWeight: FontWeight.w700,
                  color: st,
                ),
              ),
              SizedBox(width: af(context, 8)),
              Expanded(
                child: SelectableText(
                  t.name,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: af(context, 12.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy, size: AppTheme.iconSize),
                tooltip: S.nameCopied,
                onPressed: () async {
                  await ClipboardSet.copy(t.name);
                  Formatter.showToast(S.nameCopied);
                },
              ),
            ],
          ),
          SizedBox(height: af(context, 10)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ProgressRing(
                progress: progress,
                color: st,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: af(context, 15),
                        fontWeight: FontWeight.w700,
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '${Formatter.setSize(t.newRelativeSize)} / ${Formatter.setSize(t.newSize)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: af(context, 8.5), color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              SizedBox(width: af(context, 14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _speedLine('▼', Formatter.setSpeed(t.newDownSpeed), _dlBlue),
                    const SizedBox(height: 2),
                    _speedLine('▲', Formatter.setSpeed(t.newUpspeed), _ulGreen),
                    SizedBox(height: af(context, 6)),
                    SizedBox(
                      height: af(context, 26),
                      child: SpeedSparkline(
                        dl: List<double>.of(_ctrl.dlSamples),
                        ul: List<double>.of(_ctrl.ulSamples),
                      ),
                    ),
                    SizedBox(height: af(context, 6)),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        _pill(
                          checking
                              ? '$_kChecking ${Formatter.setProgress(t.progress)}'
                              : '${S.fieldEta} ${Formatter.setEta(t.newEta)}',
                        ),
                        _pill(_syncHint()),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: af(context, 10)),
          Row(
            children: <Widget>[
              _metric('连接', t.activePeers < 0 ? '-' : '${t.activePeers}'),
              _metric('做种', '${t.numComplete}'),
              _metric('下载', '${t.numIncomplete}'),
              if (_ctrl.capabilities.isQb && t.availability > 0)
                _metric(S.fieldHealth, '${(t.availability * 100).toStringAsFixed(0)}%',
                    valueColor: _ulGreen),
            ],
          ),
          SizedBox(height: af(context, 6)),
          Text(
            '${Formatter.getSeederCount(t.numComplete, t.numIncomplete, t.transferPeers)}'
            ' · ${S.fieldProgress} ${Formatter.setProgress(t.progress)}',
            style: TextStyle(fontSize: af(context, 9.5), color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _speedLine(String arrow, String speed, Color c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          '$arrow ',
          style: TextStyle(fontSize: af(context, 11), color: c, fontWeight: FontWeight.w700),
        ),
        Text(
          speed,
          style: TextStyle(
            fontSize: af(context, 16),
            fontWeight: FontWeight.w700,
            color: c,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, String value, {Color? valueColor}) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: EdgeInsets.symmetric(vertical: af(context, 5)),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: TextStyle(fontSize: af(context, 9), color: cs.onSurfaceVariant)),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                fontSize: af(context, 12.5),
                fontWeight: FontWeight.w700,
                color: valueColor,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(fontSize: af(context, 9), color: cs.onSurfaceVariant)),
    );
  }

  String _syncHint() {
    final DateTime? at = _ctrl.detailSyncedAt.value;
    if (at == null) return '正在获取…';
    final int sec = DateTime.now().difference(at).inSeconds;
    if (sec <= 1) return '刚刚更新 · 每 3 秒自动刷新';
    return '$sec 秒前更新 · 每 3 秒自动刷新';
  }

  // ─────────────────────────── 操作区 ───────────────────────────

  Widget _actionArea(Torrent t, {required bool running, required bool checking}) {
    final Color danger = Theme.of(context).colorScheme.error;
    final CapabilitySet cap = _ctrl.capabilities;
    Widget gap() => const SizedBox(width: 6);

    Widget btn({
      required String label,
      required IconData icon,
      required VoidCallback? onTap,
      bool filled = false,
      Color? color,
    }) =>
        Expanded(
          child: (filled ? FilledButton.icon : OutlinedButton.icon)(
            icon: Icon(icon, size: AppTheme.iconSize, color: color),
            label: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: af(context, 11), color: color)),
            onPressed: onTap,
            style: (filled ? FilledButton.styleFrom : OutlinedButton.styleFrom)(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              side: (!filled && color != null)
                  ? BorderSide(color: color.withValues(alpha: 0.55))
                  : null,
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            btn(
              label: '继续',
              icon: Icons.play_arrow,
              filled: true,
              onTap: (!running && !checking && !_busy)
                  ? () {
                      AppLog.instance
                          .act('种子详情', '按钮[继续]', target: t.name);
                      _run(t, _ctrl.resumeSelected, '已继续');
                    }
                  : null,
            ),
            gap(),
            btn(
              label: '暂停',
              icon: Icons.pause,
              filled: true,
              onTap: (running && !checking && !_busy)
                  ? () {
                      AppLog.instance
                          .act('种子详情', '按钮[暂停]', target: t.name);
                      _run(t, _ctrl.pauseSelected, '已暂停');
                    }
                  : null,
            ),
            gap(),
            btn(
              label: checking ? '$_kChecking…' : '重新校验',
              icon: Icons.fact_check_outlined,
              onTap: (!checking && !_busy) ? () => _recheck(t) : null,
            ),
            gap(),
            btn(
              label: '重新汇报',
              icon: Icons.sync,
              onTap: _busy ? null : () => _reannounce(t),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            btn(
              label: S.renameTorrent,
              icon: Icons.drive_file_rename_outline,
              onTap: _busy ? null : () => _rename(t),
            ),
            gap(),
            btn(
              label: S.delete,
              icon: Icons.delete,
              color: danger,
              onTap: _busy ? null : () => _delete(t),
            ),
            if (cap.exportTorrent) ...<Widget>[
              gap(),
              btn(
                label: S.btExportTorrent,
                icon: Icons.download,
                onTap: _busy ? null : () => _exportTorrent(t),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ─────────────────────────── 折叠卡 ───────────────────────────

  Widget _foldCard(String title, bool open, VoidCallback onToggle, Widget child) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: af(context, 9)),
      padding: EdgeInsets.fromLTRB(af(context, 10), af(context, 6), af(context, 10), open ? af(context, 9) : 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.75),
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 3,
                    height: 12,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: af(context, 16),
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (open) child,
        ],
      ),
    );
  }

  // ─────────────────────────── 传输统计 ───────────────────────────

  Widget _statsBody(Torrent t, ColorScheme cs, {required bool isQb, required CapabilitySet cap}) {
    final List<int>? states = _pieceStates;
    final int? pieceCount = _pieceCountOf(isQb);
    final int? pieceSize = _pieceSizeOf(isQb);
    final int? sessionUp = isQb ? _extraInt('total_uploaded_session') : null;
    final int? sessionDl = isQb ? _extraInt('total_downloaded_session') : null;
    final int? desired = !isQb ? _extraInt('desiredAvailable') : null;
    final int? webSeeds = !isQb ? _extraInt('webseedsSendingToUs') : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ReadonlyKvGrid(pairs: <List<String>>[
          <String>[S.fieldState, Formatter.setStatus(t.newState)],
          <String>[
            '校验进度',
            t.isChecking ? Formatter.setProgress(t.progress) : '—',
          ],
          <String>[S.fieldSize, Formatter.setSize(t.newSize)],
          <String>[S.fieldRatio, Formatter.setRatio(t.ratio)],
          <String>[
            S.fieldSeeders,
            Formatter.getSeederCount(t.numComplete, t.numIncomplete, t.transferPeers),
          ],
          <String>[S.fieldEta, Formatter.setEta(t.newEta)],
          <String>[S.fieldDlSpeed, Formatter.setSpeed(t.newDownSpeed)],
          <String>[S.fieldUpSpeed, Formatter.setSpeed(t.newUpspeed)],
          <String>[S.fieldDownloaded, Formatter.setSize(t.downloaded)],
          <String>[S.fieldUploaded, Formatter.setSize(t.newUploaded)],
          if (sessionDl != null && sessionDl > 0)
            <String>['本次会话 ↓', Formatter.setSize(sessionDl)],
          if (sessionUp != null && sessionUp > 0)
            <String>['本次会话 ↑', Formatter.setSize(sessionUp)],
          <String>[
            S.fieldRemaining,
            t.amountLeft > 0 ? Formatter.setSize(t.amountLeft) : '—',
          ],
          <String>[
            S.fieldWastedShort,
            t.wasted > 0 ? Formatter.setSize(t.wasted) : '—',
          ],
          if (desired != null && desired > 0)
            <String>['可获取量', Formatter.setSize(desired)],
          if (webSeeds != null && webSeeds > 0)
            <String>['Web 做种', '$webSeeds'],
        ]),
        if (states != null) ...<Widget>[
          SizedBox(height: af(context, 10)),
          PieceHeatmap(states: states, height: af(context, 30)),
          SizedBox(height: af(context, 5)),
          Row(
            children: <Widget>[
              Text(
                '分块 ${pieceCount ?? states.length}'
                '${pieceSize != null && pieceSize > 0 ? ' × ${Formatter.setSize(pieceSize)}' : ''}',
                style: TextStyle(fontSize: af(context, 9.5), fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _legendCell(PieceHeatmap.cDone, '已完成'),
              const SizedBox(width: 8),
              _legendCell(PieceHeatmap.cActive, '下载中'),
              const SizedBox(width: 8),
              _legendCell(PieceHeatmap.cMissing, '空缺'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _legendCell(Color c, String label) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 7, height: 7, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: af(context, 9), color: cs.onSurfaceVariant)),
      ],
    );
  }

  // ─────────────────────────── 限速与做种 ───────────────────────────

  Widget _limitsBody(Torrent t) {
    final CapabilitySet cap = _ctrl.capabilities;
    final bool trHonors = cap.bandwidthPriority &&
        _ctrl.detailExtras['honorsSessionLimits'] is bool;
    final bool ratioCustom = _ratioCustom ?? t.ratioLimit >= 0;
    final bool seedCustom = _seedCustom ?? t.seedingTimeLimit >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _dlLimitField(t),
        _upLimitField(t),
        SizedBox(height: af(context, 6)),
        _modeChips(
          S.fieldRatioLimit,
          t.ratioLimit,
          customShown: ratioCustom,
          onMode: (int mode) async {
            if (mode >= 0) {
              setState(() => _ratioCustom = true);
              return;
            }
            setState(() => _ratioCustom = false);
            await _apply(t, S.fieldRatioLimit,
                () => _ctrl.setShareLimitsOf(<String>[t.hash], ratioLimit: mode.toDouble()));
          },
        ),
        if (ratioCustom)
          _ratioLimitField(t),
        SizedBox(height: af(context, 6)),
        _modeChips(
          S.fieldSeedingTimeLimit,
          t.seedingTimeLimit.toDouble(),
          customShown: seedCustom,
          unitLabel: S.editMinutesUnit,
          onMode: (int mode) async {
            if (mode >= 0) {
              setState(() => _seedCustom = true);
              return;
            }
            setState(() => _seedCustom = false);
            await _apply(t, S.fieldSeedingTimeLimit,
                () => _ctrl.setShareLimitsOf(<String>[t.hash], seedingTimeMin: mode));
          },
        ),
        if (seedCustom) _seedTimeField(t),
        if (trHonors) ...<Widget>[
          SizedBox(height: af(context, 4)),
          EditSwitchChip(
            label: '遵循全局限速',
            value: _extraBool('honorsSessionLimits', true),
            onChanged: (bool v) => _apply(
              t,
              '遵循全局限速',
              () => _ctrl.setHonorsLimitsOf(<String>[t.hash], v),
            ),
          ),
        ],
      ],
    );
  }

  Widget _modeChips(
    String label,
    double current, {
    required bool customShown,
    required ValueChanged<int> onMode,
    String? unitLabel,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    Widget chip(String text, int mode, bool selected) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: selected ? null : () => onMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? cs.primary.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.55)
                  : cs.outlineVariant.withValues(alpha: 0.9),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: af(context, 10),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        SizedBox(
          width: af(context, 88),
          child: Text(label, style: TextStyle(fontSize: af(context, 11))),
        ),
        const SizedBox(width: 4),
        chip('跟随全局', -2, current < -1),
        const SizedBox(width: 5),
        chip('自定义', 0, customShown),
        const SizedBox(width: 5),
        chip('不限制', -1, current == -1 && !customShown),
        if (current >= 0 && !customShown) ...<Widget>[
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              unitLabel == null
                  ? Formatter.setRatio(current.toDouble())
                  : '$current $unitLabel',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: af(context, 10.5)),
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────── 位置与组织 ───────────────────────────

  Widget _placeBody(Torrent t, CapabilitySet cap) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool queueable = cap.queuePosition || cap.isQb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (t.savePath != null)
          EditActionRow(
            label: S.fieldPath,
            value: t.savePath!,
            onTap: _busy ? null : () => _editPath(t),
          ),
        if (t.contentPath != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: af(context, 88),
                  child: Text('内容路径', style: TextStyle(fontSize: af(context, 11))),
                ),
                Expanded(
                  child: SelectableText(t.contentPath!, style: TextStyle(fontSize: af(context, 11))),
                ),
              ],
            ),
          ),
        if (cap.category)
          EditActionRow(
            label: S.fieldCategory,
            value: t.categoryName,
            onTap: _busy ? null : () => _editCategory(t),
          ),
        EditActionRow(
          label: S.fieldTags,
          value: t.tags == null || t.tags!.isEmpty ? S.editCategoryNone : t.tags!,
          onTap: _busy ? null : () => _editTags(t),
        ),
        if (queueable) ...<Widget>[
          SizedBox(height: af(context, 6)),
          Row(
            children: <Widget>[
              SizedBox(
                width: af(context, 88),
                child: Text('队列位置', style: TextStyle(fontSize: af(context, 11))),
              ),
              Text(
                cap.isQb ? '第 ${t.priority} 位' : '第 ${t.priority + 1} 位',
                style: TextStyle(
                  fontSize: af(context, 11.5),
                  fontWeight: FontWeight.w600,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              _queueBtn(context, cs, Icons.vertical_align_top, '置顶', 'top'),
              const SizedBox(width: 4),
              _queueBtn(context, cs, Icons.arrow_upward, '上移', 'up'),
              const SizedBox(width: 4),
              _queueBtn(context, cs, Icons.arrow_downward, '下移', 'down'),
              const SizedBox(width: 4),
              _queueBtn(context, cs, Icons.vertical_align_bottom, '沉底', 'bottom'),
            ],
          ),
        ],
        if (cap.bandwidthPriority) ...<Widget>[
          SizedBox(height: af(context, 6)),
          _bandwidthRow(t),
        ],
      ],
    );
  }

  Widget _queueBtn(BuildContext context, ColorScheme cs, IconData icon, String tip, String where) {
    return Tooltip(
      message: tip,
      child: SizedBox(
        width: af(context, 26),
        height: af(context, 26),
        child: IconButton(
          icon: Icon(icon, size: af(context, 15)),
          color: cs.onSurfaceVariant,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
          onPressed: _busy
              ? null
              : () {
                  final Torrent? t = _ctrl.current.value;
                  if (t == null) return;
                  AppLog.instance.act('种子详情', '队列[$tip]', target: t.name);
                  _run(t, () => _ctrl.queueMoveSelected(where), '已$tip');
                },
        ),
      ),
    );
  }

  Widget _bandwidthRow(Torrent t) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int current = t.bandwidthPriority;
    Widget chip(String label, int value) {
      final bool selected = current == value;
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: selected || _busy
            ? null
            : () {
                _apply(
                  t,
                  '带宽优先级',
                  () => _ctrl.setBandwidthPriorityOf(<String>[t.hash], value),
                );
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? cs.primary.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.55)
                  : cs.outlineVariant.withValues(alpha: 0.9),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: af(context, 10),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        SizedBox(
          width: af(context, 88),
          child: Text('带宽优先级', style: TextStyle(fontSize: af(context, 11))),
        ),
        const SizedBox(width: 4),
        chip('高', 1),
        const SizedBox(width: 5),
        chip('普通', 0),
        const SizedBox(width: 5),
        chip('低', -1),
      ],
    );
  }

  // ─────────────────────────── 时间信息 ───────────────────────────

  Widget _timesBody(Torrent t, {required bool isQb, required CapabilitySet cap}) {
    final int? createdOn = _createdOnOf(isQb);
    final int? lastSeen = isQb ? _extraInt('last_seen') : null;
    return ReadonlyKvGrid(pairs: <List<String>>[
      <String>[S.fieldAddedOn, Formatter.setDate(t.newAddedOn)],
      <String>[S.fieldCompletionOn, Formatter.setDate(t.newCompletionOn)],
      if (createdOn != null && createdOn > 0)
        <String>['创建时间', Formatter.setDate(createdOn)],
      if (lastSeen != null && lastSeen > 0)
        <String>['最后见到', Formatter.setDate(lastSeen)],
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
    ]);
  }

  // ─────────────────────────── 元数据 ───────────────────────────

  Widget _metaBody(Torrent t, {required bool isQb, required CapabilitySet cap}) {
    final String site = t.site;
    final String? createdBy = _createdByOf(isQb);
    final String? hashV2 = isQb ? _extraStr('infohash_v2') : null;
    final int? nbConn = isQb ? _extraInt('nb_connections') : null;
    final int? nbLimit = isQb ? _extraInt('nb_connections_limit') : null;
    final int? trMaxPeers = !isQb ? _extraInt('maxConnectedPeers') : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (site.isNotEmpty) _kvCopy(S.fieldSiteName, site, maxLines: 2),
        _kvCopy('${S.fieldHash}（v1）', t.hash, maxLines: 2),
        if (hashV2 != null && hashV2.isNotEmpty)
          _kvCopy('Info Hash v2', hashV2, maxLines: 2),
        if ((t.magnetUri ?? '').isNotEmpty)
          _kvCopy(S.fieldMagnet, t.magnetUri!, mask: true, maxLines: 3),
        if ((t.comment ?? '').isNotEmpty)
          _kvCopy(S.fieldComment, t.comment!, maxLines: 3),
        if (createdBy != null) _kvCopy('创建工具', createdBy, maxLines: 2),
        if (nbConn != null && nbConn > 0)
          _kv('连接数', nbLimit != null && nbLimit > 0 ? '$nbConn / 上限 $nbLimit' : '$nbConn'),
        if (trMaxPeers != null && trMaxPeers > 0)
          _kv('连接上限', '$trMaxPeers'),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: af(context, 88),
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
            width: af(context, 88),
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
            height: af(context, 28),
            width: af(context, 28),
            child: IconButton(
              icon: Icon(Icons.copy, size: af(context, 14)),
              tooltip: S.nameCopied,
              onPressed: () async {
                final String text = mask ? Formatter.maskUrl(v) : v;
                await ClipboardSet.copy(text);
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
      padding: EdgeInsets.fromLTRB(af(context, 10), af(context, 8), af(context, 10), af(context, 8)),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: cs.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: af(context, 16), color: cs.error),
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

  // ─────────────────────────── 开关组 ───────────────────────────

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
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  // ─────────────────────────── 编辑字段 ───────────────────────────

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
        initial: t.ratioLimit >= 0 ? t.ratioLimit : 0,
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

  // ─────────────────────────── 动作逻辑 ───────────────────────────

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
      Formatter.showToast('已开始校验 ${t.name}（进度见上方）');
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

  Future<String?> _write(Future<String?> Function() body) async {
    try {
      return await body();
    } catch (e) {
      return Formatter.safeErr(e);
    }
  }
}

/// 剪贴板小工具（避免本文件直接依赖 flutter/services 的散落调用）
class ClipboardSet {
  ClipboardSet._();

  static Future<void> copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
