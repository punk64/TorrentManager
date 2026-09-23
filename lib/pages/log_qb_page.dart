import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../data/models/qb_log.dart';
import '../data/models/server_data.dart';
import '../data/qbittorrent/qb_method.dart';
import '../data/transmission/tr_method.dart';
import '../utils/formatter.dart';
import '../utils/log_export.dart';
import '../utils/net_error.dart';
import '../utils/strings.dart';
import '../widgets/auto_refresh.dart';
import '../widgets/log_selection.dart';

class LogQbPage extends StatefulWidget {
  const LogQbPage({super.key});

  @override
  State<LogQbPage> createState() => _LogQbPageState();
}

class _LogQbPageState extends State<LogQbPage> {
  static const Duration kLogPollInterval = Duration(seconds: 10);

  final ServerController sc = Get.find<ServerController>();

  final QbMethod _qb = QbMethod();

  final TrMethod _tr = TrMethod();

  List<(String, String)> _trFacts = <(String, String)>[];

  final List<QbLog> _all = <QbLog>[];
  String? _serverId;
  DateTime? _from;
  DateTime? _to;
  bool _loading = false;
  String? _error;

  int _reqSeq = 0;

  bool _privacy = true;

  static const int _kMaskCacheMax = 500;
  final Map<String, String> _maskCache = <String, String>{};

  String _display(String raw) {
    if (!_privacy) return raw;
    final String? hit = _maskCache[raw];
    if (hit != null) return hit;
    if (_maskCache.length >= _kMaskCacheMax) _maskCache.clear();
    final String masked = Formatter.maskLogText(raw);
    _maskCache[raw] = masked;
    return masked;
  }

  bool _selecting = false;

  final Set<int> _selected = <int>{};

  @override
  void initState() {
    super.initState();

    final dynamic arg = Get.arguments;

    if (arg is ServerData) {
      _serverId = arg.id;
    }
  }

  List<ServerData> get _servers => sc.servers.toList();

  ServerData? get _currentServer {
    final String? id = _serverId;
    if (id == null) return null;
    for (final ServerData s in sc.servers) {
      if (s.id == id) return s;
    }
    return null;
  }

  bool get _isTr => _currentServer?.isTransmission ?? false;

  List<QbLog> get _visible {
    final List<QbLog> list = _all.where((QbLog l) {
      if (_from == null && _to == null) return true;
      final DateTime t =
          DateTime.fromMillisecondsSinceEpoch(l.timestamp * 1000);
      if (_from != null && t.isBefore(_from!)) return false;
      if (_to != null && t.isAfter(_to!)) return false;
      return true;
    }).toList()
      ..sort((QbLog a, QbLog b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _dropStale() {
    _all.clear();
    _trFacts = <(String, String)>[];
  }

  Future<void> _load() async {
    final String? id = _serverId;
    if (id == null) return;
    final int seq = ++_reqSeq;
    ServerData? target;
    for (final ServerData s in sc.servers) {
      if (s.id == id) {
        target = s;
        break;
      }
    }
    if (target == null) return;

    final ServerData srv = target;

    if (!mounted) return;
    setState(() {
      _loading = srv.isTransmission ? _trFacts.isEmpty : _all.isEmpty;
      _error = null;
    });

    if (srv.isTransmission) {
      await _loadTr(srv, seq);
      return;
    }
    try {
      final bool logged = await _qb.checkQbServerCookie(srv);
      if (!logged) {
        if (!mounted || seq != _reqSeq) return;
        setState(() {
          _error = '${S.logQbFetchFailed}登录失败，请检查账号与密码';
          _loading = false;

          _dropStale();
        });
        return;
      }
      final List<QbLog> list = await _qb.getQbLogs();
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _all
          ..clear()
          ..addAll(list);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _error = '${S.logQbFetchFailed}${NetError.describe(e)}';
        _loading = false;

        _dropStale();
      });
    }
  }

  Future<void> _loadTr(ServerData s, int seq) async {
    try {
      final TrLoginResult r = await _tr.checkTrServerCookie(s);
      if (!r.ok) {
        if (!mounted || seq != _reqSeq) return;
        setState(() {
          _error = '${S.logQbFetchFailed}${r.reason ?? '连接失败'}';
          _loading = false;

          _dropStale();
        });
        return;
      }
      final Map<String, dynamic> session = await _tr.sessionGet();

      Map<String, dynamic> stats = const <String, dynamic>{};
      try {
        stats = await _tr.updateTrInfo();
      } catch (_) {
        stats = const <String, dynamic>{};
      }
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _trFacts = _trFactsOf(session, stats);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _error = '${S.logQbFetchFailed}${NetError.describe(e)}';
        _loading = false;

        _dropStale();
      });
    }
  }

  List<(String, String)> _trFactsOf(
      Map<String, dynamic> session, Map<String, dynamic> stats) {
    final Map<String, dynamic> cum = stats['cumulative-stats'] is Map
        ? Map<String, dynamic>.from(stats['cumulative-stats'] as Map)
        : const <String, dynamic>{};
    final String version = Formatter.getString(session, 'version');
    return <(String, String)>[
      ('Transmission 版本', version.isEmpty ? '—' : version),
      ('RPC 版本', Formatter.getString(session, 'rpc-version', def: '—')),
      ('种子总数', '${Formatter.getInt(stats, 'torrentCount')}'),
      ('下载中', '${Formatter.getInt(stats, 'activeTorrentCount')}'),
      ('当前下行', Formatter.setSpeed(Formatter.getInt(stats, 'downloadSpeed'))),
      ('当前上行', Formatter.setSpeed(Formatter.getInt(stats, 'uploadSpeed'))),
      ('累计下载', Formatter.setSize(Formatter.getInt(cum, 'downloadedBytes'))),
      ('累计上传', Formatter.setSize(Formatter.getInt(cum, 'uploadedBytes'))),
      (
        '下载目录',
        _display(Formatter.getString(session, 'download-dir', def: '—'))
      ),
    ];
  }

  void _pickRange(String kind) async {
    final DateTime now = DateTime.now();
    switch (kind) {
      case 'today':
        final DateTime d = DateTime(now.year, now.month, now.day);
        setState(() {
          _from = d;
          _to = now;
        });
        return;
      case '7d':
        setState(() {
          _from = DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 6));
          _to = now;
        });
        return;
      case 'custom':
        final DateTimeRange? r = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: now,
          initialDateRange: _from == null
              ? null
              : DateTimeRange(start: _from!, end: _to ?? now),
        );
        if (r == null) return;
        setState(() {
          _from = DateTime(r.start.year, r.start.month, r.start.day);
          _to = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59);
        });
        return;
      default: 
        setState(() {
          _from = null;
          _to = null;
        });
    }
  }

  (String, Color) _level(int type, ColorScheme cs) {
    switch (type) {
      case 3:
        return (S.severe, cs.error);
      case 2:
        return (S.warning, Colors.orange);
      case 1:
        return (S.info, cs.primary);
      default:
        return (S.normal, cs.outline);
    }
  }

  void _enterSelection(QbLog l) => setState(() {
        _selecting = true;
        _selected
          ..clear()
          ..add(l.id);
      });

  void _exitSelection() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  void _toggle(int id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  void _toggleAll() => setState(() {
        final List<QbLog> all = _visible;
        if (all.isNotEmpty && _selected.length == all.length) {
          _selected.clear();
        } else {
          _selected
            ..clear()
            ..addAll(all.map((QbLog l) => l.id));
        }
      });

  void _invert() => setState(() {
        final Set<int> next = <int>{
          for (final QbLog l in _visible)
            if (!_selected.contains(l.id)) l.id,
        };
        _selected
          ..clear()
          ..addAll(next);
      });

  List<LogLine> _selectedLines(ColorScheme cs) => _visible
      .where((QbLog l) => _selected.contains(l.id))
      .map((QbLog l) => qbLogLine(l, _level(l.type, cs).$1, _privacy))
      .toList();

  List<LogLine> _exportRangeLines(ColorScheme cs) {
    final bool filtered = _from != null || _to != null;
    final List<QbLog> src = filtered ? _visible : _all;
    return src
        .map((QbLog l) => qbLogLine(l, _level(l.type, cs).$1, _privacy))
        .toList();
  }

  Future<void> _copy(ColorScheme cs) async {
    await copyLogLines(_selectedLines(cs));
    if (mounted) _exitSelection();
  }

  Future<void> _exportSelected(ColorScheme cs) async {
    final bool ok = await exportLogLines(
      context,
      lines: _selectedLines(cs),
      masked: _privacy,
      kind: 'qb',
    );
    if (ok && mounted) _exitSelection();
  }

  Future<void> _exportRange(ColorScheme cs) async {
    final bool ok = await exportLogLines(
      context,
      lines: _exportRangeLines(cs),
      masked: _privacy,
      kind: 'qb',
    );
    if (ok && mounted) _exitSelection();
  }

  void _clearAll() {
    setState(() {
      _all.clear();

      _trFacts = <(String, String)>[];
      _maskCache.clear(); 
    });
    _exitSelection();
    if (_isTr) _load();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<QbLog> visible = _visible;
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
                allSelected:
                    visible.isNotEmpty && _selected.length == visible.length,
                onClose: _exitSelection,
                onToggleAll: _toggleAll,
              )
            : AppBar(
                title: const Text('服务器日志',
                    style: TextStyle(fontSize: 15)),
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
                    onPressed: () async {
                      await _load();
                      Formatter.showToast(S.logRefreshed);
                    },
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

                      if (!_isTr)
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
                onInvert: _invert,
                onExportAll: () => _exportRange(cs),
                onClear: _clearAll,
              )
            : null,
        body: Column(
          children: <Widget>[

            if (!_selecting) ...<Widget>[
              _picker(cs),
              const Divider(height: 1),
            ],
            Expanded(
              child: AutoRefresh(
                interval: kLogPollInterval,
                onTick: _load,
                child: _body(cs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _picker(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Obx(() {
            final List<ServerData> list = _servers;
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(S.logNoServer,
                    style: TextStyle(fontSize: 11, color: cs.error)),
              );
            }

            final String? value =
                list.any((ServerData s) => s.id == _serverId) ? _serverId : null;

            return DropdownButtonFormField<String>(
              initialValue: value,
              isDense: true,
              isExpanded: true,

              style: TextStyle(fontSize: 13, color: cs.onSurface),

              borderRadius: BorderRadius.circular(AppTheme.radius),

              icon: const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.arrow_drop_down, size: 24),
              ),
              decoration: InputDecoration(
                labelText: '服务器',
                hintText: S.logPickServer,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: list
                  .map((ServerData s) => DropdownMenuItem<String>(
                        value: s.id,
                        child: Text(

                          '${s.name} · ${s.isTransmission ? 'Transmission' : 'qBittorrent'}',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (String? v) {
                setState(() {
                  _serverId = v;
                  _all.clear();
                  _error = null;
                });
                _load();
              },
            );
          }),

          if (!_isTr) ...<Widget>[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: <Widget>[
                _chip(S.logRangeAll, _from == null && _to == null,
                    () => _pickRange('all'), cs),
                _chip(S.logRangeToday, _isToday, () => _pickRange('today'), cs),
                _chip(S.logRange7d, _is7d, () => _pickRange('7d'), cs),
                _chip(S.logRangeCustom, _isCustom, () => _pickRange('custom'), cs),
              ],
            ),
            if (_from != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${S.logRangeHint}：${_fmt(_from!)} ~ ${_fmt(_to ?? DateTime.now())}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
          ],
        ],
      ),
    );
  }

  bool get _isToday {
    if (_from == null) return false;
    final DateTime now = DateTime.now();
    return _fmt(_from!) == _fmt(now) && _to != null;
  }

  bool get _is7d {
    if (_from == null) return false;
    final DateTime now = DateTime.now();
    return _fmt(_from!) ==
        _fmt(DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6)));
  }

  bool get _isCustom =>
      _from != null && !_isToday && !_is7d && _to != null;

  Widget _chip(String label, bool selected, VoidCallback onTap, ColorScheme cs) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => onTap(),

      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _trBody(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.info_outline, size: 15, color: cs.primary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Transmission 的 RPC 不提供服务器日志接口（服务端日志只能去读 '
                  'daemon 的日志文件）。这里显示的是它当前能查到的会话诊断信息，'
                  '每 10 秒随页面刷新。',
                  style: TextStyle(fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ..._trFacts.map(((String, String) f) => ListTile(
              dense: true,
              title: Text(f.$1, style: const TextStyle(fontSize: 11)),
              subtitle: Text(
                f.$2.isEmpty ? '—' : f.$2,
                style: const TextStyle(fontSize: 12),
              ),
            )),
      ],
    );
  }

  Widget _body(ColorScheme cs) {
    if (_serverId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${S.logPickServer}\n${S.logPickServerHint}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      );
    }

    if (_isTr) return _trBody(cs);
    final List<QbLog> list = _visible;
    if (list.isEmpty) {
      return Center(
        child: Text(
          _all.isEmpty ? S.noTraffic : S.logRangeEmpty,
          style: const TextStyle(fontSize: 12),
        ),
      );
    }
    return ListView.separated(

      padding: EdgeInsets.only(
        bottom: _selecting ? LogSelectionBar.listBottomPadding : 0,
      ),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int i) {
        final QbLog log = list[i];
        final (String label, Color color) = _level(log.type, cs);
        final bool checked = _selected.contains(log.id);
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
                    onChanged: (_) => _toggle(log.id),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : Center(child: Icon(Icons.circle, size: 9, color: color)),
          ),
          title: Text(

            _display(log.message),
            style: const TextStyle(fontSize: 11),
          ),
          subtitle: Text(
            '${Formatter.setDate(log.timestamp)} · $label',
            style: const TextStyle(fontSize: 9),
          ),
          onTap: _selecting ? () => _toggle(log.id) : null,
          onLongPress: () => _enterSelection(log),
        );
      },
    );
  }
}
