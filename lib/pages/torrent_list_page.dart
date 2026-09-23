import 'dart:async';

import 'package:flutter/material.dart';
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
import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../utils/i18n.dart';
import '../utils/strings.dart';
import '../widgets/auto_refresh.dart';
import '../widgets/list_loading_placeholder.dart';
import '../widgets/disk_io_chip.dart';
import '../widgets/draggable_fab.dart';
import '../widgets/slidable_tile.dart';
import '../widgets/sort_filter_panel.dart';
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

  final Set<String> _expanded = <String>{};

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

    _serverWorker =
        ever<ServerData?>(ctrl.serverCtrl.current, (ServerData? s) {
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

        flexibleSpace: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          child: Center(
            child: ConstrainedBox(

              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.4,
              ),
              child: Obx(
                () => Text(
                  Get.find<ServerController>().current.value?.name ?? '',
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
        actions: <Widget>[
          if (_selecting) ...<Widget>[

            IconButton(
              icon: const Icon(Icons.play_arrow, size: AppTheme.iconSize),

              tooltip: '开始做种',
              color: _actColor(Colors.green),
              onPressed: () async {
                AppLog.instance.act('种子列表', '多选栏[开始做种]',
                    target: '${ctrl.selected.length} 个');
                await _onSelected(ctrl.resumeSelected);
                _exitSelect();
              },
            ),
            IconButton(
              icon: const Icon(Icons.pause, size: AppTheme.iconSize),
              tooltip: '暂停',
              color: _actColor(Colors.orange),
              onPressed: () async {
                AppLog.instance.act('种子列表', '多选栏[暂停]',
                    target: '${ctrl.selected.length} 个');
                await _onSelected(ctrl.pauseSelected);
                _exitSelect();
              },
            ),
            IconButton(
              icon: const Icon(Icons.fact_check_outlined,
                  size: AppTheme.iconSize),
              tooltip: S.fieldVerifyState,
              color: _actColor(Colors.blue),
              onPressed: () async {
                AppLog.instance.act('种子列表', '多选栏[重新校验]',
                    target: '${ctrl.selected.length} 个');
                await _onSelected(ctrl.recheckSelected);
                _exitSelect();
              },
            ),

            Obx(() {
              final bool isTr = Get.find<ServerController>()
                      .current
                      .value
                      ?.isTransmission ==
                  true;
              if (!isTr) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.reorder, size: AppTheme.iconSize),
                tooltip: S.queueMoveTitle,
                color: _actColor(Colors.purple),
                onSelected: (String v) async {
                  AppLog.instance.act('种子列表', '多选栏[队列移动:$v]',
                      target: '${ctrl.selected.length} 个');
                  await _onSelected(() => ctrl.queueMoveSelected(v));
                  _exitSelect();
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'top',
                    child: Text(S.queueMoveTop,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  PopupMenuItem<String>(
                    value: 'up',
                    child: Text(S.queueMoveUp,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  PopupMenuItem<String>(
                    value: 'down',
                    child: Text(S.queueMoveDown,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  PopupMenuItem<String>(
                    value: 'bottom',
                    child: Text(S.queueMoveBottom,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              );
            }),

            IconButton(
              icon: const Icon(Icons.delete, size: AppTheme.iconSize),
              tooltip: S.delete,
              color: _actColor(Colors.red),
              onPressed: () {
                AppLog.instance.act('种子列表', '多选栏[删除]',
                    target: '${ctrl.selected.length} 个');
                _confirmDelete();
              },
            ),
          ] else ...<Widget>[

            IconButton(
              icon: const Icon(Icons.tune, size: AppTheme.iconSize),
              tooltip: '排序与筛选',
              onPressed: () => showSortFilterPanel(context),
            ),
            IconButton(
              icon: const Icon(Icons.checklist, size: AppTheme.iconSize),
              tooltip: '多选',
              onPressed: () => setState(() => _selecting = true),
            ),

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
                  final bool v =
                      ctrl.siteMasked.value;
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
          final String? why = cur == null ? null : sc.connError[cur.id];
          final bool suspended = cur != null && sc.isSuspended(cur.id);
          final bool hasError =
              ctrl.error.value != null || (suspended && why != null);
          if (hasError) {
            final bool authFailed = why != null && why.startsWith('登录失败');
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
                topInset: kToolbarHeight + MediaQuery.of(context).padding.top,

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
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: <Widget>[
          for (final TorrentFilter f in TorrentFilter.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Obx(
                () => ChoiceChip(
                  label: Text(f.label, style: const TextStyle(fontSize: 11)),
                  selected: ctrl.filter.value == f,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    AppLog.instance.act('种子列表', '筛选[${f.label}]');
                    ctrl.setFilter(f);
                  },
                ),
              ),
            ),
          if (ctrl.filter.value != TorrentFilter.all ||
              ctrl.keyword.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ActionChip(
                avatar: const Icon(Icons.clear_all, size: 14),
                label: const Text('清除', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  AppLog.instance.act('种子列表', '筛选[清除]');
                  ctrl.setFilter(TorrentFilter.all);
                  _clearKeywordNow();
                  Formatter.showToast(S.filterCleared);
                  setState(() {});
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectionBar() {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.select_all, size: AppTheme.iconSize),
              tooltip: '全选',
              onPressed: ctrl.selectAll,
            ),
            const Spacer(),
            Text(
              '${S.selectedCount(ctrl.selected.length)}'
              '　${S.fieldSelectedSize}'
              '${Formatter.setSize(_selectedSize())}',
              style: const TextStyle(fontSize: 11),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: AppTheme.iconSize),
              onPressed: _exitSelect,
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

      onTap: () => _openDetail(t),
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
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              InkWell(

                onTap: () => _openDetail(t),

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

                          InkWell(
                            onTap: () => setState(() {
                              if (!_expanded.add(t.hash)) _expanded.remove(t.hash);
                            }),
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
                            : const SizedBox(width: double.infinity, height: 0),
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                width: double.infinity,
                color: _sectionTint(cardBg),
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[

                        Expanded(
                          flex: 2,
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

                              DiskIoChip(written: t.downloaded, read: t.uploaded),
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
                                Formatter.setSize(t.newSize), strong: true),
                            const SizedBox(height: 3),
                            _metricRow(Icons.swap_horiz,
                                '${S.fieldRatio} ${Formatter.setRatio(t.ratio)}'),
                            const SizedBox(height: 3),
                            _metricRow(Icons.schedule, Formatter.setEta(t.newEta)),
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
                  ],
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
          0.33, 0.33, 0.33, 0, 0, 
          0.33, 0.33, 0.33, 0, 0, 
          0.33, 0.33, 0.33, 0, 0, 
          0, 0, 0, 1, 0, 
        ]),
        child: child,
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

  String _metaLine(Torrent t) {
    final List<String> parts = <String>[];
    final String cat = (t.category ?? '').trim();
    if (cat.isNotEmpty) parts.add(cat);
    final String tags = (t.tags ?? '').trim();
    if (tags.isNotEmpty) parts.add(tags);

    parts.add(
      '${S.fieldSeeders} '
      '${Formatter.getSeederCount(t.numComplete, t.numIncomplete, t.transferPeers)}',
    );
    final String site = _siteHost(t);
    if (site.isNotEmpty) {
      parts.add(ctrl.siteMasked.value
          ? Formatter.maskSite(site)
          : site);
    }
    return parts.join(' · ');
  }

  Widget _detail(Torrent t, ColorScheme cs) {
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '$k$v',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Divider(height: 8, color: cs.outlineVariant.withValues(alpha: 0.5)),
          kv('${S.fieldPath}：', (t.contentPath ?? '').isEmpty ? '-' : t.contentPath!),
          kv('${S.fieldUploaded}：', Formatter.setSize(t.newUploaded)),
          kv('${S.fieldDownloaded}：', Formatter.setSize(t.downloaded)),
          kv('${S.fieldDlLimit}：',
              t.newDlLimit <= 0 ? '∞' : Formatter.setSpeed(t.newDlLimit)),
          kv('${S.fieldUpLimit}：',
              t.newUpLimit <= 0 ? '∞' : Formatter.setSpeed(t.newUpLimit)),
          kv('${S.fieldAddedOn}：', Formatter.setDate(t.newAddedOn)),
          kv('${S.fieldActiveTime}：',
              Formatter.setLastActivity(t.newLastActivity)),
          kv('${S.fieldCompletionOn}：', Formatter.setDate(t.newCompletionOn)),
        ],
      ),
    );
  }

  void _openDetail(Torrent t) {
    if (_selecting) {
      ctrl.toggleSelect(t.hash);
      return;
    }
    AppLog.instance.act('种子列表', '卡片[进入详情]', target: t.name);
    if (_expanded.contains(t.hash)) return;
    ctrl.openDetail(t);
    Get.toNamed(Routes.torrentInfo);
  }

  void _exitSelect() {
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
