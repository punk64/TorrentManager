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

class TorrentInfoTrackersPage extends StatelessWidget {
  const TorrentInfoTrackersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TorrentController ctrl = Get.find<TorrentController>();
    final ServerController sc = Get.find<ServerController>();

    return Obx(() {
      if (ctrl.detailLoading.value && ctrl.trackers.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      final List<Map<String, dynamic>> trackers = ctrl.trackers;
      if (trackers.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.asset('assets/images/empty.webp', width: 80),
              const SizedBox(height: 10),
              Text(S.trkNone, style: TextStyle(fontSize: af(context, 12))),
              const SizedBox(height: 12),
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
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          SizedBox(
            height: 180,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 12, 4),
              child: _TrackerBarChart(trackers: trackers),
            ),
          ),
          const Divider(height: 1),
          for (final Map<String, dynamic> t in trackers)
            _trackerTile(context, ctrl, sc, t),
          Padding(
            padding: const EdgeInsets.all(12),
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

  Widget _trackerTile(
    BuildContext context,
    TorrentController ctrl,
    ServerController sc,
    Map<String, dynamic> t,
  ) {
    final String url =
        (t['url'] ?? t['announce'] ?? t['host'])?.toString() ?? '-';
    final String status =
        (t['msg'] ?? t['lastAnnounceResult'])?.toString() ?? '';
    final int seeds =
        ((t['num_seeds'] ?? t['seederCount']) as num?)?.toInt() ?? 0;
    final int leechs =
        ((t['num_leeches'] ?? t['leecherCount']) as num?)?.toInt() ?? 0;
    final String host = Formatter.trackerHost(url) ?? url;

    return ListTile(
      dense: true,
      leading: const Icon(Icons.public, size: AppTheme.iconSize),
      title: Text(
        url,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: af(context, 11)),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '${S.fieldSiteName} $host · '
          '${S.fieldSeeders} $seeds · ${S.fieldLeechers} $leechs'
          '${status.isEmpty ? '' : ' · $status'}',
          style: TextStyle(fontSize: af(context, 10)),
        ),
      ),
      trailing: PopupMenuButton<String>(
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
      ),
    );
  }

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
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
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
