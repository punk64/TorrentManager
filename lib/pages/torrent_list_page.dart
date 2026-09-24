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
import '../utils/i18n.dart';
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

class TorrentListPage extends StatefulWidget {
  const TorrentListPage({super.key});

  @override
  State<TorrentListPage> createState() => _TorrentListPageState();
}

class _TorrentListPageState extends State<TorrentListPage> {
  final TorrentController ctrl = Get.find<TorrentController>();
  final TextEditingController _search = TextEditingController();

  bool _selecting = false;

  /// 删除按钮是否处于「已上膛」状态（首次点击后等待再次点击确认）
  bool _deleteArmed = false;

  Timer? _deleteArmTimer;

  final Set<String> _expanded = <String>{};

  /// 展开区编辑提交中（与详情页的 `_busy` 同义，防连点重复提交）。
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

    if (Get.isRegistered<TorrentController>()) ctrl.setListVisible(false);
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
                      icon: const Icon(Icons.close, size: AppTheme.iconSize),
                      onPressed: _exitSelect,
                    )
                  : Builder(
                      builder: (BuildContext ctx) => IconButton(
                        icon: const Icon(Icons.menu, size: AppTheme.iconSize),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),

              // 多选态不显示居中的服务器名（给左侧「已选 N 个」让位，避免文字重叠）
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
                              style: const TextStyle(
                                fontSize: 18,
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
              // 多选态的操作按钮已下移到列表上方「操作行」（AppBar 只留标题，
              // 避免按钮与标题挤在一行互相重叠 —— 历史上曾出现点"暂停"命中"删除"）
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
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (suspended)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    S.srvSuspended,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.orange),
                                  ),
                                ),
                              Text(
                                '${S.execFailed}\n${ctrl.error.value ?? why}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              if (authFailed && cur != null)
                                FilledButton.icon(
                                  onPressed: () => sc.relogin(cur),
                                  icon: const Icon(Icons.login, size: 16),
                                  label: Text(S.relogin),
                                )
                              else
                                TextButton.icon(
                                  onPressed: () => ctrl.refresh(),
                                  icon: const Icon(Icons.refresh, size: 16),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 3),
      child: TextField(
        controller: _search,
        maxLength: AppTheme.maxLenName,
        buildCounter: AppTheme.noCounter,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
          prefixIcon: const Icon(Icons.search, size: AppTheme.iconSize),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear_all, size: AppTheme.iconSize),
                  onPressed: () {
                    _clearKeywordNow();
                    setState(() {});
                  },
                ),
          hintText: S.search,
          hintStyle: const TextStyle(fontSize: 12),
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
      height: 40,
      child: Row(
        children: <Widget>[
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
              children: <Widget>[
                // D2：状态横条收进面板，顶部只留「已选状态 + 清除」。
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
                        size: 14,
                      ),
                      label: Text(
                        hasStatus
                            ? '${S.filterStatusPrefix}${ctrl.statusSummaryText}'
                            : (hasKw
                                ? '${S.search}: ${ctrl.keyword.value}'
                                : S.filterStatusTitle),
                        style: const TextStyle(fontSize: 11),
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
                      avatar: const Icon(Icons.clear_all, size: 14),
                      label: const Text('清除', style: TextStyle(fontSize: 11)),
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
          // 固定在筛选行右端：多选 / 排序筛选（图标 + 文字，始终可见）；多选态隐藏
          if (!_selecting)
            Padding(
              padding: const EdgeInsets.only(right: 8),
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

  /// 图标 + 文字的小按钮（筛选行右侧的「多选 / 排序筛选」）
  Widget _toolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 28,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
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

  /// 多选态的操作行（位于全选行上方）：开始 / 暂停 / 校验 /（TR）队列移动 / 删除。
  ///
  /// 删除为**二次点击确认**：首次点击后按钮变为红底「再点确认删除 N 项」，
  /// 4 秒内不再点击自动还原；避免误触/单击穿到删除（数据安全底线）。
  /// 多选态操作区（2026-09-24 用户整改）：**固定 2 行 × 4 列**按钮网格。
  ///
  /// ★ 原实现是「`Row` 平铺 + `_batchRow` 横向 `SingleChildScrollView`」，两个毛病：
  ///   ① 按钮只有描边、**没有填充底** ⇒ 彩色壁纸下文字看不清；
  ///   ② 第二行能左右滑动 ⇒ 位置不固定、末尾按钮常年在屏幕外。
  /// ⇒ 现改为**固定两行**（每行 4 格 `Expanded` 等宽，随屏幕宽度自适应，
  ///   **永不横向滑动**），每个按钮带**不透明填充 + 边框 + 圆角**（与「状态筛选」
  ///   按钮同口径）；整块再加一层不透明底，彻底隔开壁纸。
  ///
  /// 行 1 = 对种子本身的操作：开始 / 暂停 / 重新校验 / 删除
  /// 行 2 = 取出信息与批量：批量编辑 / 复制哈希 / 复制磁力链 /（TR 队列移动 | qB 批量导出）
  Widget _actionGrid() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int n = ctrl.selected.length;
    final bool empty = ctrl.selected.isEmpty;
    final bool isTr =
        Get.find<ServerController>().current.value?.isTransmission == true;
    final bool canExport = ctrl.capabilities.exportTorrent;

    Widget gap() => const SizedBox(width: 6);

    // 第 2 行末格：TR 走队列移动（弹菜单）、qB 走批量导出；都不支持时留空占位，
    // 保证两行的列宽完全对齐（不留空会出现 3 格撑满、宽度与上行错开）。
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
      // ★ 不透明底：彩色壁纸不再透上来（用户要求「和状态筛选按钮一样」的可读性口径）
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _gridButton(
                  icon: Icons.play_arrow,
                  label: S.actStart,
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

  /// 网格里的按钮：**填充底 + 边框 + 圆角**（对齐筛选面板 `_btn` 的观感）。
  ///
  /// ★ `onTap` 传 null ⇒ 不套 `InkWell`（外观照旧、手势交给外层，例如
  ///   `PopupMenuButton` 自带手势）—— 嵌两层 InkWell 会让外层点不动。
  Widget _gridButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? danger,
    bool solid = false,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fg = danger == null
        ? cs.onSurface
        : (solid ? Colors.white : danger);
    final Widget content = SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: fg),
            ),
          ),
        ],
      ),
    );
    return Material(
      color: solid
          ? danger
          : (danger != null
              ? danger.withValues(alpha: 0.14)
              : cs.surfaceContainerHighest.withValues(alpha: 0.9)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(
          color: solid
              ? Colors.transparent
              : (danger != null
                  ? danger.withValues(alpha: 0.6)
                  : cs.outlineVariant),
          width: 0.7,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }

  /// 批量编辑：把选中项交给第三期做好的批量面板（接口已就绪）。
  Future<void> _batchEdit() async {
    final List<String> hashes = ctrl.selected.toList();
    if (hashes.isEmpty) return;
    AppLog.instance.act('种子列表', '多选栏[批量编辑]', target: '${hashes.length} 个');
    await TorrentEditSheet.show(hashes);
  }

  /// 批量复制哈希（每行一条；多行粘贴到别处也认得）。
  Future<void> _copyHashes() async {
    final List<String> hashes = ctrl.selected.toList();
    if (hashes.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: hashes.join('\n')));
    AppLog.instance.act('种子列表', '多选栏[复制哈希]', target: '${hashes.length} 个');
    Formatter.showToast(S.batchCopied(hashes.length, S.fieldHash));
  }

  /// 批量复制磁力链。
  ///
  /// ⚠️ 磁力链里带 **passkey**（私人站点的个人标识）⇒ 复制前必须脱敏，
  ///    与 trackers 页同一口径（清单 6.4 第 17 条）。
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

  /// 批量导出 .torrent（逐个拉字节流 → 系统另存为）。
  ///
  /// 逐个而不是打包：`saveBytesAs` 走的是系统另存为，一次只能落一个文件；
  /// 且导出是重操作，失败要能按种子定位。
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

  /// 队列移动（TR 专有）：弹出菜单选「置顶 / 上移 / 下移 / 置底」。
  ///
  /// ★ 外观复用 `_gridButton`（不传 `onTap` ⇒ 不套内层 `InkWell`，手势交给
  ///   `PopupMenuButton` 自己），保证与相邻网格按钮完全一致。
  Widget _queueMoveButton() {
    return PopupMenuButton<String>(
      onSelected: (String v) =>
          _runSelected(() => ctrl.queueMoveSelected(v), '队列移动:$v'),
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'top',
          child: Text(S.queueMoveTop, style: const TextStyle(fontSize: 13)),
        ),
        PopupMenuItem<String>(
          value: 'up',
          child: Text(S.queueMoveUp, style: const TextStyle(fontSize: 13)),
        ),
        PopupMenuItem<String>(
          value: 'down',
          child: Text(S.queueMoveDown, style: const TextStyle(fontSize: 13)),
        ),
        PopupMenuItem<String>(
          value: 'bottom',
          child: Text(S.queueMoveBottom, style: const TextStyle(fontSize: 13)),
        ),
      ],
      child: _gridButton(
        icon: Icons.reorder,
        label: S.queueMoveTitle,
      ),
    );
  }

  /// 删除（网格第 1 行末格）：**二次点击确认** —— 首次点击只"上膛"（按钮转
  /// 红底实心「再点确认删除 N 项」），4 秒内不再点自动还原，避免误触。
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

  /// 删除必须点两次：首次只"上膛"，再次点击才真正弹确认框。
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
    final Color onBg = Theme.of(context).colorScheme.onSecondaryContainer;
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: <Widget>[
            // 全选：图标 + 文字（原来是纯图标，不易理解）
            SizedBox(
              height: 28,
              child: TextButton.icon(
                onPressed: ctrl.selectAll,
                icon: Icon(Icons.select_all, size: 15, color: onBg),
                label: Text(S.logSelectAll,
                    style: TextStyle(fontSize: 11, color: onBg)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${S.selectedCount(ctrl.selected.length)}'
                '　${S.fieldSelectedSize}'
                '${Formatter.setSize(_selectedSize())}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            SizedBox(
              height: 28,
              child: TextButton.icon(
                onPressed: _exitSelect,
                icon: Icon(Icons.close, size: 15, color: onBg),
                label:
                    Text(S.cancel, style: TextStyle(fontSize: 11, color: onBg)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
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
            Image.asset('assets/images/empty.webp', width: 96),
            const SizedBox(height: 12),
            const Text('暂无种子', style: TextStyle(fontSize: 12)),
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
          padding: const EdgeInsets.only(top: 4, bottom: 88),
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
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
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
        // ★ D9 方案 C：整块点击 = 展开/收起。
        //   手势**不挂在这里**——挂这会让展开区里的「修改 / 查看详情」按钮冒泡上来
        //   把卡片一起收起（第六节 6.1 第 1 条）。改为只绑收起态的两个内容区。
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
              border:
                  Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                InkWell(
                  onTap: () => _onCardTap(t),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            if (_selecting) ...<Widget>[
                              Checkbox(
                                value: selected,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onChanged: (_) => ctrl.toggleSelect(t.hash),
                              ),
                              const SizedBox(width: 4),
                            ] else ...<Widget>[
                              Icon(
                                Formatter.statusIcon(t.state),
                                size: 16,
                                color: Formatter.setStatusColor(t.state, cs),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                t.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              Formatter.setProgress(t.progress),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Formatter.setStatusColor(t.state, cs),
                              ),
                            ),
                            if (t.isPause) ...<Widget>[
                              const SizedBox(width: 6),
                              _pausedChip(cs),
                            ],
                            // ▼ 只是「整块可点」的视觉提示；走同一个 handler，
                            //   保证"收起即丢草稿"这条不会从这个入口漏掉。
                            InkWell(
                              onTap: () => _onCardTap(t),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Icon(
                                  _expanded.contains(t.hash)
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _metaLine(t),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 9),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              Formatter.setStatus(t.state),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                color: Formatter.setStatusColor(t.state, cs),
                              ),
                            ),
                          ],
                        ),
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
                GestureDetector(
                  onTap: () => _onCardTap(t),
                  child: Container(
                    width: double.infinity,
                    color: _sectionTint(cardBg),
                    padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // ★ 4.1：底部区从 2:1 改成 1:1（右栏补到 4 行后，
                          //   2:1 会把右侧挤成一行一行换行的碎字）。
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(
                                        '${S.upArrow}${Formatter.setSpeed(t.newUpspeed)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 10, color: cs.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '${S.downArrow}${Formatter.setSpeed(t.newDownSpeed)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 10, color: cs.secondary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                DiskIoChip(
                                    written: t.downloaded, read: t.uploaded),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                _metricRow(Icons.save_alt,
                                    Formatter.setSize(t.newSize),
                                    strong: true),
                                const SizedBox(height: 3),
                                _metricRow(Icons.swap_horiz,
                                    '${S.fieldRatio} ${Formatter.setRatio(t.ratio)}'),
                                const SizedBox(height: 3),
                                _metricRow(
                                    Icons.schedule, Formatter.setEta(t.newEta)),
                                const SizedBox(height: 3),
                                _metricRow(Icons.hourglass_bottom,
                                    Formatter.setSize(t.amountLeft)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusBar),
                        child: LinearProgressIndicator(
                          value: t.progress.clamp(0, 1),
                          minHeight: 4,
                        ),
                      ),
                      // 4.1：分类/标签直接上卡片（原来是挤在 _metaLine 的一行灰字里）。
                      if (_catChips(t).isNotEmpty ||
                          _tagChips(t).isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 3,
                          children: <Widget>[
                            ..._catChips(t),
                            ..._tagChips(t),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                ),
              ],
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

  /// 分类 chip（紫）。分类为空时不产生 chip。
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

  /// 标签 chip（青）。qB 是逗号串、TR 是 labels 拼的串 ⇒ 统一按逗号切。
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
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: fg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pausedChip(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: cs.outline,
        borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
      ),
      child: Text(
        L.t('已暂停'),
        style: TextStyle(fontSize: 9, color: cs.surface),
      ),
    );
  }

  Color _sectionTint(Color cardBg) {
    final bool onDark =
        ThemeData.estimateBrightnessForColor(cardBg) == Brightness.dark;
    return (onDark ? Colors.white : Colors.black)
        .withValues(alpha: AppTheme.sectionTintShift);
  }

  Widget _metricRow(IconData icon, String text, {bool strong = false}) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 11, color: cs.onSurfaceVariant),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: strong ? 10 : 9,
              fontWeight: strong ? FontWeight.w600 : FontWeight.normal,
              color: strong ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  String _siteHost(Torrent t) => t.site;

  /// 副标题行：做种者数 + 站点。
  ///
  /// ★ 4.1 之后分类/标签已经做成 **chip 上卡片**（见 [_catChips] / [_tagChips]），
  ///   这里不能再重复一遍 —— 否则卡片上会出现两处同样的分类。
  String _metaLine(Torrent t) {
    final List<String> parts = <String>[];

    parts.add(
      '${S.fieldSeeders} '
      '${Formatter.getSeederCount(t.numComplete, t.numIncomplete, t.transferPeers)}',
    );
    final String site = _siteHost(t);
    if (site.isNotEmpty) {
      parts.add(ctrl.siteMasked.value ? Formatter.maskSite(site) : site);
    }
    return parts.join(' · ');
  }

  /// 卡片展开区（方案 A · 分区卡片式）。
  ///
  /// ① 可编辑段（路径/分类/标签 + 限速×2/分享率上限/做种时限 **各独占一行**）
  /// ② 下载策略开关（**同一行 chip**，点即生效，按服务器能力裁剪）
  /// ③ 只读信息段（**两列网格**、长值独占行）—— 与概览 Tab 共用 `ReadonlyKvGrid`
  /// ④ 操作行：「查看详情」——方案 C 之后进详情的**唯一入口**
  ///
  /// ★ 2026-09-24 用户整改：① 每栏目套 `EditSectionCard` 分区（**边界感 + 可读性**）；
  ///   ② 限速×2 / 分享率上限 / 做种时限**改回独占一行**（撤回 v3 的 2×2：半格里
  ///   输入框只剩几十 dp —— 边框看不见、胶囊按钮挤在一起）。
  /// ★ 草稿一律走 controller 的 `setDraft`：列表 `ListView` 会回收重建卡片，
  ///   存 widget state 会"滚出去再滚回来输入就没了"（清单 6.2 第 5 条）。
  Widget _detail(Torrent t, ColorScheme cs) {
    final CapabilitySet cap = ctrl.capabilities;

    /// 下载策略开关：v3 定稿 = **同一行 chip**（原来是 4 个整行 Switch）。
    ///
    /// ★ 点即生效；不支持的能力**直接隐藏**（D4/V6）—— 调用方负责裁剪。
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

    // 可编辑 4 项：**各独占一行**（2026-09-24 用户整改，撤回 v3 的 2×2 紧凑形态）。
    // 独占行时 label 有 88dp、输入框拿满剩余宽度 ⇒ 边框可见、按钮不再互相挤。
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

    return GestureDetector(
      // ★ 吞掉展开区内部的点击：展开区里按钮/输入框的点击会冒泡到卡片手势，
      //   导致"点一下修改，卡片同时收起了"（第六节 6.1 第 1 条）。
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // ① 常规：路径 / 分类（qB）/ 标签 —— 每项点「修改」走弹窗提交
              EditSectionCard(
                dense: true,
                title: S.editSectionBasic,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
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
                      value: t.tagList.isEmpty
                          ? S.editCategoryNone
                          : t.tagList.join('、'),
                      onTap: _cardBusy ? null : () => _editCardTags(t),
                    ),
                  ],
                ),
              ),

              // ② 限速与分享：4 项**各独占一行**（2026-09-24 用户整改；
              //   文案以「下载限速 / 上传限速 / 分享率上限 / 做种时限」为准）
              EditSectionCard(
                dense: true,
                title: S.editSectionLimits,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    dlField(),
                    upField(),
                    ratioField(),
                    seedTimeField(),
                  ],
                ),
              ),

              // ③ 下载策略（**同一行 chip**；点即生效；不支持的直接隐藏 —— D4/V6）
              if (cap.forceStart ||
                  cap.sequentialDownload ||
                  cap.isQb ||
                  cap.superSeeding)
                EditSectionCard(
                  dense: true,
                  title: S.editSectionSwitches,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      if (cap.forceStart)
                        chip(
                          label: S.swForceStart,
                          value: t.forceStart,
                          run: (bool v) =>
                              ctrl.setForceStartOf(<String>[t.hash], v),
                        ),
                      if (cap.sequentialDownload)
                        chip(
                          label: S.swSequential,
                          value: t.sequentialDownload,
                          run: (bool v) => ctrl.toggleSequentialOf(
                              <String>[t.hash],
                              target: v),
                        ),
                      if (cap.isQb)
                        chip(
                          label: S.swFirstLast,
                          value: t.firstLastPiecePrio,
                          run: (bool v) => ctrl.toggleFirstLastPrioOf(
                              <String>[t.hash],
                              target: v),
                        ),
                      if (cap.superSeeding)
                        chip(
                          label: S.swSuperSeeding,
                          value: t.superSeeding,
                          run: (bool v) =>
                              ctrl.setSuperSeedingOf(<String>[t.hash], v),
                        ),
                    ],
                  ),
                ),

              // ④ 只读信息（短值两列网格、长值独占行 —— 与概览 Tab **共用组件**）
              EditSectionCard(
                dense: true,
                title: S.editSectionInfo,
                child: ReadonlyKvGrid(
                  fullRows: <List<String>>[
                    <String>[
                      S.fieldPath,
                      (t.contentPath ?? '').isEmpty ? '-' : t.contentPath!,
                    ],
                  ],
                  pairs: <List<String>>[
                    <String>[S.fieldUploaded, Formatter.setSize(t.newUploaded)],
                    <String>[S.fieldDownloaded, Formatter.setSize(t.downloaded)],
                    <String>[S.fieldAddedOn, Formatter.setDate(t.newAddedOn)],
                    <String>[
                      S.fieldCompletionOn,
                      Formatter.setDate(t.newCompletionOn),
                    ],
                    <String>[
                      S.fieldActiveTime,
                      Formatter.setLastActivity(t.newLastActivity),
                    ],
                  ],
                ),
              ),

              // ④ 操作行：进详情（方案 C）
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 30,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _openDetail(t),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: Text(S.viewDetail,
                        style: const TextStyle(fontSize: 11)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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

  // ---------------------------------------------------------------- 展开区编辑

  /// 展开区草稿读取（int）。没有草稿就回落服务端值。
  int _draftInt(Torrent t, String key, int fallback) {
    final dynamic v = ctrl.draftOf(t.hash, key);
    return v is int ? v : fallback;
  }

  double _draftDouble(Torrent t, String key, double fallback) {
    final dynamic v = ctrl.draftOf(t.hash, key);
    return v is num ? v.toDouble() : fallback;
  }

  /// 展开区统一的编辑提交外壳（对齐详情页 `_apply`）。
  ///
  /// 成功后：清掉**该字段**草稿 + 延迟 400ms 定点刷新（qB 常"返回成功但状态没变"）。
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
      // 失败详情由控制器写进 ctrl.error，下面统一提示。
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
      // TR 的 set-location 可选 move；qB 恒移动 ⇒ 弹窗里只给说明（清单 6.3 第 11 条）。
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

  /// ★ D9 方案 C：卡片**整块**点击 = 展开 / 收起。
  ///
  /// 不再直接进详情（进详情改走展开区底部的「查看详情」按钮，见 [_detail]）。
  /// 多选态下仍然是「勾选/取消」，与旧行为一致。
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
        // D6：收起即丢弃草稿（滚动重建不清草稿，只有主动收起才清）。
        ctrl.clearDraft(t.hash);
      }
    });
    AppLog.instance.act(
        '种子列表', '卡片[${willExpand ? '展开' : '收起'}]', target: t.name);
    // 展开时按需补齐开关类字段（带 60s 缓存，失败静默）。
    if (willExpand) unawaited(ctrl.ensureEditFields(t));
  }

  /// 展开区底部的「查看详情」：方案 C 之后进详情的唯一入口。
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
          ? const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Center(
                child: Text('未找到其它辅种', style: TextStyle(fontSize: 12)),
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
                      style: const TextStyle(fontSize: 10),
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
                    style: const TextStyle(fontSize: 12),
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
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              Formatter.setSpeed(bytesPerSec),
              style: const TextStyle(fontSize: 11),
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
