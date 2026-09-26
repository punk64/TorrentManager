import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../controllers/torrent_controller.dart';
import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';
import '../app/adaptive.dart';

class TorrentInfoTrackersPage extends StatefulWidget {
  const TorrentInfoTrackersPage({super.key});

  @override
  State<TorrentInfoTrackersPage> createState() =>
      _TorrentInfoTrackersPageState();
}

class _TorrentSpecialEntry {
  const _TorrentSpecialEntry(this.key, this.label);

  final String key;

  final String label;
}

class _TorrentInfoTrackersPageState extends State<TorrentInfoTrackersPage> {
  final TorrentController ctrl = Get.find<TorrentController>();
  final ServerController sc = Get.find<ServerController>();

  bool _showChart = false;

  static const List<_TorrentSpecialEntry> _specials = <_TorrentSpecialEntry>[
    _TorrentSpecialEntry('DHT', 'DHT'),
    _TorrentSpecialEntry('PEX', 'PEX'),
    _TorrentSpecialEntry('LSD', 'LSD'),
  ];

  /// qB 返回的 `** [DHT] **` 等特殊条目不算真实 Tracker
  static final RegExp _specialRe = RegExp(r'^\*\*\s*\[(\w+)\]\s*\*\*$');

  bool _isSpecial(Map<String, dynamic> t) {
    final String url =
        (t['url'] ?? t['announce'] ?? t['host'])?.toString() ?? '';
    return _specialRe.hasMatch(url.trim());
  }

  List<Map<String, dynamic>> get _realTrackers =>
      ctrl.trackers.where((Map<String, dynamic> t) => !_isSpecial(t)).toList();

  Map<String, Map<String, dynamic>> get _specialMap {
    final Map<String, Map<String, dynamic>> out = <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> t in ctrl.trackers) {
      if (!_isSpecial(t)) continue;
      final String url =
          (t['url'] ?? t['announce'] ?? t['host'])?.toString() ?? '';
      final Match? m = _specialRe.firstMatch(url.trim());
      if (m == null) continue;
      out[m.group(1)!.toUpperCase()] = t;
    }
    return out;
  }

  int get _badCount {
    int n = 0;
    for (final Map<String, dynamic> t in _realTrackers) {
      final bool isQb = sc.current.value?.isQbittorrent == true;
      final int st = (t['status'] as num?)?.toInt() ?? -1;
      if (isQb) {
        if (st == 4) n++;
      } else {
        if (t['isBackup'] == true) continue;
        if (t['lastAnnounceSucceeded'] == false) n++;
      }
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.detailLoading.value && ctrl.trackers.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      final List<Map<String, dynamic>> trackers = _realTrackers;
      final Map<String, Map<String, dynamic>> specials = _specialMap;
      if (trackers.isEmpty && specials.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.asset('assets/images/empty.webp', width: af(context, 80)),
              SizedBox(height: af(context, 10)),
              Text(S.trkNone, style: TextStyle(fontSize: af(context, 12))),
              SizedBox(height: af(context, 12)),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: AppTheme.iconSize),
                label: Text(S.trkAddTitle, style: TextStyle(fontSize: af(context, 12))),
                onPressed: () => _editTracker(context, ctrl, sc, null),
              ),
            ],
          ),
        );
      }

      return ListView(
        padding: EdgeInsets.only(bottom: af(context, 24)),
        children: <Widget>[
          _summaryBar(trackers.length, specials),
          if (trackers.isNotEmpty) ...<Widget>[
            SizedBox(height: af(context, 8)),
            _chartToggle(trackers),
            if (_showChart)
              SizedBox(
                height: af(context, 170),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      af(context, 8), af(context, 8), af(context, 12), 0),
                  child: _TrackerBarChart(trackers: trackers),
                ),
              ),
          ],
          const SizedBox(height: 6),
          for (final Map<String, dynamic> t in trackers)
            _trackerCard(context, ctrl, sc, t),
          Padding(
            padding: EdgeInsets.all(af(context, 12)),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: AppTheme.iconSize),
              label: Text(S.trkAddTitle, style: TextStyle(fontSize: af(context, 12))),
              onPressed: () => _editTracker(context, ctrl, sc, null),
            ),
          ),
        ],
      );
    });
  }

  // ─────────────────────────── 汇总条 ───────────────────────────

  Widget _summaryBar(int realCount, Map<String, Map<String, dynamic>> specials) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isQb = sc.current.value?.isQbittorrent == true;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(af(context, 12), af(context, 10), af(context, 12), 0),
      padding: EdgeInsets.symmetric(horizontal: af(context, 10), vertical: af(context, 8)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.75), width: 0.6),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            '$realCount 个 Tracker',
            style: TextStyle(fontSize: af(context, 11), fontWeight: FontWeight.w600),
          ),
          if (_badCount > 0)
            Text(
              '· ⚠ $_badCount 个异常',
              style: TextStyle(fontSize: af(context, 11), color: cs.error, fontWeight: FontWeight.w600),
            ),
          if (isQb)
            for (final _TorrentSpecialEntry e in _specials)
              _specialBadge(e, specials[e.key]),
        ],
      ),
    );
  }

  Widget _specialBadge(_TorrentSpecialEntry e, Map<String, dynamic>? t) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool on = t != null;
    final int nodes =
        ((t?['num_peers'] ?? t?['peers']) as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: on ? cs.primary.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: on ? cs.primary.withValues(alpha: 0.35) : cs.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? cs.primary : cs.outlineVariant,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            on && nodes > 0 ? '${e.label} $nodes' : e.label,
            style: TextStyle(
              fontSize: af(context, 10),
              color: on ? cs.onSurface : cs.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartToggle(List<Map<String, dynamic>> trackers) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => setState(() => _showChart = !_showChart),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: af(context, 12)),
        padding: EdgeInsets.symmetric(horizontal: af(context, 10), vertical: af(context, 8)),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.75), width: 0.6),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              _showChart ? Icons.expand_less : Icons.expand_more,
              size: af(context, 15),
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _showChart ? '收起分布图' : 'Tracker 分布图（做种 / 下载者对比）',
                style: TextStyle(fontSize: af(context, 10.5), color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Tracker 卡片 ───────────────────────────

  /// 返回 (颜色语义, 文案)：0 正常 1 进行中 2 异常 3 空闲
  (int, String) _statusOf(Map<String, dynamic> t, bool isQb) {
    if (isQb) {
      final int st = (t['status'] as num?)?.toInt() ?? -1;
      switch (st) {
        case 2:
          return (0, '工作中');
        case 3:
          return (1, '更新中');
        case 4:
          return (2, '不可用');
        case 1:
          return (3, '未联系');
        case 0:
          return (3, '未启用');
        default:
          return (3, '未知');
      }
    }
    if (t['isBackup'] == true) return (3, '备用');
    final int st = (t['announceState'] as num?)?.toInt() ?? 0;
    switch (st) {
      case 3:
        return (0, '活动中');
      case 2:
        return (1, '排队');
      case 1:
        return (1, '等待');
      default:
        return (3, '未活动');
    }
  }

  Color _statusColor(int level, ColorScheme cs) {
    switch (level) {
      case 0:
        return const Color(0xFF0F9D58);
      case 1:
        return const Color(0xFFE8710A);
      case 2:
        return cs.error;
      default:
        return cs.outline;
    }
  }

  Widget _trackerCard(
    BuildContext context,
    TorrentController ctrl,
    ServerController sc,
    Map<String, dynamic> t,
  ) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isQb = sc.current.value?.isQbittorrent == true;

    final String url =
        (t['url'] ?? t['announce'] ?? t['host'])?.toString() ?? '-';
    final int seeds =
        ((t['num_seeds'] ?? t['seederCount']) as num?)?.toInt() ?? 0;
    final int leechs =
        ((t['num_leeches'] ?? t['leecherCount']) as num?)?.toInt() ?? 0;
    final int downloaded =
        ((t['num_downloaded'] ?? t['downloadCount']) as num?)?.toInt() ?? 0;
    final int tier = ((t['tier']) as num?)?.toInt() ?? 0;

    final (int level, String statusText) = _statusOf(t, isQb);
    final Color stc = _statusColor(level, cs);

    String? errMsg;
    if (isQb) {
      if (level == 2) {
        final String m = (t['msg'] ?? '').toString();
        if (m.isNotEmpty) errMsg = m;
      }
    } else {
      if (t['lastAnnounceSucceeded'] == false) {
        final String m = (t['lastAnnounceResult'] ?? '').toString();
        if (m.isNotEmpty) errMsg = m;
      }
    }

    String? nextAnnounce;
    if (!isQb) {
      final int next = (t['nextAnnounceTime'] as num?)?.toInt() ?? 0;
      if (next > 0 && level != 3 && t['isBackup'] != true) {
        final int diff = next - DateTime.now().millisecondsSinceEpoch ~/ 1000;
        nextAnnounce = diff > 0 ? '下次汇报 $diff 秒后' : '下次汇报 等待中';
      }
    }

    return Container(
      margin: EdgeInsets.fromLTRB(af(context, 12), af(context, 6), af(context, 12), 0),
      padding: EdgeInsets.fromLTRB(af(context, 11), af(context, 9), af(context, 7), af(context, 9)),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.75), width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: af(context, 8),
                height: af(context, 8),
                decoration: BoxDecoration(color: stc, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: af(context, 11),
                  fontWeight: FontWeight.w700,
                  color: stc,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: af(context, 11.5), fontWeight: FontWeight.w600),
                ),
              ),
              _trackerMenu(context, ctrl, sc, url),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Wrap(
              spacing: 10,
              runSpacing: 3,
              children: <Widget>[
                _stat('做种', '$seeds'),
                _stat('下载者', '$leechs'),
                _stat('已完成', '$downloaded'),
                _stat('层级', '$tier'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 2),
            child: Row(
              children: <Widget>[
                if (nextAnnounce != null)
                  Text(
                    nextAnnounce,
                    style: TextStyle(fontSize: af(context, 10), color: cs.onSurfaceVariant),
                  ),
                const Spacer(),
                if (errMsg == null && level == 0)
                  Text(
                    isQb ? (t['msg']?.toString().isNotEmpty == true ? t['msg'].toString() : '成功 ✓') : '成功 ✓',
                    style: TextStyle(fontSize: af(context, 10), color: cs.outline),
                  ),
              ],
            ),
          ),
          if (errMsg != null) ...<Widget>[
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
              ),
              child: Text(
                '✗ $errMsg',
                style: TextStyle(fontSize: af(context, 10.5), color: cs.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        text: '$label ',
        style: TextStyle(fontSize: af(context, 10.5), color: cs.onSurfaceVariant),
        children: <TextSpan>[
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: af(context, 10.5),
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackerMenu(
    BuildContext context,
    TorrentController ctrl,
    ServerController sc,
    String url,
  ) {
    return PopupMenuButton<String>(
      onSelected: (String v) async {
        switch (v) {
          case 'copy':
            await Clipboard.setData(
              ClipboardData(text: Formatter.maskUrl(url)),
            );
            Formatter.showToast('${S.trkCopied}（passkey 已打码）');
            break;
          case 'edit':
            await _editTracker(context, ctrl, sc, url);
            break;
          case 'remove':
            await _removeTracker(context, ctrl, sc, url);
            break;
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
            value: 'copy',
            child: Text(S.trkCopied, style: TextStyle(fontSize: af(context, 12)))),
        PopupMenuItem<String>(
            value: 'edit',
            child: Text(S.trkEditTitle, style: TextStyle(fontSize: af(context, 12)))),
        PopupMenuItem<String>(
            value: 'remove',
            child: Text(S.trkDeleteTitle, style: TextStyle(fontSize: af(context, 12)))),
      ],
    );
  }

  // ─────────────────────────── 增删改（保留原逻辑） ───────────────────────────

  Future<void> _editTracker(
    BuildContext context,
    TorrentController ctrl,
    ServerController sc,
    String? original,
  ) async {
    final s = sc.current.value;
    final t = ctrl.current.value;
    if (s == null || t == null) return;

    final TextEditingController input = TextEditingController();
    final bool editing = original != null;

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(
          editing
              ? '${S.trkEditTitle}${t.name}）'
              : '${S.trkAddTitle}${t.name}）',
          style: TextStyle(fontSize: af(context, 14)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              editing ? S.trkReplaceHelp : S.trkAddAllHelp,
              style: TextStyle(fontSize: af(context, 10), height: 1.4),
            ),
            SizedBox(height: af(context, 8)),
            if (editing)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  original,
                  style: TextStyle(fontSize: af(context, 10)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            TextField(
              controller: input,
              maxLength: AppTheme.maxLenUrl,
              buildCounter: AppTheme.noCounter,
              maxLines: 3,
              style: TextStyle(fontSize: af(context, 11)),
              decoration: InputDecoration(
                labelText: 'Tracker URL',
                labelStyle: TextStyle(fontSize: af(context, 11)),
                hintText: 'udp://tracker.example.com:6969/announce',
                hintStyle: TextStyle(fontSize: af(context, 11)),
                helperText: S.setAddNewLineHelp,
                helperStyle: TextStyle(fontSize: af(context, 9)),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(input.text.trim()),
            child: Text(editing ? S.trkDoEdit : S.trkDoAdd),
          ),
        ],
      ),
    ).whenComplete(input.dispose);
    if (result == null || result.isEmpty) return;

    final List<String> urls = <String>[];
    for (final String line in result.split('\n')) {
      final String v = line.trim();
      if (v.isEmpty) continue;
      if (!Formatter.isValidUrl(v) && !v.startsWith('udp://')) {
        Formatter.showToast('${S.trkEditInvalidUrl}${t.name}', isError: true);
        return;
      }
      urls.add(v);
    }
    if (urls.isEmpty) return;

    try {
      if (s.isQbittorrent) {
        if (editing) {
          await sc.qb.editTracker(t.hash, original, result);

          AppLog.instance.op('修改 Tracker：$original → ${_oneLine(result)}'
              '（${t.name} · ${s.name}）',
              scope: s.logScope);
          Formatter.showToast('${S.trkEditOk}${t.name}');
        } else {
          await sc.qb.addTracker(t.hash, result);
          AppLog.instance.op('添加 Tracker：${_oneLine(result)}'
              '（${t.name} · ${s.name}）',
              scope: s.logScope);
          Formatter.showToast('${S.trkAddOk}${t.name}');
        }
      } else {
        if (t.trId == null) {
          Formatter.showToast(S.noTrId, isError: true);
          return;
        }

        final bool byList = ctrl.capabilities.trackerList;
        if (editing) {
          final int? tid = _trackerIdOf(ctrl, original);
          if (tid == null) {
            Formatter.showToast('${S.trkEditNotFound}$original', isError: true);
            return;
          }
          if (byList) {
            await sc.tr.editTrackerByIndex(t.trId!, tid, urls.first);
          } else {
            await sc.tr.editTracker(<int>[t.trId!], tid, urls.first);
          }
          AppLog.instance.op('修改 Tracker：$original → ${_oneLine(urls.first)}'
              '（${t.name} · ${s.name}）',
              scope: s.logScope);
          Formatter.showToast('${S.trkEditOk}${t.name}');
        } else {
          if (byList) {
            await sc.tr.addTrackersByList(t.trId!, urls);
          } else {
            await sc.tr.addTrackers(<int>[t.trId!], urls);
          }
          AppLog.instance.op('添加 Tracker：${_oneLine(result)}'
              '（${t.name} · ${s.name}）',
              scope: s.logScope);
          Formatter.showToast('${S.trkAddOk}${t.name}');
        }
      }
      await ctrl.loadDetailData();
    } catch (e) {
      AppLog.instance.error('Tracker 操作失败（${editing ? '修改' : '添加'}）：'
          '${_oneLine(result)} · ${Formatter.safeErr(e)}',
          scope: s.logScope);
      Formatter.showToast('${S.trkParseFailed}${Formatter.safeErr(e)}', isError: true);
    }
  }

  String _oneLine(String v) => v
      .split('\n')
      .map((String e) => e.trim())
      .where((String e) => e.isNotEmpty)
      .join(' | ');

  Future<void> _removeTracker(
    BuildContext context,
    TorrentController ctrl,
    ServerController sc,
    String url,
  ) async {
    final s = sc.current.value;
    final t = ctrl.current.value;
    if (s == null || t == null) return;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('${S.trkDeleteTitle}${t.name}）',
            style: TextStyle(fontSize: af(context, 14))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(S.trkDeleteHelp, style: TextStyle(fontSize: af(context, 11))),
            SizedBox(height: af(context, 8)),
            Text(url, style: TextStyle(fontSize: af(context, 10))),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.trkDoDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      if (s.isQbittorrent) {
        await sc.qb.removeTracker(t.hash, url);
      } else {
        final int? tid = _trackerIdOf(ctrl, url);
        if (tid == null || t.trId == null) {
          Formatter.showToast('${S.trkDelNotFound}$url', isError: true);
          return;
        }

        if (ctrl.capabilities.trackerList) {
          await sc.tr.removeTrackerByIndex(t.trId!, tid);
        } else {
          await sc.tr.removeTracker(<int>[t.trId!], <int>[tid]);
        }
      }
      AppLog.instance.op('删除 Tracker：$url（${t.name} · ${s.name}）',
          scope: s.logScope);
      Formatter.showToast('${S.trkDelOk}${t.name}');
      await ctrl.loadDetailData();
    } catch (e) {
      AppLog.instance.error('删除 Tracker 失败：$url · ${Formatter.safeErr(e)}',
          scope: s.logScope);
      Formatter.showToast('${S.trkDelNotFound}$url', isError: true);
    }
  }

  int? _trackerIdOf(TorrentController ctrl, String url) {
    for (final Map<String, dynamic> m in ctrl.trackers) {
      if (m['announce']?.toString() == url || m['url']?.toString() == url) {
        return (m['id'] as num?)?.toInt();
      }
    }
    return null;
  }
}

class _TrackerBarChart extends StatelessWidget {
  const _TrackerBarChart({required this.trackers});

  final List<Map<String, dynamic>> trackers;

  double _v(Map<String, dynamic> t, List<String> keys) {
    for (final String k in keys) {
      final num? v = t[k] as num?;
      if (v != null) return v.toDouble();
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = AppTheme.chartColors(Theme.of(context).colorScheme);
    final List<Map<String, dynamic>> data = trackers.take(6).toList();
    double maxY = 1;
    for (final Map<String, dynamic> t in data) {
      final double s = _v(t, <String>['num_seeds', 'seederCount']);
      final double l = _v(t, <String>['num_leeches', 'leecherCount']);
      if (s > maxY) maxY = s;
      if (l > maxY) maxY = l;
    }

    return BarChart(
      BarChartData(
        maxY: maxY * 1.2,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(enabled: true),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 30),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barGroups: <BarChartGroupData>[
          for (int i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: _v(data[i], <String>['num_seeds', 'seederCount']),
                  color: colors[0],
                  width: 8,
                  borderRadius: BorderRadius.circular(AppTheme.radiusBar),
                ),
                BarChartRodData(
                  toY: _v(data[i], <String>['num_leeches', 'leecherCount']),
                  color: colors[2],
                  width: 8,
                  borderRadius: BorderRadius.circular(AppTheme.radiusBar),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
