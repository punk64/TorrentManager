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

class _TorrentInfoFilesPageState extends State<TorrentInfoFilesPage> {
  final TorrentController ctrl = Get.find<TorrentController>();
  final ServerController sc = Get.find<ServerController>();

  final Set<String> _selected = <String>{};

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
      final List<FileNode> tree = ctrl.fileTree;
      return Column(
        children: <Widget>[
          if (_selected.isNotEmpty) _prioBar(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(bottom: af(context, 24)),
              children: <Widget>[
                _tree(nodes: tree, depth: 0),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _prioBar() {
    final bool isTr = sc.current.value?.isTransmission == true;
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
                      if (!isTr || p.trSupported)
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
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(left: af(context, 8.0) + depth * af(context, 14), right: af(context, 8)),
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
      title: Text(
        n.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: af(context, 11)),
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
          Text(
            '${Formatter.setSize(n.size)} · ${Formatter.setProgress(n.progress)}',
            style: TextStyle(fontSize: af(context, 9)),
          ),
        ],
      ),
    );
  }

  Widget _folderRow(FileNode n, int depth) {
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
      tilePadding: EdgeInsets.only(left: af(context, 8.0) + depth * af(context, 14), right: af(context, 8)),
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
      title: Text(
        n.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: af(context, 11)),
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
