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

  /// 编辑草稿：只有**页面级的未提交标记**放在这里（每个输入框自己的文本
  /// 由组件 state 持有）。详情页不因滚动被回收 ⇒ 放页面 state 就够；
  /// 列表卡片的草稿必须放 controller（那边会被回收重建）。
  final EditDraft _draft = EditDraft();

  void _markDirty(String key, bool dirty) {
    if (dirty) {
      _draft.write(key, true);
    } else {
      _draft.drop(key);
    }
    if (mounted) setState(() {});
  }

  /// 异常 Tracker 计数（明细与错误原因已在 Tracker Tab，概览只给计数 + 引导）。
  int get _badTrackerCount {
    int n = 0;
    for (final Map<String, dynamic> m in _ctrl.trackers) {
      final int st = (m['status'] as num?)?.toInt() ?? -1;
      // qB：4 = 未工作；TR：用 lastAnnounceSucceeded 判定。
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
              Text(S.pleaseSelectTorrent, style: const TextStyle(fontSize: 12)),
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

          // ★ 种子级错误原因红条：v3 布局定稿把它归到页面**末尾的条件块**
          //   （与元数据进度同区，见本文件 11 条顺序的最后一条）。

          const SizedBox(height: 6),

          // ── 区①：实时状态（2026-09-24 用户整改：每栏目套分区卡片，边界感 + 可读性）──
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
                            TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
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
                    _statChip(
                        '连接', t.activePeers < 0 ? '-' : '${t.activePeers}', cs),
                    const SizedBox(width: 8),
                    _statChip('做种', '${t.numComplete}', cs),
                    const SizedBox(width: 8),
                    _statChip('下载', '${t.numIncomplete}', cs),
                    // ★ 健康度：只有 qB 返回（TR 的 availability 是 per-piece 数组，
                    //   不是百分比 ⇒ 不能共用一套显示逻辑）。
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
                          TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 区②：操作（2026-09-24 用户整改：六个按钮**固定两行 × 3 列等宽**，
          //   随屏幕自适应、**不横向滑动**；下载策略 chip 归到同一区）──
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

          // ── 区③：基本信息（只读短值 ⇒ 两列网格）──
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
              // ★ v3：剩余量从进度条下方移进组①（图上它就占这一格）。
              <String>[
                S.fieldRemaining,
                t.amountLeft > 0 ? Formatter.setSize(t.amountLeft) : '—',
              ],
              // ★ v3：损坏·浪费固定占一格（原来只在 >0 时才出现 ⇒ 网格会缺角）。
              <String>[
                S.fieldWastedShort,
                t.wasted > 0 ? Formatter.setSize(t.wasted) : '—',
              ],
            ]),
          ),

          // ── 区④：限速与分享（4 项**各独占一行** —— 2026-09-24 用户整改，
          //   撤回 v3 的 2×2；文案以「下载限速 / 上传限速 / 分享率上限 / 做种时限」为准）──
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

          // ── 区⑤：时间信息（只读短值 ⇒ 两列网格）──
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
              // ★ Tracker 数量 → 状态：异常的明细与错误原因已在 Tracker Tab，
              //   概览只给计数 + 引导，不重复造明细。
              //   半格 label 只有 50dp ⇒ 用短文案「Tracker」（长文案会折行）。
              <String>[
                S.fieldTrackerShort,
                _badTrackerCount > 0
                    ? S.trackerFailed(_badTrackerCount)
                    : '${S.trackerAllOk}（${t.newTrackerCount}）',
              ],
              // 剩余磁盘空间（TR 有 `downloadDirFreeSpace`；qB 只有全局的 ⇒ 不显示）。
              if (!cap.isQb)
                <String>[
                  S.fieldDiskFree,
                  t.freeSpace > 0 ? Formatter.setSize(t.freeSpace) : '—',
                ],
              // 私有种子标记：TR 原生有；qB 要 5.0+（V4）⇒ 按版本显示。
              if (cap.privateFlag)
                <String>[
                  S.fieldPrivate,
                  t.isPrivate == null ? '—' : (t.isPrivate! ? S.yes : S.no),
                ],
            ]),
          ),

          const Divider(height: 18),

          // ── 区⑥：常规（路径 / 内容路径 / 分类 / 标签）──
          EditSectionCard(
            title: S.editSectionBasic,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // ★ 保存路径升级为可编辑（独占一行）。
                if (t.savePath != null)
                  EditActionRow(
                    label: S.fieldPath,
                    value: t.savePath!,
                    onTap: _busy ? null : () => _editPath(t),
                  ),
                if (t.contentPath != null) _kv('内容路径', t.contentPath!),
                // ★ 分类：仅 qB（TR 无分类 ⇒ 整行隐藏，D4）。
                if (cap.category)
                  EditActionRow(
                    label: S.fieldCategory,
                    value: t.categoryName,
                    onTap: _busy ? null : () => _editCategory(t),
                  ),
                // ★ 标签：chip 编辑器。
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

          // ── 区⑦：链接与标识 —— 站点名称 / 哈希**各独占一行、各带复制按钮**
          //   （2026-09-24 用户整改）；磁力链 / 注释同区。──
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

          // ★ v3 定稿：组③末尾补「导出种子」（与 AppBar 同口径按能力显隐）。
          if (_ctrl.capabilities.exportTorrent) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.download, size: AppTheme.iconSize),
                label:
                    Text(S.btExportTorrent, style: const TextStyle(fontSize: 11)),
                onPressed: _busy ? null : () => _exportTorrent(t),
              ),
            ),
          ],

          // ── 条件块（v3 第 11 条）：只在需要时出现，平时不占位 ──
          // ① 种子级错误原因红条（仅 error / missingFiles）
          if (t.isError) ...<Widget>[
            const SizedBox(height: 10),
            _errorBanner(t, cs),
          ],
          // ② 元数据进度（仅磁力链且元数据未完成）
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
                style: const TextStyle(fontSize: 10, color: Colors.deepOrange),
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

  /// ★ v3 的两列网格判据与排布已抽成**共享组件**（`EditLayout.gridOkOf` /
  ///   `ReadonlyKvGrid`，见 `torrent_edit_fields.dart`）—— 概览 Tab 与卡片展开区
  ///   共用同一份实现，别再在本页另写一套（第 67 轮 v3 只落了概览、展开区漏做的教训）。
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

  /// 带「复制」按钮的只读行（站点 / 哈希 / 磁力链 / 注释这类长值）。
  ///
  /// [maxLines] 给超长值封顶（哈希 40 字符、磁力链几百字符）—— 不封顶会把
  /// 页面撑得很长；复制按钮拿到的仍是**完整原值**。
  Widget _kvCopy(String k, String v, {bool mask = false, int? maxLines}) {
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
            child: SelectableText(
              v,
              maxLines: maxLines,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          SizedBox(
            height: 28,
            width: 28,
            child: IconButton(
              icon: const Icon(Icons.copy, size: 14),
              tooltip: S.nameCopied,
              onPressed: () async {
                // ★ 磁力链里可能带 passkey ⇒ 与 trackers 页口径一致，脱敏后再复制。
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

  /// 种子级错误原因红条（仅 error / missingFiles 状态显示）。
  ///
  /// 值来自 TR `errorString`、qB `state`；两者都可能为空 ⇒ 空时给兜底文案，
  /// 别显示一条空的红条。
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
              style: TextStyle(fontSize: 11, color: cs.error),
            ),
          ),
        ],
      ),
    );
  }

  /// 元数据下载进度（仅磁力链且元数据未完成时显示）。
  ///
  /// TR 有 `metadataPercentComplete`；qB 没有 ⇒ 用 -1 表示"未知"，此时仍显示
  /// 但进度条按不确定态处理（用户至少知道卡在"获取元数据"）。
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
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  /// 元数据是否仍在下载中（v3 条件块②的显示条件）。
  ///
  /// 原来是 `_remainingRow` 里的内联判断；v3 把元数据进度挪进末尾条件块后单独成函数。
  bool _metaIncomplete(Torrent t) =>
      !t.isCompleted &&
      t.metadataPercent >= 0 &&
      t.metadataPercent < 1 &&
      (t.magnetUri ?? '').isNotEmpty;

  /// 操作按钮：**固定两行 × 3 列等宽**（2026-09-24 用户整改）。
  ///
  /// ★ 原实现是 `Wrap` —— 折行位置随字数与屏幕而变（3/2/1 行），位置不固定；
  ///   现固定两行、每格 `Expanded` 等宽 ⇒ 随屏幕自适应、**永不横向滑动**。
  ///   行 1 = 运行控制：继续 / 暂停 / 重新校验
  ///   行 2 = 其它：重新汇报 / 重命名 / 删除（危险项放行末）
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
                style: const TextStyle(fontSize: 11)),
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
                style: TextStyle(fontSize: 11, color: color)),
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

  /// 下载限速（模型统一存 bytes/s ⇒ 显示/提交都按 KB/s 换算）。
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

  /// 上传限速（同上）。
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

  /// 分享率上限（-2 跟随全局 / -1 不限 / ≥0 具体值）。
  ///
  /// ★ 2026-09-24 用户整改：4 项改回独占一行 ⇒ label 有 88dp，
  ///   恢复**完整文案**「分享率上限」（用户口径「文本以这个为准」）。
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

  /// 做种时限（分钟；≤0 ⇒ 提交 -1 = 不限）。
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

  /// 导出当前种子（v3 组③末尾的入口；与 AppBar 的导出同口径、同落盘方式）。
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
      // ★ 走系统「另存为」让用户自己选位置：直接写 app 私有目录在
      //   Android 11+ 的文件管理器里看不到。
      final String? saved = await FileExport.saveBytesAs(
        fileName: '${t.name}.torrent',
        bytes: Uint8List.fromList(bytes),
        dialogTitle: S.btExportTorrent,
      );
      if (saved == null) return; // 用户取消
      Formatter.showToast('${S.btExportOk} $saved');
    } catch (e) {
      Formatter.showToast(
        '${S.btExportFailPrefix}${Formatter.safeErr(e)}',
        isError: true,
      );
    }
  }

  /// 开关组（v3 定稿：**同一行 4 个 chip**；用 `Wrap` ⇒ 窄屏自动折行，不会溢出）。
  ///
  /// ★ 「顺序下载」按**版本**显示（TR 4.1 才有 ⇒ V6），不是按服务器类型一刀切。
  /// ★ 强制做种 / 超级做种只有 qB 有（TR 的 `honorsSessionLimits` 语义完全不同）。
  /// ★ 不支持的项**直接隐藏**（D4：不给点了才报错的控件）。
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
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    );
  }

  /// 统一的编辑提交外壳：成功 toast + 延迟 400ms 再拉一次定点刷新。
  ///
  /// ★ 延迟刷新是必需的：qB 常常"返回成功但状态还没变"，只信返回值会显示旧值。
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
      // TR 的 set-location 可选 move；qB 恒移动 ⇒ 弹窗里只给说明。
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
