import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../app/page_style.dart';
import '../app/routes.dart';
import '../app/style_keys.dart';
import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/torrent_controller.dart';
import '../data/models/server_data.dart';
import '../data/models/torrent.dart';
import '../data/server_capabilities.dart';
import '../utils/app_log.dart';
import '../utils/file_export.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';
import '../widgets/auto_refresh.dart';
import '../widgets/list_loading_placeholder.dart';
import '../widgets/disk_io_chip.dart';
import '../widgets/draggable_fab.dart';
import '../widgets/slidable_tile.dart';
import '../widgets/sort_filter_panel.dart';
import '../widgets/torrent_edit_fields.dart';
import '../widgets/torrent_edit_sheet.dart';
import 'drawer_page.dart';
import '../app/adaptive.dart';

class TorrentListPage extends StatefulWidget {
  const TorrentListPage({super.key});

  @override
  State<TorrentListPage> createState() => _TorrentListPageState();
}

class _TorrentListPageState extends State<TorrentListPage> {
  final TorrentController ctrl = Get.find<TorrentController>();
  final TextEditingController _search = TextEditingController();

  bool _selecting = false;

  bool _deleteArmed = false;

  Timer? _deleteArmTimer;

  final Set<String> _expanded = <String>{};

  bool _cardBusy = false;

  bool _drawerOpen = false;

  bool _cardOpen = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final Worker _serverWorker;

  final ScrollController _scrollCtl = ScrollController();

  Timer? _scrollIdleTimer;

  bool _scrolling = false;
  static const Duration _kScrollIdle = Duration(milliseconds: 120);

  Timer? _kwTimer;

  static const Duration _kKeywordDebounce = Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();

    ctrl.setListVisible(true);

    _serverWorker = ever<ServerData?>(ctrl.serverCtrl.current, (ServerData? s) {
      if (!mounted || _expanded.isEmpty) return;
      setState(_expanded.clear);
    });

    _scrollCtl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _serverWorker.dispose();
    _scrollIdleTimer?.cancel();
    _kwTimer?.cancel();
    _deleteArmTimer?.cancel();
    _scrollCtl.dispose();

    if (Get.isRegistered<TorrentController>()) {
      ctrl.setScrollPaused(false);
      ctrl.setListVisible(false);
    }
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrolling) {
      _scrolling = true;

      ctrl.setScrollPaused(true);
    }
    _scrollIdleTimer?.cancel();
    _scrollIdleTimer = Timer(_kScrollIdle, () {
      if (!mounted) return;
      _scrolling = false;
      ctrl.setScrollPaused(false);

      unawaited(ctrl.refreshAuto());
    });
  }

  void _onCardSlideChanged(bool open) {
    if (!mounted || _cardOpen == open) return;
    setState(() => _cardOpen = open);
  }

  List<Torrent> get _list => ctrl.visibleItems;

  Color _actColor(MaterialColor ramp) =>
      Theme.of(context).brightness == Brightness.dark
          ? ramp.shade300
          : ramp.shade700;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_cardOpen && !_drawerOpen,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_cardOpen) {
          closeAllSlidables();
          if (mounted) setState(() => _cardOpen = false);
          return;
        }
        if (_drawerOpen) {
          _scaffoldKey.currentState?.closeDrawer();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Scaffold(
            key: _scaffoldKey,
            onDrawerChanged: (bool open) {
              if (mounted) setState(() => _drawerOpen = open);
            },
            appBar: AppBar(
              leading: _selecting
                  ? IconButton(
                      icon: Icon(Icons.close, size: AppTheme.iconSize),
                      onPressed: _exitSelect,
                    )
                  : Builder(
                      builder: (BuildContext ctx) => IconButton(
                        icon: Icon(Icons.menu, size: AppTheme.iconSize),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),

              flexibleSpace: _selecting
                  ? null
                  : Padding(
                      padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.4,
                          ),
                          child: Obx(
                            () => Text(
                              Get.find<ServerController>()
                                      .current
                                      .value
                                      ?.name ??
                                  '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: af(context, 18),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

              title: Align(
                alignment: Alignment.centerLeft,
                child: _selecting
                    ? Obx(() => Text(S.selectedCount(ctrl.selected.length)))
                    : const _SpeedTitle(),
              ),

              actions: <Widget>[
                if (!_selecting) ...<Widget>[
                  Obx(
                    () => IconButton(
                      icon: Icon(
                        ctrl.siteMasked.value
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: AppTheme.iconSize,
                      ),
                      tooltip: '站点打码',
                      onPressed: () {
                        final bool v = ctrl.siteMasked.value;
                        ctrl.setSiteMasked(!v);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ],
            ),
            drawer: const AppDrawer(),
            body: Stack(
              children: <Widget>[
                AutoRefresh(
                  onTick: ctrl.refreshAuto,
                  enabled: !_selecting,
                  child: Obx(() {
                    if (ctrl.isLoading.value && ctrl.items.isEmpty) {
                      return const ListLoadingPlaceholder();
                    }

                    final ServerController sc = Get.find<ServerController>();
                    final ServerData? cur = sc.current.value;
                    final String? why =
                        cur == null ? null : sc.connError[cur.id];
                    final bool suspended =
                        cur != null && sc.isSuspended(cur.id);
                    final bool hasError =
                        ctrl.error.value != null || (suspended && why != null);
                    if (hasError) {
                      final bool authFailed =
                          why != null && why.startsWith('登录失败');
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(af(context, 24)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (suspended)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    S.srvSuspended,
                                    style: TextStyle(
                                        fontSize: af(context, 11), color: Colors.orange),
                                  ),
                                ),
                              Text(
                                '${S.execFailed}\n${ctrl.error.value ?? why}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: af(context, 12)),
                              ),
                              SizedBox(height: af(context, 12)),
                              if (authFailed && cur != null)
                                FilledButton.icon(
                                  onPressed: () => sc.relogin(cur),
                                  icon: Icon(Icons.login, size: af(context, 16)),
                                  label: Text(S.relogin),
                                )
                              else
                                TextButton.icon(
                                  onPressed: () => ctrl.refresh(),
                                  icon: Icon(Icons.refresh, size: af(context, 16)),
                                  label: Text(S.retry),
                                ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: <Widget>[
                        _searchBar(),
                        _filterBar(),
                        if (_selecting) _selectionBar(),
                        if (_selecting) _actionGrid(),
                        Expanded(child: _body(context)),
                      ],
                    );
                  }),
                ),
                Positioned.fill(
                  child: Visibility(
                    visible: !_selecting,
                    maintainState: true,
                    maintainSize: true,
                    maintainAnimation: true,
                    child: DraggableFab(
                      topInset:
                          kToolbarHeight + MediaQuery.of(context).padding.top,
                      initialYRatio: DraggableFab.listPageInitialYRatio,
                      onPressed: () => Get.toNamed(Routes.torrentAdd),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(af(context, 12), af(context, 8), af(context, 12), 3),
      child: TextField(
        controller: _search,
        maxLength: AppTheme.maxLenName,
        buildCounter: AppTheme.noCounter,
        style: TextStyle(fontSize: af(context, 12)),
        decoration: InputDecoration(
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
          prefixIcon: Icon(Icons.search, size: AppTheme.iconSize),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.clear_all, size: AppTheme.iconSize),
                  onPressed: () {
                    _clearKeywordNow();
                    setState(() {});
                  },
                ),
          hintText: S.search,
          hintStyle: TextStyle(fontSize: af(context, 12)),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
        ),
        onChanged: _onKeywordInput,
      ),
    );
  }

  void _onKeywordInput(String v) {
    setState(() {});
    _kwTimer?.cancel();
    _kwTimer = Timer(_kKeywordDebounce, () {
      if (!mounted) return;
      ctrl.setKeyword(v);

      setState(() {});
    });
  }

  void _clearKeywordNow() {
    _kwTimer?.cancel();
    _search.clear();
    ctrl.setKeyword('');
  }

  Widget _filterBar() {
    return SizedBox(
      height: af(context, 40),
      child: Row(
        children: <Widget>[
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(af(context, 10), 0, 4, 0),
              children: <Widget>[

                Obx(() {
                  final bool hasStatus = ctrl.hasStatusFilter;
                  final bool hasKw = ctrl.keyword.value.isNotEmpty;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ActionChip(
                      avatar: Icon(
                        hasStatus
                            ? Icons.filter_alt
                            : (hasKw ? Icons.search : Icons.filter_alt_outlined),
                        size: af(context, 14),
                      ),
                      label: Text(
                        hasStatus
                            ? '${S.filterStatusPrefix}${ctrl.statusSummaryText}'
                            : (hasKw
                                ? '${S.search}: ${ctrl.keyword.value}'
                                : S.filterStatusTitle),
                        style: TextStyle(fontSize: af(context, 11)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => showSortFilterPanel(context),
                    ),
                  );
                }),
                if (ctrl.hasStatusFilter || ctrl.keyword.value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ActionChip(
                      avatar: Icon(Icons.clear_all, size: af(context, 14)),
                      label: Text('清除', style: TextStyle(fontSize: af(context, 11))),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        AppLog.instance.act('种子列表', '筛选[清除]');
                        ctrl.clearStatus();
                        _clearKeywordNow();
                        Formatter.showToast(S.filterCleared);
                        setState(() {});
                      },
                    ),
                  ),
              ],
            ),
          ),

          if (!_selecting)
            Padding(
              padding: EdgeInsets.only(right: af(context, 8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _toolButton(
                    icon: Icons.checklist,
                    label: S.actMultiSelect,
                    onTap: () => setState(() => _selecting = true),
                  ),
                  const SizedBox(width: 6),
                  _toolButton(
                    icon: Icons.tune,
                    label: S.actSortFilter,
                    onTap: () => showSortFilterPanel(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: af(context, 28),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: af(context, 14)),
        label: Text(label, style: TextStyle(fontSize: af(context, 11))),
        style: OutlinedButton.styleFrom(
          backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.92),
          padding: EdgeInsets.symmetric(horizontal: af(context, 8)),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }

  Widget _actionGrid() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int n = ctrl.selected.length;
    final bool empty = ctrl.selected.isEmpty;
    final bool isTr =
        Get.find<ServerController>().current.value?.isTransmission == true;
    final bool canExport = ctrl.capabilities.exportTorrent;

    Widget gap() => const SizedBox(width: 6);

    Widget lastCell() {
      if (isTr) return Expanded(child: _queueMoveButton());
      if (canExport) {
        return Expanded(
          child: _gridButton(
            icon: Icons.download,
            label: S.batchExport,
            onTap: empty ? null : _batchExport,
          ),
        );
      }
      return const Expanded(child: SizedBox.shrink());
    }

    return Container(
      margin: EdgeInsets.fromLTRB(af(context, 8), 0, af(context, 8), 4),
      padding: EdgeInsets.all(af(context, 8)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _gridButton(
                  icon: Icons.play_arrow,
                  label: S.actStart,
                  tint: cs.primary,
                  onTap: () => _runSelected(ctrl.resumeSelected, '开始'),
                ),
              ),
              gap(),
              Expanded(
                child: _gridButton(
                  icon: Icons.pause,
                  label: S.actPause,
                  onTap: () => _runSelected(ctrl.pauseSelected, '暂停'),
                ),
              ),
              gap(),
              Expanded(
                child: _gridButton(
                  icon: Icons.fact_check_outlined,
                  label: S.fieldVerifyState,
                  tint: cs.tertiary,
                  onTap: () => _runSelected(ctrl.recheckSelected, '重新校验'),
                ),
              ),
              gap(),
              Expanded(child: _deleteButton(n)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: _gridButton(
                  icon: Icons.edit_note,
                  label: S.batchEdit,
                  onTap: empty ? null : _batchEdit,
                ),
              ),
              gap(),
              Expanded(
                child: _gridButton(
                  icon: Icons.tag,
                  label: S.copyHash,
                  onTap: empty ? null : _copyHashes,
                ),
              ),
              gap(),
              Expanded(
                child: _gridButton(
                  icon: Icons.link,
                  label: S.copyMagnet,
                  onTap: empty ? null : _copyMagnets,
                ),
              ),
              gap(),
              lastCell(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gridButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? danger,
    bool solid = false,
    Color? tint,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fg =
        danger == null ? (tint ?? cs.onSurface) : (solid ? Colors.white : danger);
    final Color bg = solid
        ? danger!
        : danger != null
            ? danger.withValues(alpha: 0.10)
            : (tint ?? cs.onSurfaceVariant).withValues(alpha: 0.09);
    final Widget content = SizedBox(
      height: af(context, 46),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: af(context, 18), color: fg),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: af(context, 9.5),
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }

  Future<void> _batchEdit() async {
    final List<String> hashes = ctrl.selected.toList();
    if (hashes.isEmpty) return;
    AppLog.instance.act('种子列表', '多选栏[批量编辑]', target: '${hashes.length} 个');
    await TorrentEditSheet.show(hashes);
  }

  Future<void> _copyHashes() async {
    final List<String> hashes = ctrl.selected.toList();
    if (hashes.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: hashes.join('\n')));
    AppLog.instance.act('种子列表', '多选栏[复制哈希]', target: '${hashes.length} 个');
    Formatter.showToast(S.batchCopied(hashes.length, S.fieldHash));
  }

  Future<void> _copyMagnets() async {
    final List<String> magnets = <String>[
      for (final Torrent t in ctrl.items)
        if (ctrl.selected.contains(t.hash) &&
            (t.magnetUri ?? '').trim().isNotEmpty)
          Formatter.maskUrl(t.magnetUri!.trim()),
    ];
    if (magnets.isEmpty) {
      Formatter.showToast(S.batchNoMagnet, isError: true);
      return;
    }
    await Clipboard.setData(ClipboardData(text: magnets.join('\n')));
    AppLog.instance.act('种子列表', '多选栏[复制磁力链]', target: '${magnets.length} 个');
    Formatter.showToast(S.batchCopied(magnets.length, S.fieldMagnet));
  }

  Future<void> _batchExport() async {
    final List<Torrent> list = ctrl.items
        .where((Torrent t) => ctrl.selected.contains(t.hash))
        .toList();
    if (list.isEmpty) return;
    if (!ctrl.capabilities.exportTorrent) {
      Formatter.showToast(S.exportVersionTooOld, isError: true);
      return;
    }
    AppLog.instance.act('种子列表', '多选栏[批量导出]', target: '${list.length} 个');
    final ServerController sc = Get.find<ServerController>();
    int ok = 0;
    int fail = 0;
    for (final Torrent t in list) {
      try {
        final List<int> bytes = await sc.qb.exportTorrent(t.hash);
        if (bytes.isEmpty) {
          fail++;
          continue;
        }
        await FileExport.saveBytesAs(
          fileName: '${Formatter.safeFileName(t.name)}.torrent',
          bytes: Uint8List.fromList(bytes),
          allowedExtensions: const <String>['torrent'],
        );
        ok++;
      } catch (_) {
        fail++;
      }
    }
    if (ok == 0 && fail > 0) {
      Formatter.showToast(S.batchExportNothing, isError: true);
      return;
    }
    Formatter.showToast(
        fail == 0 ? S.batchExportDone(ok, 0) : S.batchExportDone(ok, fail),
        isError: fail > 0);
  }

  Widget _queueMoveButton() {
    return PopupMenuButton<String>(
      onSelected: (String v) =>
          _runSelected(() => ctrl.queueMoveSelected(v), '队列移动:$v'),
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'top',
          child: Text(S.queueMoveTop, style: TextStyle(fontSize: af(context, 13))),
        ),
        PopupMenuItem<String>(
          value: 'up',
          child: Text(S.queueMoveUp, style: TextStyle(fontSize: af(context, 13))),
        ),
        PopupMenuItem<String>(
          value: 'down',
          child: Text(S.queueMoveDown, style: TextStyle(fontSize: af(context, 13))),
        ),
        PopupMenuItem<String>(
          value: 'bottom',
          child: Text(S.queueMoveBottom, style: TextStyle(fontSize: af(context, 13))),
        ),
      ],
      child: _gridButton(
        icon: Icons.reorder,
        label: S.queueMoveTitle,
      ),
    );
  }

  Widget _deleteButton(int n) {
    final Color red = _actColor(Colors.red);
    if (_deleteArmed) {
      return _gridButton(
        icon: Icons.delete_forever,
        label: S.deleteTapAgain(n),
        danger: red,
        solid: true,
        onTap: _onDeleteTapped,
      );
    }
    return _gridButton(
      icon: Icons.delete,
      label: S.delete,
      danger: red,
      onTap: _onDeleteTapped,
    );
  }

  void _onDeleteTapped() {
    if (_deleteArmed) {
      _disarmDelete();
      AppLog.instance
          .act('种子列表', '多选栏[删除]', target: '${ctrl.selected.length} 个');
      _confirmDelete();
      return;
    }
    if (ctrl.selected.isEmpty) return;
    setState(() => _deleteArmed = true);
    _deleteArmTimer?.cancel();
    _deleteArmTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _deleteArmed = false);
    });
  }

  void _disarmDelete() {
    _deleteArmTimer?.cancel();
    _deleteArmTimer = null;
    if (_deleteArmed) setState(() => _deleteArmed = false);
  }

  Future<void> _runSelected(Future<void> Function() run, String what) async {
    if (ctrl.selected.isEmpty) return;
    AppLog.instance
        .act('种子列表', '多选栏[$what]', target: '${ctrl.selected.length} 个');
    await _onSelected(run);
    _exitSelect();
  }

  Widget _selectionBar() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color onBg = cs.primary;
    return Padding(
      padding: EdgeInsets.fromLTRB(af(context, 8), 2, af(context, 8), 2),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: af(context, 10)),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: <Widget>[
            Flexible(
              child: Text(
                '${S.selectedCount(ctrl.selected.length)}'
                '　·　${S.fieldSelectedSize}'
                '${Formatter.setSize(_selectedSize())}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: af(context, 11),
                  fontWeight: FontWeight.w700,
                  color: onBg,
                ),
              ),
            ),
            const Spacer(),
            _selectionAction(S.logSelectAll, ctrl.selectAll),
            _selectionAction(S.batchInvert, ctrl.invertSelection),
            _selectionAction(S.cancel, _exitSelect, icon: Icons.close),
          ],
        ),
      ),
    );
  }

  Widget _selectionAction(String label, VoidCallback onTap, {IconData? icon}) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: af(context, 7), vertical: af(context, 6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: af(context, 12), color: cs.onSurfaceVariant),
              const SizedBox(width: 2),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: af(context, 10),
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _selectedSize() => ctrl.items
      .where((Torrent t) => ctrl.selected.contains(t.hash))
      .fold(0, (int a, Torrent t) => a + t.size);

  Widget _body(BuildContext context) {
    final List<Torrent> list = _list;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset('assets/images/empty.webp', width: af(context, 96)),
            SizedBox(height: af(context, 12)),
            Text('暂无种子', style: TextStyle(fontSize: af(context, 12))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () {
        AppLog.instance.act('种子列表', '下拉[刷新]');
        return ctrl.refresh();
      },
      child: SlidableAutoCloseGroup(
        child: ListView.builder(
          controller: _scrollCtl,
          addAutomaticKeepAlives: false,
          padding: EdgeInsets.only(top: 4, bottom: af(context, 88)),
          itemCount: list.length,
          itemBuilder: (BuildContext context, int i) => AppPageTheme(
            key: ValueKey<String>(list[i].hash),
            page: AppPageKey.torrentCard,
            applyCardBackground: true,
            child: _tile(list[i]),
          ),
        ),
      ),
    );
  }

  Widget _tile(Torrent t) {
    return Obx(() {
      final bool selected = ctrl.selected.contains(t.hash);
      final ColorScheme cs = Theme.of(context).colorScheme;
      final Color cardBg =
          cardBackgroundFor(AppPageKey.torrentCard, selected: selected) ??
              (selected ? cs.secondaryContainer : cs.surfaceContainerLow);

      return SlidableTile(
        margin: EdgeInsets.fromLTRB(af(context, 10), 4, af(context, 10), 4),
        motion: SlidableMotionKind.scroll,
        extentRatio: 0.30,
        slotCount: 2,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        contentBackground: cardBg,
        enabled: !_selecting,
        onLongPress: () {
          AppLog.instance.act('种子列表', '卡片[长按多选]', target: t.name);
          setState(() => _selecting = true);
          ctrl.toggleSelect(t.hash);
        },
        onSlideChanged: _onCardSlideChanged,

        startActions: <SlidableActionItem>[
          SlidableActionItem(
            icon: Icons.search,
            badgeColor: Colors.indigoAccent,
            tooltip: S.querySubTorrents,
            onPressed: () {
              AppLog.instance.act('种子列表', '右滑[查询辅种]', target: t.name);
              _showSubTorrents(t);
            },
          ),
        ],
        endActions: <SlidableActionItem>[
          SlidableActionItem(
            icon: t.isPause ? Icons.play_arrow : Icons.pause,
            badgeColor: t.isPause ? Colors.green : Colors.orangeAccent,
            tooltip: t.isPause ? S.actResume : S.actPause,
            onPressed: () {
              AppLog.instance.act(
                '种子列表',
                '左滑[${t.isPause ? S.actResume : S.actPause}]',
                target: t.name,
              );
              _single(
                t,
                t.isPause ? ctrl.resumeSelected : ctrl.pauseSelected,
              );
            },
          ),
          SlidableActionItem(
            icon: Icons.delete,
            badgeColor: Colors.red,
            tooltip: S.delete,
            onPressed: () async {
              AppLog.instance.act('种子列表', '左滑[删除]', target: t.name);
              await _single(t, () => Future<void>.value(), silent: true);
              await _confirmDelete();
            },
          ),
        ],
        child: _pauseFade(
          t,
          Container(
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: selected
                    ? cs.primary.withValues(alpha: 0.85)
                    : cs.outlineVariant.withValues(alpha: 0.55),
                width: selected ? 1.2 : 0.8,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    width: 3.5,
                    color: Formatter.setStatusColor(t.state, cs),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _onCardTap(t),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(af(context, 10), af(context, 8), af(context, 10), af(context, 8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                if (_selecting) ...<Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: _selectRing(
                                      cs,
                                      selected,
                                      onTap: () => ctrl.toggleSelect(t.hash),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                ] else ...<Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Icon(
                                      Formatter.statusIcon(t.state),
                                      size: af(context, 16),
                                      color: Formatter.setStatusColor(t.state, cs),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    t.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: af(context, 13),
                                      height: 1.22,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(
                                    _expanded.contains(t.hash)
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: af(context, 18),
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2.5),
                                    child: LinearProgressIndicator(
                                      value: t.progress.clamp(0, 1),
                                      minHeight: 5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Formatter.setStatusColor(t.state, cs)),
                                      backgroundColor:
                                          cs.surfaceContainerHighest,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  Formatter.setProgress(t.progress),
                                  style: TextStyle(
                                    fontSize: af(context, 12),
                                    fontWeight: FontWeight.w800,
                                    color: Formatter.setStatusColor(t.state, cs),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: <Widget>[
                                Icon(Icons.arrow_upward,
                                    size: af(context, 12), color: cs.primary),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    Formatter.setSpeed(t.newUpspeed),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: af(context, 11.5),
                                        fontWeight: FontWeight.w700,
                                        color: cs.primary),
                                  ),
                                ),
                                SizedBox(width: af(context, 10)),
                                Icon(Icons.arrow_downward,
                                    size: af(context, 12), color: cs.secondary),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    Formatter.setSpeed(t.newDownSpeed),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: af(context, 11.5),
                                        fontWeight: FontWeight.w700,
                                        color: cs.secondary),
                                  ),
                                ),
                                const Spacer(),
                                Icon(Icons.hourglass_bottom,
                                    size: af(context, 11),
                                    color: cs.onSurfaceVariant),
                                const SizedBox(width: 3),
                                Text(
                                  Formatter.setEta(t.newEta),
                                  style: TextStyle(
                                      fontSize: af(context, 10),
                                      color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                    fontSize: af(context, 10),
                                    color: cs.onSurfaceVariant),
                                children: <InlineSpan>[
                                  TextSpan(
                                    text:
                                        '${Formatter.setSize(t.downloaded)} / ${Formatter.setSize(t.newSize)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.92),
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        '　·　${S.fieldRatio} ${Formatter.setRatio(t.ratio)}'
                                        '　·　${S.fieldRemaining} ${Formatter.setSize(t.amountLeft)}',
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: <Widget>[
                                Icon(Icons.groups,
                                    size: af(context, 11),
                                    color: cs.onSurfaceVariant),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    '${S.fieldSeeders} '
                                    '${Formatter.getSeederCount(t.numSeeds, t.numLeechs, t.transferPeers)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: af(context, 10),
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurfaceVariant),
                                  ),
                                ),
                                if (_siteHost(t).isNotEmpty) ...<Widget>[
                                  const SizedBox(width: 8),
                                  Icon(Icons.language,
                                      size: af(context, 11),
                                      color: cs.onSurfaceVariant),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      ctrl.siteMasked.value
                                          ? Formatter.maskSite(_siteHost(t))
                                          : _siteHost(t),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: af(context, 10),
                                          color: cs.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  Formatter.setStatus(t.state),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: af(context, 10),
                                    fontWeight: FontWeight.w700,
                                    color: Formatter.setStatusColor(t.state, cs),
                                  ),
                                ),
                              ],
                            ),
                            if (t.downloaded > 0 ||
                                t.uploaded > 0 ||
                                _catChips(t).isNotEmpty ||
                                _tagChips(t).isNotEmpty) ...<Widget>[
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 4,
                                runSpacing: 3,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: <Widget>[
                                  if (t.downloaded > 0 || t.uploaded > 0)
                                    DiskIoChip(
                                      written: t.downloaded,
                                      read: t.uploaded,
                                      compact: true,
                                    ),
                                  ..._catChips(t),
                                  ..._tagChips(t),
                                ],
                              ),
                            ],
                            AnimatedSize(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              alignment: Alignment.topCenter,
                              child: _expanded.contains(t.hash)
                                  ? _detail(t, cs)
                                  : const SizedBox(
                                      width: double.infinity, height: 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _pauseFade(Torrent t, Widget child) {
    if (!t.isPause) return child;
    return Opacity(
      opacity: 0.62,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.33,
          0.33,
          0.33,
          0,
          0,
          0.33,
          0.33,
          0.33,
          0,
          0,
          0.33,
          0.33,
          0.33,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: child,
      ),
    );
  }

  Widget _selectRing(ColorScheme cs, bool checked, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Container(
          width: 19,
          height: 19,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: checked ? cs.primary : Colors.transparent,
            border: Border.all(
              color: checked ? cs.primary : cs.outline.withValues(alpha: 0.9),
              width: 1.6,
            ),
          ),
          child: checked
              ? Icon(Icons.check, size: 13, color: cs.onPrimary)
              : null,
        ),
      ),
    );
  }

  List<Widget> _catChips(Torrent t) {
    final String cat = (t.category ?? '').trim();
    if (cat.isEmpty) return const <Widget>[];
    final ColorScheme cs = Theme.of(context).colorScheme;
    return <Widget>[
      _chip(
        icon: Icons.folder_outlined,
        text: cat,
        fg: cs.primary,
        bg: cs.primaryContainer.withValues(alpha: 0.55),
      ),
    ];
  }

  List<Widget> _tagChips(Torrent t) {
    final String raw = (t.tags ?? '').trim();
    if (raw.isEmpty) return const <Widget>[];
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<String> tags = raw
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .take(4)
        .toList();
    return <Widget>[
      for (final String g in tags)
        _chip(
          icon: Icons.label_outline,
          text: g,
          fg: cs.tertiary,
          bg: cs.tertiaryContainer.withValues(alpha: 0.55),
        ),
    ];
  }

  Widget _chip({
    required IconData icon,
    required String text,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: af(context, 10), color: fg),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: af(context, 9), color: fg),
            ),
          ),
        ],
      ),
    );
  }

  String _siteHost(Torrent t) => t.site;

  Widget _detail(Torrent t, ColorScheme cs) {
    final CapabilitySet cap = ctrl.capabilities;

    Widget chip({
      required String label,
      required bool? value,
      required Future<void> Function(bool v) run,
    }) =>
        EditSwitchChip(
          label: label,
          value: value ?? false,
          enabled: !_cardBusy,
          onChanged: (bool v) => _cardApply(t, label, () => run(v)),
        );

    Widget dlField({bool compact = false}) => EditNumberField(
          label: S.fieldDlLimit,
          initial:
              _draftInt(t, TorrentEditFields.kDlLimit, t.newDlLimit ~/ 1024),
          baseline: t.newDlLimit ~/ 1024,
          unit: 'KB/s',
          compact: compact,
          zeroMeansUnlimited: true,
          onChanged: (int v) =>
              ctrl.setDraft(t.hash, TorrentEditFields.kDlLimit, v),
          onSave: (int v) => _cardApply(
            t,
            S.fieldDlLimit,
            () => ctrl.setLimitsOf(<String>[t.hash], dlKb: v),
            draftKey: TorrentEditFields.kDlLimit,
          ),
        );

    Widget upField({bool compact = false}) => EditNumberField(
          label: S.fieldUpLimit,
          initial:
              _draftInt(t, TorrentEditFields.kUpLimit, t.newUpLimit ~/ 1024),
          baseline: t.newUpLimit ~/ 1024,
          unit: 'KB/s',
          compact: compact,
          zeroMeansUnlimited: true,
          onChanged: (int v) =>
              ctrl.setDraft(t.hash, TorrentEditFields.kUpLimit, v),
          onSave: (int v) => _cardApply(
            t,
            S.fieldUpLimit,
            () => ctrl.setLimitsOf(<String>[t.hash], upKb: v),
            draftKey: TorrentEditFields.kUpLimit,
          ),
        );

    Widget ratioField({bool compact = false}) => EditRatioField(
          label: S.fieldRatioLimit,
          initial:
              _draftDouble(t, TorrentEditFields.kRatioLimit, t.ratioLimit),
          baseline: t.ratioLimit,
          compact: compact,
          onChanged: (double v) =>
              ctrl.setDraft(t.hash, TorrentEditFields.kRatioLimit, v),
          onSave: (double v) => _cardApply(
            t,
            S.fieldRatioLimit,
            () => ctrl.setShareLimitsOf(<String>[t.hash], ratioLimit: v),
            draftKey: TorrentEditFields.kRatioLimit,
          ),
        );

    Widget seedTimeField({bool compact = false}) => EditNumberField(
          label: S.fieldSeedingTimeLimit,
          initial: _draftInt(t, TorrentEditFields.kSeedingTime,
              t.seedingTimeLimit < 0 ? 0 : t.seedingTimeLimit),
          baseline: t.seedingTimeLimit < 0 ? 0 : t.seedingTimeLimit,
          unit: S.editMinutesUnit,
          compact: compact,
          zeroMeansUnlimited: true,
          onChanged: (int v) =>
              ctrl.setDraft(t.hash, TorrentEditFields.kSeedingTime, v),
          onSave: (int v) => _cardApply(
            t,
            S.fieldSeedingTimeLimit,
            () => ctrl.setShareLimitsOf(<String>[t.hash],
                seedingTimeMin: v <= 0 ? -1 : v),
            draftKey: TorrentEditFields.kSeedingTime,
          ),
        );

    Widget groupTitle(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            text,
            style: TextStyle(
              fontSize: af(context, 9.5),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: cs.onSurfaceVariant,
            ),
          ),
        );

    Widget quickCell(String label, String value, {Color? color}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label,
                  style: TextStyle(
                      fontSize: af(context, 8.5),
                      color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: af(context, 11),
                    fontWeight: FontWeight.w700,
                    color: color ?? cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );

    final List<Widget> switchChips = <Widget>[
      if (cap.forceStart)
        chip(
          label: S.swForceStart,
          value: t.forceStart,
          run: (bool v) => ctrl.setForceStartOf(<String>[t.hash], v),
        ),
      if (cap.sequentialDownload)
        chip(
          label: S.swSequential,
          value: t.sequentialDownload,
          run: (bool v) =>
              ctrl.toggleSequentialOf(<String>[t.hash], target: v),
        ),
      if (cap.isQb)
        chip(
          label: S.swFirstLast,
          value: t.firstLastPiecePrio,
          run: (bool v) =>
              ctrl.toggleFirstLastPrioOf(<String>[t.hash], target: v),
        ),
      if (cap.superSeeding)
        chip(
          label: S.swSuperSeeding,
          value: t.superSeeding,
          run: (bool v) => ctrl.setSuperSeedingOf(<String>[t.hash], v),
        ),
    ];

    return GestureDetector(

      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: RepaintBoundary(
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: EdgeInsets.all(af(context, 9)),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
                cs.onSurface.withValues(alpha: 0.045), cs.surfaceContainerLow),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  quickCell(S.fieldUploaded,
                      Formatter.setSize(t.newUploaded),
                      color: cs.primary),
                  quickCell(S.fieldDownloaded,
                      Formatter.setSize(t.downloaded)),
                  quickCell(
                      S.fieldAddedOn, Formatter.setDate(t.newAddedOn)),
                  quickCell(S.fieldCompletionOn,
                      Formatter.setDate(t.newCompletionOn)),
                ],
              ),
              const SizedBox(height: 9),
              groupTitle(S.editSectionLimits),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: dlField(compact: true)),
                  const SizedBox(width: 6),
                  Expanded(child: upField(compact: true)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: ratioField(compact: true)),
                  const SizedBox(width: 6),
                  Expanded(child: seedTimeField(compact: true)),
                ],
              ),
              if (switchChips.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                groupTitle(S.editSectionSwitches),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: switchChips,
                ),
              ],
              const SizedBox(height: 8),
              groupTitle(S.editSectionBasic),
              EditActionRow(
                label: S.fieldPath,
                value: (t.savePath ?? '').isEmpty
                    ? S.editCategoryNone
                    : t.savePath!,
                onTap: _cardBusy ? null : () => _editCardPath(t),
              ),
              if (cap.category)
                EditActionRow(
                  label: S.fieldCategory,
                  value: t.categoryName,
                  onTap: _cardBusy ? null : () => _editCardCategory(t),
                ),
              EditActionRow(
                label: S.fieldTags,
                value: t.tagList.isEmpty ? S.editCategoryNone : t.tagList.join('、'),
                onTap: _cardBusy ? null : () => _editCardTags(t),
              ),
              const SizedBox(height: 8),
              groupTitle(S.editSectionInfo),
              ReadonlyKvGrid(
                fullRows: <List<String>>[
                  <String>[
                    S.fieldPath,
                    (t.contentPath ?? '').isEmpty ? '-' : t.contentPath!,
                  ],
                ],
                pairs: <List<String>>[
                  <String>[
                    S.fieldActiveTime,
                    Formatter.setLastActivity(t.newLastActivity),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: af(context, 30),
                  child: FilledButton.tonalIcon(
                    onPressed: () => _openDetail(t),
                    icon: Icon(Icons.open_in_new, size: af(context, 14)),
                    label: Text(S.viewDetail,
                        style: TextStyle(fontSize: af(context, 11))),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: af(context, 12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _draftInt(Torrent t, String key, int fallback) {
    final dynamic v = ctrl.draftOf(t.hash, key);
    return v is int ? v : fallback;
  }

  double _draftDouble(Torrent t, String key, double fallback) {
    final dynamic v = ctrl.draftOf(t.hash, key);
    return v is num ? v.toDouble() : fallback;
  }

  Future<bool> _cardApply(
    Torrent t,
    String what,
    Future<void> Function() body, {
    String? draftKey,
  }) async {
    if (_cardBusy) return false;
    setState(() => _cardBusy = true);
    AppLog.instance.act('种子列表', '卡片编辑[$what]', target: t.name);
    try {
      await body();
    } catch (_) {

    }
    final bool ok = ctrl.lastActionOk.value != false;
    if (!mounted) return ok;
    setState(() => _cardBusy = false);
    if (!ok) {
      Formatter.showToast(
        '${S.execFailed}: ${ctrl.error.value ?? ''}',
        isError: true,
      );
      return false;
    }
    if (draftKey != null) ctrl.clearDraftKey(t.hash, draftKey);
    Formatter.showToast('$what${S.editSaved}');
    unawaited(_refreshCardAfter(t));
    return true;
  }

  Future<void> _refreshCardAfter(Torrent t) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    await ctrl.refresh();
  }

  Future<void> _editCardPath(Torrent t) async {
    final bool isQb = ctrl.capabilities.isQb;
    final PathEditResult? r = await EditDialogs.path(
      context,
      initial: t.savePath ?? '',

      askMove: !isQb,
    );
    if (r == null) return;
    await _cardApply(
      t,
      S.fieldPath,
      () => ctrl.setLocationOf(<String>[t.hash], r.path, move: r.move),
    );
  }

  Future<void> _editCardCategory(Torrent t) async {
    final List<String> cats =
        ctrl.facets(FilterDim.category).map((FacetEntry e) => e.value).toList();
    final String? v = await EditDialogs.category(
      context,
      initial: t.category ?? '',
      candidates: cats,
    );
    if (v == null) return;
    await _cardApply(
      t,
      S.fieldCategory,
      () => ctrl.setCategoryOf(<String>[t.hash], v),
    );
  }

  Future<void> _editCardTags(Torrent t) async {
    final List<String> cand =
        ctrl.facets(FilterDim.tags).map((FacetEntry e) => e.value).toList();
    final TagEditResult? r = await EditDialogs.tags(
      context,
      initial: t.tagList,
      candidates: cand,
    );
    if (r == null) return;
    await _cardApply(
      t,
      S.fieldTags,
      () => ctrl.setTagsOf(<String>[t.hash], r.tags, append: r.append),
    );
  }

  void _onCardTap(Torrent t) {
    if (_selecting) {
      ctrl.toggleSelect(t.hash);
      return;
    }
    final bool willExpand = !_expanded.contains(t.hash);
    setState(() {
      if (willExpand) {
        _expanded.add(t.hash);
      } else {
        _expanded.remove(t.hash);

        ctrl.clearDraft(t.hash);
      }
    });
    AppLog.instance.act(
        '种子列表', '卡片[${willExpand ? '展开' : '收起'}]', target: t.name);

    if (willExpand) unawaited(ctrl.ensureEditFields(t));
  }

  void _openDetail(Torrent t) {
    if (_selecting) {
      ctrl.toggleSelect(t.hash);
      return;
    }
    AppLog.instance.act('种子列表', '卡片[进入详情]', target: t.name);
    ctrl.openDetail(t);
    Get.toNamed(Routes.torrentInfo);
  }

  void _exitSelect() {
    _disarmDelete();
    ctrl.clearSelection();
    setState(() => _selecting = false);
  }

  Future<void> _onSelected(Future<void> Function() action) async {
    if (ctrl.selected.isEmpty) return;
    await action();
  }

  Future<void> _single(
    Torrent t,
    Future<void> Function() action, {
    bool silent = false,
  }) async {
    ctrl
      ..clearSelection()
      ..toggleSelect(t.hash);
    if (!silent) await action();
  }

  Future<void> _showSubTorrents(Torrent t) async {
    final List<Torrent> subs = ctrl.items
        .where((Torrent x) => TorrentController.isCrossSeed(t, x))
        .toList();
    await Formatter.showCustomBottomSheet<void>(
      title: '${S.querySubTorrents}（${subs.length}）',
      context: context,
      child: subs.isEmpty
          ? Padding(
              padding: EdgeInsets.fromLTRB(af(context, 16), af(context, 24), af(context, 16), af(context, 32)),
              child: Center(
                child: Text('未找到其它辅种', style: TextStyle(fontSize: af(context, 12))),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              itemCount: subs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int i) {
                final Torrent s = subs[i];
                final ColorScheme cs = Theme.of(context).colorScheme;
                final String site = s.site;

                Widget line(String text) => Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: af(context, 10)),
                    );
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Formatter.statusIcon(s.state),
                    size: AppTheme.iconSize,
                    color: Formatter.setStatusColor(s.state, cs),
                  ),
                  title: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: af(context, 12)),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      line('${S.fieldSiteShort} ${site.isEmpty ? '-' : site}'
                          ' · ${S.fieldSeeders} '
                          '${Formatter.getSeederCount(s.numComplete, s.numIncomplete, s.transferPeers)}'
                          ' · ${Formatter.setStatus(s.state)}'),
                      line('${Formatter.setSize(s.size)}'
                          ' · ${S.fieldRatioShort} ${Formatter.setRatio(s.ratio)}'
                          ' · ${S.fieldUpShort} ${Formatter.setSize(s.uploaded)}'
                          ' · ${S.fieldDlShort} ${Formatter.setSize(s.downloaded)}'),
                    ],
                  ),
                  onTap: () async {
                    Navigator.of(context).maybePop();
                    ctrl.openDetail(s);
                    Get.toNamed(Routes.torrentInfo);
                  },
                );
              },
            ),
    );
  }

  Future<void> _confirmDelete() async {
    if (ctrl.selected.isEmpty) return;
    final DeleteOptions? opt = await Formatter.showDeleteTorrent(
      context,
      count: ctrl.selected.length,
      defaultDeleteFiles: false,
      defaultDeleteSub: false,
      defaultNoSubDeleteFiles: false,
    );
    if (opt == null) return;

    await ctrl.deleteSelected(
      deleteFiles: opt.deleteFiles,
      deleteSub: opt.deleteSub,
      noSubDeleteFiles: opt.noSubDeleteFiles,
    );
    _exitSelect();
  }
}

class _SpeedTitle extends StatefulWidget {
  const _SpeedTitle();

  @override
  State<_SpeedTitle> createState() => _SpeedTitleState();
}

class _SpeedTitleState extends State<_SpeedTitle> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TorrentController ctrl = Get.find<TorrentController>();

    final Color? bg = Get.find<ThemeController>().effectiveBackgroundColor;
    final bool dark = bg == null
        ? Theme.of(context).brightness == Brightness.dark
        : AppTheme.contrastOn(bg) == const Color(0xFFE6E6E6);
    final Color upColor = dark ? Colors.green.shade300 : Colors.green.shade700;
    final Color dlColor = dark ? Colors.red.shade300 : Colors.red.shade700;

    Widget line(Color color, String arrow, int bytesPerSec) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              arrow,
              style: TextStyle(
                color: color,
                fontSize: af(context, 11),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              Formatter.setSpeed(bytesPerSec),
              style: TextStyle(fontSize: af(context, 11)),
            ),
          ],
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        line(upColor, '↑', ctrl.totalUpSpeed),
        line(dlColor, '↓', ctrl.totalDlSpeed),
      ],
    );
  }
}
