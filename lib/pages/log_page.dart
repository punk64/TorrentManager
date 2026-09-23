import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../data/models/server_data.dart';
import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../utils/log_export.dart';
import '../utils/strings.dart';
import '../widgets/log_selection.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  bool _privacy = true;

  static const int _kMaskCacheMax = 500;
  final Map<String, String> _maskCache = <String, String>{};

  bool _selecting = false;

  final Set<LogEntry> _selected = <LogEntry>{};

  final Set<String> _srvFilter = <String>{};

  bool _hideSystem = false;

  bool get _filterActive => _srvFilter.isNotEmpty || _hideSystem;

  String _display(String raw) {
    if (!_privacy) return raw;
    final String? hit = _maskCache[raw];
    if (hit != null) return hit;
    if (_maskCache.length >= _kMaskCacheMax) _maskCache.clear();
    final String masked = Formatter.maskLogText(raw);
    _maskCache[raw] = masked;
    return masked;
  }

  (String, Color) _levelOf(String level, ColorScheme cs) {
    switch (level) {
      case 'ERROR':
        return (S.error, cs.error);
      case 'WARN':
        return (S.warning, Colors.orange);
      case 'CRITICAL':
        return (S.severe, cs.error);
      default:
        return (S.info, cs.primary);
    }
  }

  LogLine _line(LogEntry e, ColorScheme cs) =>
      appLogLine(e, _levelOf(e.level, cs).$1, _privacy);

  List<LogEntry> _visible() => AppLog.instance.entries
      .where((LogEntry e) => AppLog.passScopeFilter(e,
          selected: _srvFilter, hideSystem: _hideSystem))
      .toList();

  int _countOf(String id) =>
      AppLog.instance.entries.where((LogEntry e) => e.serverId == id).length;

  List<_SrvOption> _candidates(ServerController sc) {
    final Map<String, _SrvOption> m = <String, _SrvOption>{};
    for (final ServerData s in sc.servers) {
      m[s.id] = _SrvOption(
        s.logScope,
        s.isTransmission ? 'Transmission' : 'qBittorrent',
      );
    }
    for (final LogEntry e in AppLog.instance.entries) {
      final LogScope? s = e.scope;

      if (s != null) m.putIfAbsent(s.id, () => _SrvOption(s, ''));
    }
    return m.values.toList();
  }

  String _summary(List<_SrvOption> opts) {
    final List<String> names = <String>[
      for (final _SrvOption o in opts)
        if (_srvFilter.contains(o.scope.id)) o.scope.name,

      for (final String id in _srvFilter)
        if (!opts.any((_SrvOption o) => o.scope.id == id)) id,
    ];
    return <String>[
      if (names.isNotEmpty) S.logFilterSummary(names.join('、')),
      if (_hideSystem) S.logFilterSummaryHideSystem,
    ].join(' · ');
  }

  void _resetFilter() => setState(() {
        _srvFilter.clear();
        _hideSystem = false;
      });

  Future<void> _openFilterSheet(ServerController sc) async {
    final List<_SrvOption> opts = _candidates(sc);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheet) {
          void bump(VoidCallback mutate) {
            setState(mutate);
            setSheet(() {});
          }

          final ColorScheme cs = Theme.of(ctx).colorScheme;
          return SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                  child: Row(
                    children: <Widget>[
                      Text(S.logFilterTitle,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton(

                        onPressed: _filterActive
                            ? () => bump(() {
                                  _srvFilter.clear();
                                  _hideSystem = false;
                                })
                            : null,
                        child: Text(S.logFilterReset,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                CheckboxListTile(
                  dense: true,
                  value: _hideSystem,
                  onChanged: (bool? v) => bump(() => _hideSystem = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(S.logFilterHideSystem,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(S.logFilterHideSystemHint,
                      style: const TextStyle(fontSize: 10, height: 1.35)),
                ),
                const Divider(height: 1),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                  child: Row(
                    children: <Widget>[
                      Text(S.logFilterServerSection,
                          style: TextStyle(fontSize: 10, color: cs.outline)),
                      const Spacer(),
                      Text(S.logFilterNoneHint,
                          style: TextStyle(fontSize: 10, color: cs.outline)),
                    ],
                  ),
                ),

                if (opts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Text(S.logFilterNoServer,
                        style: TextStyle(fontSize: 12, color: cs.outline)),
                  )
                else

                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.38,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: opts.length,
                      itemBuilder: (BuildContext c, int i) {
                        final _SrvOption o = opts[i];
                        return CheckboxListTile(
                          dense: true,
                          value: _srvFilter.contains(o.scope.id),
                          onChanged: (bool? v) => bump(() {
                            if (v == true) {
                              _srvFilter.add(o.scope.id);
                            } else {
                              _srvFilter.remove(o.scope.id);
                            }
                          }),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(o.scope.name,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            <String>[
                              if (o.kind.isNotEmpty) o.kind,
                              S.logFilterCount(_countOf(o.scope.id)),
                            ].join(' · '),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),

                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: opts.isEmpty
                            ? null
                            : () => bump(() => _srvFilter
                                  ..clear()
                                  ..addAll(opts
                                      .map((_SrvOption o) => o.scope.id))),
                        child: Text(S.logSelectAll,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: opts.isEmpty
                            ? null
                            : () => bump(() {
                                  for (final _SrvOption o in opts) {
                                    if (!_srvFilter.remove(o.scope.id)) {
                                      _srvFilter.add(o.scope.id);
                                    }
                                  }
                                }),
                        child: Text(S.logInvert,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(S.logFilterDone,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filterChip(ColorScheme cs, List<_SrvOption> opts,
          VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.filter_alt, size: 11, color: cs.primary),
              const SizedBox(width: 3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  _summary(opts),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: cs.primary),
                ),
              ),
            ],
          ),
        ),
      );

  void _enterSelection(LogEntry first) => setState(() {
        _selecting = true;
        _selected
          ..clear()
          ..add(first);
      });

  void _exitSelection() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  void _toggle(LogEntry e) => setState(() {
        if (!_selected.remove(e)) _selected.add(e);
      });

  void _toggleAll(List<LogEntry> all) => setState(() {
        if (all.isNotEmpty && _selected.length == all.length) {
          _selected.clear();
        } else {
          _selected
            ..clear()
            ..addAll(all);
        }
      });

  void _invert(List<LogEntry> all) => setState(() {
        final Set<LogEntry> next =
            all.where((LogEntry e) => !_selected.contains(e)).toSet();
        _selected
          ..clear()
          ..addAll(next);
      });

  List<LogLine> _selectedLines(ColorScheme cs) => AppLog.instance.entries
      .where(_selected.contains)
      .map((LogEntry e) => _line(e, cs))
      .toList();

  Future<void> _copy(ColorScheme cs) async {
    await copyLogLines(_selectedLines(cs));
    if (mounted) _exitSelection();
  }

  Future<void> _exportSelected(ColorScheme cs) async {
    final bool ok = await exportLogLines(
      context,
      lines: _selectedLines(cs),
      masked: _privacy,
    );
    if (ok && mounted) _exitSelection();
  }

  Future<void> _exportAll(ColorScheme cs) async {
    final List<LogLine> all =
        _visible().map((LogEntry e) => _line(e, cs)).toList();
    final bool ok = await exportLogLines(context, lines: all, masked: _privacy);
    if (ok && mounted) _exitSelection();
  }

  void _showDetail(LogEntry e, ColorScheme cs) {
    final (String label, Color color) = _levelOf(e.level, cs);
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Row(
          children: <Widget>[
            Icon(Icons.circle, size: 9, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SelectableText(
                _display(e.message),
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 10),
              Text(
                '${e.formattedTime} · ${e.source}',
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () async {
              await copyLogLines(<LogLine>[_line(e, cs)]);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
            },
            child: const Text('复制全文', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _clearAll() {
    final AppLog log = AppLog.instance;
    log.clear();
    _maskCache.clear(); 

    log.op('清空应用日志');
    _exitSelection();
  }

  @override
  Widget build(BuildContext context) {
    final ServerController sc = Get.find<ServerController>();
    final AppLog log = AppLog.instance;
    final ColorScheme cs = Theme.of(context).colorScheme;

    final List<LogEntry> vis = _visible();

    final List<_SrvOption> opts =
        _filterActive ? _candidates(sc) : const <_SrvOption>[];

    return PopScope(

      canPop: !_selecting,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) return;
        _exitSelection();
      },
      child: Scaffold(
        appBar: _selecting
            ? LogSelectionAppBar(
                count: _selected.length,

                allSelected: vis.isNotEmpty && vis.every(_selected.contains),
                onClose: _exitSelection,
                onToggleAll: () => _toggleAll(vis),
              )
            : AppBar(
                title: const Text('日志', style: TextStyle(fontSize: 15)),
                actions: <Widget>[

                  IconButton(
                    icon: Icon(
                      _privacy ? Icons.visibility_off : Icons.visibility,
                      size: AppTheme.iconSize,
                    ),
                    tooltip: '隐私模式（隐藏域名 / IP / 端口）',
                    onPressed: () => setState(() => _privacy = !_privacy),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: AppTheme.iconSize),
                    tooltip: S.logRefreshed,
                    onPressed: () {
                      log.info(S.logRefreshed);
                      Formatter.showToast(S.logRefreshed);
                    },
                  ),

                  IconButton(
                    icon: Badge.count(
                      count: _srvFilter.length,
                      isLabelVisible: _srvFilter.isNotEmpty,
                      child: Icon(
                        _filterActive
                            ? Icons.filter_alt
                            : Icons.filter_alt_outlined,
                        size: AppTheme.iconSize,
                      ),
                    ),
                    tooltip: S.logFilterEntry,
                    onPressed: () => _openFilterSheet(sc),
                  ),

                  PopupMenuButton<String>(
                    tooltip: '',
                    icon: const Icon(Icons.more_vert, size: AppTheme.iconSize),
                    onSelected: (String v) {
                      switch (v) {
                        case 'select':
                          setState(() {
                            _selecting = true;
                            _selected.clear();
                          });
                          break;
                        case 'clear':
                          _clearAll();
                          break;
                      }
                    },
                    itemBuilder: (BuildContext ctx) =>
                        <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'select',
                        child: Text(S.logSelectMode,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      PopupMenuItem<String>(
                        value: 'clear',
                        child:
                            Text(S.logClear, style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
        bottomNavigationBar: _selecting
            ? LogSelectionBar(
                count: _selected.length,
                onCopy: () => _copy(cs),
                onExportSelected: () => _exportSelected(cs),

                onInvert: () => _invert(vis),
                onExportAll: () => _exportAll(cs),
                onClear: _clearAll,

                exportAllLabel: _filterActive ? S.logExportFiltered : null,
              )
            : null,
        body: Column(
          children: <Widget>[
            Obx(
              () => ListTile(
                dense: true,

                leading: Image.asset(
                  sc.current.value?.isTransmission == true
                      ? 'assets/images/transmission.png'
                      : 'assets/images/qbittorrent.png',
                  width: 22,
                  height: 22,
                ),
                title: const Text('服务器日志', style: TextStyle(fontSize: 12)),
                subtitle: Text(
                  sc.current.value == null
                      ? '选择一台服务器后查看它的服务器日志'
                      : sc.current.value!.isTransmission
                          ? 'Transmission 会话诊断（RPC 不提供日志接口）'
                          : 'GET /api/v2/log/main',
                  style: const TextStyle(fontSize: 10),
                ),
                trailing:
                    const Icon(Icons.chevron_right, size: AppTheme.iconSize),

                onTap: () => Get.toNamed(Routes.logQb,
                    arguments: sc.current.value),
              ),
            ),
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 3),
              child: Row(
                children: <Widget>[
                  const Text('应用日志', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 6),
                  Obx(() => Text(

                        _filterActive
                            ? '${_visible().length}/${log.entries.length}'
                            : '${log.entries.length}/${AppLog.maxEntries}',
                        style: const TextStyle(fontSize: 10),
                      )),
                  const Spacer(),

                  if (_filterActive)
                    _filterChip(cs, opts, () => _openFilterSheet(sc)),
                ],
              ),
            ),

            Expanded(
              child: Obx(() {
                final List<LogEntry> rows = _visible();

                if (log.entries.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        '暂无日志记录。应用内的操作提示、网络请求与异常'
                        '会自动记在这里（服务器日志见上方入口）。',
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            S.logFilterEmpty,
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _resetFilter,
                            child: Text(
                              S.logFilterResetAction,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(

                  padding: EdgeInsets.only(
                    bottom: _selecting ? LogSelectionBar.listBottomPadding : 0,
                  ),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int i) {
                    final LogEntry e = rows[i];
                    final (String label, Color c) = _levelOf(e.level, cs);
                    final bool checked = _selected.contains(e);
                    return ListTile(
                      dense: true,
                      selected: _selecting && checked,

                      selectedTileColor: cs.primary.withValues(alpha: 0.08),
                      leading: SizedBox(
                        width: 20,
                        height: 20,
                        child: _selecting
                            ? Checkbox(
                                value: checked,
                                onChanged: (_) => _toggle(e),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              )
                            : Center(
                                child: Icon(Icons.circle, size: 9, color: c),
                              ),
                      ),
                      title: Text(

                        _display(e.message),

                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                      subtitle: Text(
                        '${e.formattedTime} · $label · ${e.source}',
                        style: const TextStyle(fontSize: 9),
                      ),
                      onTap: _selecting ? () => _toggle(e) : () => _showDetail(e, cs),
                      onLongPress: () => _enterSelection(e),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _SrvOption {
  const _SrvOption(this.scope, this.kind);

  final LogScope scope;

  final String kind;
}
