import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../controllers/torrent_controller.dart';
import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../utils/i18n.dart';
import '../utils/strings.dart';
import '../app/adaptive.dart';

class TorrentInfoFilesPage extends StatefulWidget {
  const TorrentInfoFilesPage({super.key});

  @override
  State<TorrentInfoFilesPage> createState() => _TorrentInfoFilesPageState();
}

enum FilePrio {
  skip(0, 0),
  normal(1, 0),
  high(6, 1),
  maximal(7, 1);

  const FilePrio(this.value, this.trValue);

  final int value;
  final int trValue;

  bool get trSupported => this != FilePrio.maximal;

  String get label => switch (this) {
        FilePrio.skip => L.t('跳过'),
        FilePrio.normal => L.t('普通'),
        FilePrio.high => L.t('高'),
        FilePrio.maximal => L.t('最高'),
      };
}

enum FileSort { tree, size, progress }

class _TorrentInfoFilesPageState extends State<TorrentInfoFilesPage> {
  final TorrentController ctrl = Get.find<TorrentController>();
  final ServerController sc = Get.find<ServerController>();

  final Set<String> _selected = <String>{};

  FileSort _sort = FileSort.tree;

  bool get _isQb => sc.current.value?.isQbittorrent == true;

  bool get _isTr => sc.current.value?.isTransmission == true;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.detailLoading.value && ctrl.files.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (ctrl.files.isEmpty) {
        return Center(
          child: Text('暂无文件', style: TextStyle(fontSize: af(context, 12))),
        );
      }
      final List<FileNode> tree = _sortedTree;
      return Column(
        children: <Widget>[
          _summaryBar(),
          _sortBar(),
          if (_selected.isNotEmpty) _prioBar(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(af(context, 10), 2, af(context, 10), af(context, 24)),
              children: <Widget>[
                _tree(nodes: tree, depth: 0),
              ],
            ),
          ),
        ],
      );
    });
  }

  // ─────────────────────────── 汇总与排序 ───────────────────────────

  Widget _summaryBar() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    int count = 0;
    int total = 0;
    double done = 0;
    for (final Map<String, dynamic> f in ctrl.files) {
      count++;
      final int sz = (f['size'] ?? f['length'] ?? 0) as int;
      final double pr = ((f['progress'] ?? 0) as num?)?.toDouble() ?? 0;
      total += sz;
      done += sz * pr;
    }
    final double pct = total <= 0 ? 0 : done / total;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(af(context, 10), af(context, 8), af(context, 10), 0),
      padding: EdgeInsets.symmetric(horizontal: af(context, 10), vertical: af(context, 7)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.75), width: 0.6),
      ),
      child: Text.rich(
        TextSpan(
          text: '$count 个文件',
          style: TextStyle(fontSize: af(context, 11), fontWeight: FontWeight.w600),
          children: <TextSpan>[
            TextSpan(
              text: ' · ${Formatter.setSize(total)} · 已完成 ',
              style: TextStyle(
                  fontSize: af(context, 10.5),
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant),
            ),
            TextSpan(
              text: '${Formatter.setSize(done.round())}（${Formatter.setProgress(pct)}）',
              style: TextStyle(
                fontSize: af(context, 10.5),
                color: const Color(0xFF0F9D58),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _sortBar() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(af(context, 10), af(context, 6), af(context, 10), 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            '排序',
            style: TextStyle(fontSize: af(context, 10), color: cs.outline),
          ),
          for (final FileSort s in FileSort.values)
            ChoiceChip(
              label: Text(_sortLabel(s), style: TextStyle(fontSize: af(context, 10.5))),
              selected: _sort == s,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _sort = s),
            ),
        ],
      ),
    );
  }

  String _sortLabel(FileSort s) {
    switch (s) {
      case FileSort.tree:
        return '默认';
      case FileSort.size:
        return '按大小';
      case FileSort.progress:
        return '按进度';
    }
  }

  List<FileNode> get _sortedTree {
    final List<Map<String, dynamic>> raw =
        List<Map<String, dynamic>>.of(ctrl.files);
    if (_sort != FileSort.tree) {
      int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
        switch (_sort) {
          case FileSort.size:
            return ((b['size'] ?? b['length'] ?? 0) as num)
                .compareTo((a['size'] ?? a['length'] ?? 0) as num);
          case FileSort.progress:
            final double pa = ((a['progress'] ?? 0) as num?)?.toDouble() ?? 0;
            final double pb = ((b['progress'] ?? 0) as num?)?.toDouble() ?? 0;
            return pa.compareTo(pb);
          default:
            return 0;
        }
      }

      raw.sort(cmp);
    }
    final List<FileNode> tree = buildFileTree(raw);
    _sortNodes(tree);
    return tree;
  }

  void _sortNodes(List<FileNode> nodes) {
    if (_sort == FileSort.tree) return;
    nodes.sort((FileNode a, FileNode b) {
      if (_sort == FileSort.size) return b.size.compareTo(a.size);
      return a.progress.compareTo(b.progress);
    });
    for (final FileNode n in nodes) {
      if (!n.isFile) _sortNodes(n.children);
    }
  }

  // ─────────────────────────── 批量优先级 ───────────────────────────

  Widget _prioBar() {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: EdgeInsets.fromLTRB(af(context, 8), 4, af(context, 8), 4),
        child: Row(
          children: <Widget>[
            Text(
              S.countLabel(_selected.length),
              style: TextStyle(fontSize: af(context, 11)),
            ),
            SizedBox(width: af(context, 8)),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (final FilePrio p in FilePrio.values)
                      if (!_isTr || p.trSupported)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ActionChip(
                            label: Text(p.label,
                                style: TextStyle(fontSize: af(context, 10))),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _applyPrio(p),
                          ),
                        ),
                    ActionChip(
                      avatar: Icon(Icons.clear_all, size: af(context, 14)),
                      label: Text('取消选择',
                          style: TextStyle(fontSize: af(context, 10))),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(_selected.clear),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyPrio(FilePrio p) async {
    final s = sc.current.value;
    final t = ctrl.current.value;
    if (s == null || t == null) return;
    final Map<String, int> idx = _indexByPath;
    final List<String> ids = _selected
        .map((String path) => idx[path])
        .whereType<int>()
        .map((int i) => '$i')
        .toList();
    if (ids.isEmpty) return;
    final List<int> indexes = ids.map(int.parse).toList();
    try {
      if (s.isQbittorrent) {
        await sc.qb.filePrio(t.hash, ids.join('|'), p.value);
      } else {
        if (t.trId == null) {
          Formatter.showToast(S.noTrId, isError: true);
          return;
        }
        final int trId = t.trId!;
        if (p == FilePrio.skip) {
          await sc.tr.setFilesWanted(<int>[trId], indexes, wanted: false);
        } else {
          await sc.tr.setFilesWanted(<int>[trId], indexes, wanted: true);
          await sc.tr.filePrio(<int>[trId], indexes, p.trValue);
        }
      }
      AppLog.instance.op('设置文件优先级：${p.label} ｜ ${ids.length} 个文件'
          '（${t.name} · ${s.name}）',
          scope: s.logScope);
      Formatter.showToast('${S.tFilePrioOk}${t.name}');
    } catch (e) {
      Formatter.showToast('${S.execFailed}: ${Formatter.safeErr(e)}', isError: true);
    }
  }

  Map<String, int> get _indexByPath {
    final Map<String, int> m = <String, int>{};
    for (int i = 0; i < ctrl.files.length; i++) {
      final String p = (ctrl.files[i]['name'] ?? '').toString();
      if (p.isNotEmpty) m[p] = i;
    }
    return m;
  }

  // ─────────────────────────── 优先级徽章 ───────────────────────────

  String? _prioBadgeOf(Map<String, dynamic> f) {
    if (_isQb) {
      final int pr = (f['priority'] as num?)?.toInt() ?? 1;
      switch (pr) {
        case 0:
          return '跳过';
        case 6:
          return '高';
        case 7:
          return '最高';
        default:
          return null;
      }
    }
    if (f['wanted'] == false) return '跳过';
    final int pr = (f['priority'] as num?)?.toInt() ?? 0;
    switch (pr) {
      case 1:
        return '高';
      case -1:
        return '低';
      default:
        return null;
    }
  }

  Color _prioBadgeColor(String badge, ColorScheme cs) {
    switch (badge) {
      case '跳过':
        return cs.outline;
      case '高':
      case '最高':
        return cs.primary;
      default:
        return cs.onSurfaceVariant;
    }
  }

  Widget _prioBadge(Map<String, dynamic> f, ColorScheme cs) {
    final String? badge = _prioBadgeOf(f);
    if (badge == null) return const SizedBox.shrink();
    final Color c = _prioBadgeColor(badge, cs);
    return Container(
      margin: const EdgeInsets.only(left: 5),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        badge,
        style: TextStyle(
          fontSize: af(context, 8.5),
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }

  // ─────────────────────────── 重命名 ───────────────────────────

  Future<void> _renameNode(FileNode n) async {
    final s = sc.current.value;
    final t = ctrl.current.value;
    if (s == null || t == null) return;
    if (!ctrl.capabilities.renameFile) {
      Formatter.showToast('当前服务器版本不支持文件重命名', isError: true);
      return;
    }

    final TextEditingController input = TextEditingController(text: n.name);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(
          n.isFile ? '重命名文件' : '重命名文件夹',
          style: TextStyle(fontSize: af(context, 14)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              n.path,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: af(context, 10), color: Theme.of(ctx).hintColor),
            ),
            SizedBox(height: af(context, 8)),
            TextField(
              controller: input,
              style: TextStyle(fontSize: af(context, 11)),
              decoration: const InputDecoration(
                labelText: '新名称',
                border: OutlineInputBorder(),
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
            onPressed: () {
              final String v = input.text.trim();
              Navigator.of(ctx).pop(v.isEmpty || v == n.name ? null : v);
            },
            child: Text(S.confirmExecute),
          ),
        ],
      ),
    ).whenComplete(input.dispose);
    if (result == null) return;

    await ctrl.renameInTorrent(t, n.path, result, isFolder: !n.isFile);
    if (ctrl.lastActionOk.value == true) {
      if (mounted) Formatter.showToast('已重命名');
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        ctrl.loadDetailData();
      });
    } else {
      if (mounted) {
        Formatter.showToast('${S.execFailed}: ${ctrl.error.value ?? ''}',
            isError: true);
      }
    }
  }

  Widget? _nodeMenu(FileNode n, ColorScheme cs) {
    if (!ctrl.capabilities.renameFile) return null;
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(Icons.more_horiz, size: af(context, 15), color: cs.onSurfaceVariant),
      onSelected: (String v) {
        if (v == 'rename') _renameNode(n);
      },
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'rename',
          height: af(context, 36),
          child: Text('重命名', style: TextStyle(fontSize: af(context, 11))),
        ),
      ],
    );
  }

  // ─────────────────────────── 树 ───────────────────────────

  Widget _tree({required List<FileNode> nodes, required int depth}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final FileNode n in nodes)
          if (n.isFile) _fileRow(n, depth) else _folderRow(n, depth),
      ],
    );
  }

  Widget _fileRow(FileNode n, int depth) {
    final bool checked = _selected.contains(n.path);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Map<String, dynamic>? raw = _rawOf(n.path);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(left: af(context, 8.0) + depth * af(context, 14), right: af(context, 4)),
      leading: SizedBox(
        width: af(context, 56),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Formatter.iconExtension(n.name),
                size: AppTheme.iconSize),
            Checkbox(
              value: checked,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => setState(() {
                if (checked) {
                  _selected.remove(n.path);
                } else {
                  _selected.add(n.path);
                }
              }),
            ),
          ],
        ),
      ),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              n.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: af(context, 11)),
            ),
          ),
          if (raw != null) _prioBadge(raw, cs),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: n.progress.clamp(0.0, 1.0),
            minHeight: 3,
          ),
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Text(
                '${Formatter.setSize(n.size)} · ${Formatter.setProgress(n.progress)}',
                style: TextStyle(fontSize: af(context, 9)),
              ),
              if (_isQb && raw != null)
                Builder(builder: (BuildContext c2) {
                  final double avail =
                      ((raw['availability'] ?? 0) as num?)?.toDouble() ?? 0;
                  if (avail <= 0) return const SizedBox.shrink();
                  return Expanded(
                    child: Text(
                      '副本 $avail',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: af(context, 9), color: cs.outline),
                    ),
                  );
                }),
            ],
          ),
        ],
      ),
      trailing: _nodeMenu(n, cs),
    );
  }

  Map<String, dynamic>? _rawOf(String path) {
    for (final Map<String, dynamic> f in ctrl.files) {
      if ((f['name'] ?? '').toString() == path) return f;
    }
    return null;
  }

  Widget _folderRow(FileNode n, int depth) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<String> leaves = _leafPaths(n);
    final int hit = leaves.where(_selected.contains).length;
    final bool? tri = hit == 0
        ? false
        : (hit == leaves.length ? true : null);
    final (int size, double progress) agg = _agg(n);

    return ExpansionTile(
        clipBehavior: Clip.antiAlias,
      dense: true,
      initiallyExpanded: depth == 0,
      tilePadding: EdgeInsets.only(left: af(context, 8.0) + depth * af(context, 14), right: af(context, 4)),
      leading: SizedBox(
        width: af(context, 56),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.folder, size: AppTheme.iconSize),
            Checkbox(
              tristate: true,
              value: tri,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => setState(() => _toggleFolder(n)),
            ),
          ],
        ),
      ),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              n.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: af(context, 11)),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: agg.$2.clamp(0.0, 1.0),
            minHeight: 3,
          ),
          const SizedBox(height: 2),
          Text(
            '${agg.$1 == 0 ? '' : Formatter.setSize(agg.$1)} · '
            '${Formatter.setProgress(agg.$2)} · '
            '${n.children.length} 项',
            style: TextStyle(fontSize: af(context, 9)),
          ),
        ],
      ),
      trailing: _nodeMenu(n, cs),
      children: <Widget>[_tree(nodes: n.children, depth: depth + 1)],
    );
  }

  void _toggleFolder(FileNode n) {
    final List<String> leaves = _leafPaths(n);
    final bool allSelected = leaves.every(_selected.contains);
    if (allSelected) {
      _selected.removeAll(leaves);
    } else {
      _selected.addAll(leaves);
    }
  }

  List<String> _leafPaths(FileNode n) {
    if (n.isFile) return <String>[n.path];
    final List<String> out = <String>[];
    for (final FileNode c in n.children) {
      out.addAll(_leafPaths(c));
    }
    return out;
  }

  (int, double) _agg(FileNode n) {
    if (n.isFile) return (n.size, n.progress);
    int size = 0;
    double done = 0;
    for (final FileNode c in n.children) {
      final (int cs, double cp) = _agg(c);
      size += cs;
      done += cs * cp;
    }
    return (size, size == 0 ? 0 : done / size);
  }
}
