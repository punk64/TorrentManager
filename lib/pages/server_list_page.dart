import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/adaptive.dart';
import '../app/page_style.dart';
import '../app/routes.dart';
import '../app/style_keys.dart';
import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../data/models/server_data.dart';
import '../data/models/torrent.dart';
import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../utils/i18n.dart';
import '../utils/strings.dart';
import '../utils/startup_update.dart';
import '../widgets/auto_refresh.dart';
import '../widgets/draggable_fab.dart';
import '../widgets/io_chip.dart';
import '../widgets/metric_row.dart';
import '../widgets/server_stats_panel.dart';
import '../widgets/slidable_tile.dart';
import 'drawer_page.dart';
import 'server_dialog.dart';

const bool kEnableServerGroup = false;

const double _kHeaderLogoBox = 36;

const double _kPrivacyBtnBox = 30;

const double _kNameGap = 6;

const double _kBadgeGap = 4;

const double _kNameMinWidth = 76;

class _BadgeEntry {
  const _BadgeEntry({required this.widget, required this.width});

  final Widget widget;
  final double width;
}

double _textWidth(String text, double fontSize) {
  final TextPainter tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontSize: fontSize)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return tp.width;
}

double _chipWidth(
  String text, {
  double fontSize = 9,
  double padH = 6,
  double lead = 13,
}) =>
    padH * 2 + lead + _textWidth(text, fontSize) + 2;

String _connBadgeLabel({
  required ConnStatus status,
  required bool checking,
  required bool onLan,
}) {
  final bool failed = status == ConnStatus.failed;
  final bool busy = !failed && (status == ConnStatus.connecting || checking);
  return failed
      ? L.t('连接失败')
      : (busy ? L.t('连接中...') : (onLan ? L.t('局域网') : L.t('公网')));
}

Widget _badgeStrip(double maxWidth, List<_BadgeEntry> badges) {
  if (badges.isEmpty) return const SizedBox.shrink();

  final List<_BadgeEntry> keep = <_BadgeEntry>[];
  double used = 0;
  for (int i = badges.length - 1; i >= 0; i--) {
    final double w = badges[i].width + (keep.isEmpty ? 0 : _kBadgeGap);

    if (keep.isNotEmpty && used + w > maxWidth) break;
    used += w;
    keep.insert(0, badges[i]);
  }
  if (keep.isEmpty) return const SizedBox.shrink();

  return ClipRect(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < keep.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: _kBadgeGap),
            keep[i].widget,
          ],
        ],
      ),
    ),
  );
}

const String _kTotalExpandedKey = 'totalStatsExpanded';

class ServerListPage extends StatefulWidget {
  const ServerListPage({super.key});

  @override
  State<ServerListPage> createState() => _ServerListPageState();
}

class _ServerListPageState extends State<ServerListPage> {
  bool _cardOpen = false;
  bool _drawerOpen = false;

  final RxBool _totalExpanded = true.obs;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    unawaited(_loadTotalExpanded());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(StartupUpdatePrompt.runOnce());
    });
  }

  Future<void> _loadTotalExpanded() async {
    final bool v = await Formatter.getGlobalBool(_kTotalExpandedKey, def: true);
    _totalExpanded.value = v;
  }

  void _toggleTotalExpanded() {
    final bool next = !_totalExpanded.value;
    _totalExpanded.value = next;
    unawaited(Formatter.saveGlobalData(_kTotalExpandedKey, next));
  }

  void _onCardSlideChanged(bool open) {
    if (!mounted || _cardOpen == open) return;
    setState(() => _cardOpen = open);
  }

  @override
  Widget build(BuildContext context) {
    final ServerController ctrl = Get.find<ServerController>();

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

        title: Obx(() => Text('服务器（${ctrl.servers.length}）')),
        actions: <Widget>[

          Obx(() => _SpinningRefreshIcon(
                spinning: ctrl.isManualRefreshing,
                onPressed: () async {
                  AppLog.instance.act('服务器列表', 'AppBar[刷新全部]');
                  await ctrl.refreshAllServers(showProgress: true);
                  Formatter.showToast(S.srvRefreshedAll);
                },
              )),

          PopupMenuButton<String>(
            onSelected: (String v) {
              AppLog.instance.act('服务器列表',
                  'AppBar[日志-${v == Routes.log ? '系统日志' : '服务器日志'}]');
              Get.toNamed(v);
            },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                  value: Routes.log, child: Text(S.logSystem)),
              PopupMenuItem<String>(
                  value: Routes.logQb, child: Text(S.logServer)),
            ],
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: af(context, 12)),
              child: Text(
                S.logTitle,

                style: (Theme.of(context).textTheme.titleSmall ??
                        Theme.of(context).textTheme.bodyMedium)
                    ?.copyWith(
                  fontSize: af(context, 14),
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).appBarTheme.foregroundColor ??
                      Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: const AppDrawer(),

      body: Stack(
        children: <Widget>[
          AutoRefresh(
            onTick: () async {
              final ServerController sc = Get.find<ServerController>();
              unawaited(sc.refreshAllServers());
            },
        child: Obx(() {
          if (ctrl.isBusy.value && ctrl.servers.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ctrl.servers.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Image.asset('assets/images/empty.webp', width: af(context, 96)),
                  SizedBox(height: af(context, 12)),
                  Text('暂无服务器', style: TextStyle(fontSize: af(context, 12))),
                  const SizedBox(height: 4),
                  Text(
                    '点击 + 添加；无需登录',
                    style: TextStyle(fontSize: af(context, 10)),
                  ),
                ],
              ),
            );
          }

          final Map<String, List<ServerData>> groups =
              Formatter.getServersGroupData(
            ctrl.servers,
            enableGroup: kEnableServerGroup,
          );

          return Column(
            children: <Widget>[
              _totalSpeedPanel(context, ctrl),

              Expanded(
                child: SlidableAutoCloseGroup(
                  child: _serverList(context, ctrl, groups),
                ),
              ),
            ],
          );
          }),
          ),

          Positioned.fill(
            child: DraggableFab(
              topInset: kToolbarHeight + MediaQuery.of(context).padding.top,

              initialYRatio: DraggableFab.listPageInitialYRatio,
              onPressed: () async {
                AppLog.instance.act('服务器列表', '悬浮按钮[添加服务器]');
                if (ctrl.servers.length >= ServerController.kMaxServers) {
                  await showServerLimitDialog(context);
                  return;
                }
                showServerDialog(context);
              },
            ),
          ),
        ],
      ),
      ),
      ],
      ),
    );
  }

  Widget _serverList(
    BuildContext context,
    ServerController ctrl,
    Map<String, List<ServerData>> groups,
  ) {
    if (!kEnableServerGroup) {
      return ReorderableListView.builder(
        padding: EdgeInsets.only(bottom: af(context, 96)),
        itemCount: ctrl.servers.length,

        onReorderItem: ctrl.reorderServer,

        proxyDecorator: _serverDragProxy,
        itemBuilder: (BuildContext ctx, int i) {
          final ServerData s = ctrl.servers[i];
          return KeyedSubtree(
            key: ValueKey<String>('srv-${s.id}'),

            child: AppPageTheme(
              page: AppPageKey.serverCard,
              applyCardBackground: true,
              child: _serverPanel(ctx, ctrl, s),
            ),
          );
        },
      );
    }

    return ListView(
      padding: EdgeInsets.only(bottom: af(context, 96)),
      children: <Widget>[
        for (final MapEntry<String, List<ServerData>> e in groups.entries)
          ...<Widget>[
            _groupPanel(context, e.key, e.value),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: e.value.length,
              onReorderItem: (int from, int to) => ctrl.reorderWithinGroup(
                e.value.map((ServerData s) => s.id).toList(),
                from,
                to,
              ),

              proxyDecorator: _serverDragProxy,
              itemBuilder: (BuildContext ctx, int i) {
                final ServerData s = e.value[i];
                return KeyedSubtree(
                  key: ValueKey<String>('srv-${s.id}'),
                  child: AppPageTheme(
                    page: AppPageKey.serverCard,
                    applyCardBackground: true,
                    child: _serverPanel(ctx, ctrl, s),
                  ),
                );
              },
            ),
          ],
      ],
    );
  }

  Widget _groupPanel(
    BuildContext context,
    String name,
    List<ServerData> list,
  ) {
    final ServerController ctrl = Get.find<ServerController>();
    int up = 0;
    int dl = 0;
    int count = 0;
    for (final ServerData raw in list) {
      final ServerData s = ctrl.withSnapshot(raw);
      up += s.totalUpSpeed;
      dl += s.totalDlSpeed;
      count += s.totalTorrents;
    }
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.fromLTRB(af(context, 12), af(context, 10), af(context, 12), 2),
      padding: EdgeInsets.symmetric(horizontal: af(context, 10), vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: af(context, 11), fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          Text(S.countLabel(count), style: TextStyle(fontSize: af(context, 10))),
          const Spacer(),
          Text('${S.upArrow}${Formatter.setSpeed(up)}',
              style: TextStyle(fontSize: af(context, 10))),
          SizedBox(width: af(context, 8)),
          Text('${S.downArrow}${Formatter.setSpeed(dl)}',
              style: TextStyle(fontSize: af(context, 10))),
        ],
      ),
    );
  }

  Widget _totalSpeedPanel(BuildContext context, ServerController ctrl) {
    return Obx(() {

      final TotalsSnapshot v = ctrl.totalsView;
      return ServerStatsPanel(
        dlSpeed: v.dlSpeed,
        upSpeed: v.upSpeed,
        counts: v.counts,
        serversOnline: v.serversOnline,
        serversTotal: v.serversTotal,
        totals: v.totals,
        expanded: _totalExpanded.value,
        onToggle: _toggleTotalExpanded,
        hasData: v.available,
      );
    });
  }

  Widget _serverPanel(
    BuildContext context,
    ServerController ctrl,
    ServerData raw,
  ) {
    final ServerData s = ctrl.withSnapshot(raw);

    return SlidableTile(
      margin: EdgeInsets.fromLTRB(af(context, 12), 6, af(context, 12), 6),
      motion: SlidableMotionKind.scroll,
      extentRatio: 0.30,

      slotCount: 2,

      borderRadius: BorderRadius.circular(AppTheme.radius),
      contentBackground: Theme.of(context).colorScheme.surfaceContainerLow,

      onSlideChanged: _onCardSlideChanged,
      startActions: <SlidableActionItem>[

        SlidableActionItem(
            icon: Icons.article,
            badgeColor: Colors.blue,
            tooltip: S.logTitle,
            onPressed: () => Get.toNamed(Routes.logQb, arguments: raw),
          ),
        SlidableActionItem(
          icon: Icons.build,
          badgeColor: Colors.indigoAccent,
          tooltip: S.srvPrefTitle,
          onPressed: () => Get.toNamed(Routes.serverSetting, arguments: raw),
        ),
      ],
      endActions: <SlidableActionItem>[
        SlidableActionItem(
          icon: Icons.create,
          badgeColor: Colors.indigoAccent,
          tooltip: S.edit,
          onPressed: () {
            AppLog.instance.act('服务器列表', '左滑[编辑]', target: raw.name);
            showServerDialog(context, editing: raw);
          },
        ),
        SlidableActionItem(
          icon: Icons.delete,
          badgeColor: Colors.red,
          tooltip: S.delete,
          onPressed: () async {
            if (!await confirmDeleteServer(context, raw)) {
              AppLog.instance.act('服务器列表', '左滑[删除]·取消', target: raw.name);
              return;
            }
            AppLog.instance.act('服务器列表', '左滑[删除]', target: raw.name);
            await ctrl.deleteServer(raw.id);
            Formatter.showToast('${S.srvDeleted}${raw.name}');
          },
        ),
      ],
      child: Card(

        margin: EdgeInsets.zero,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
        onTap: () {
          AppLog.instance.act('服务器列表', '卡片[进入种子列表]', target: raw.name);
          ctrl.select(raw);
          Get.toNamed(Routes.torrents);
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(af(context, 10), af(context, 8), 6, af(context, 8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _cardHeader(context, ctrl, s, raw),
              const SizedBox(height: 6),

              Obx(() {
                final ConnStatus stNow =
                    ctrl.connStatus[s.id] ?? ConnStatus.idle;

                final List<Torrent> liveTs = ctrl.torrentsOf(raw.id);

                if (stNow == ConnStatus.failed) {
                  return _statsRefreshingPlaceholder(
                    context,
                    error: ctrl.connError[s.id],

                    errorIsFinal: ctrl.isSuspended(s.id),
                  );
                }
                if (liveTs.isEmpty) {
                  return _statsRefreshingPlaceholder(context);
                }
                final ServerData live = raw.copyWith(torrents: liveTs);
                final ServerSpeedLimit limit = ctrl.limitOf(s.id);

                final ColorScheme cs = Theme.of(context).colorScheme;

                final Brightness br = Theme.of(context).brightness;
                final Color dlColor = adaptSemantic(kSemanticDownload, br);
                final Color upColor = adaptSemantic(kSemanticUpload, br);
                final Color actColor = adaptSemantic(kSemanticActive, br);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[

                    MetricRow(
                      gap: 6,
                      inline: true,
                      valueSize: 13,
                      labelSize: 8.5,
                      minValueSize: 9,
                      items: <MetricItem>[
                        MetricItem(
                          value: '${live.totalTorrents}',
                          label: S.fieldCount,
                          color: cs.onSurface,
                        ),
                        MetricItem(
                          value: '${live.totalDownloading}',
                          label: S.fieldDlLoading,
                          color: dlColor,
                        ),
                        MetricItem(
                          value: '${live.totalSeeding}',
                          label: S.stSeeding,
                          color: upColor,
                        ),
                        MetricItem(
                          value: '${live.totalUploading}',
                          label: S.fieldUpLoading,
                          color: actColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    MetricRow(
                      gap: 6,
                      inline: true,
                      valueSize: 13,
                      labelSize: 8.5,
                      minValueSize: 9,
                      items: <MetricItem>[
                        MetricItem(
                          value: '${live.totalPausedDL}',
                          label: S.stPausedDl,
                          color: cs.onSurfaceVariant,
                        ),
                        MetricItem(
                          value: '${live.totalPausedUP}',
                          label: S.stPausedUp,
                          color: cs.onSurfaceVariant,
                        ),
                        MetricItem(
                          value: '${live.totalChecking}',
                          label: S.fieldVerifyState,
                          color: adaptSemantic(kSemanticPeer, br),
                        ),
                        MetricItem(
                          value: '${live.totalError}',
                          label: S.error,
                          color: adaptSemantic(kSemanticError, br),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),

                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(height: 6),

                    MetricRow(
                      gap: 8,
                      valueSize: 12,
                      labelSize: 8.5,
                      iconSize: 12,
                      items: <MetricItem>[
                        MetricItem(
                          icon: Icons.arrow_upward_rounded,
                          value: Formatter.setSpeed(live.totalUpSpeed),
                          label:
                              '${S.chartLabelUpload}${Formatter.setSpeedLimit(limit.up)}',
                          color: upColor,
                        ),
                        MetricItem(
                          icon: Icons.arrow_downward_rounded,
                          value: Formatter.setSpeed(live.totalDlSpeed),
                          label:
                              '${S.chartLabelDownload}${Formatter.setSpeedLimit(limit.dl)}',
                          color: dlColor,
                        ),
                        MetricItem(
                          icon: Icons.storage_rounded,
                          value: Formatter.setSize(live.totalSize),
                          label: S.fieldSize,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _cardHeader(
    BuildContext context,
    ServerController ctrl,
    ServerData s,
    ServerData raw,
  ) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {

        final double badgeMax = (c.maxWidth -
                _kHeaderLogoBox -
                _kPrivacyBtnBox -
                _kNameGap -
                _kNameMinWidth)
            .clamp(0.0, double.infinity)
            .toDouble();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              s.isQbittorrent
                  ? 'assets/images/qbittorrent.png'
                  : 'assets/images/transmission.png',
              width: af(context, 28),
              height: af(context, 28),
            ),
            SizedBox(width: af(context, 8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: af(context, 13),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Obx(() {
                        final ConnStatus st =
                            ctrl.connStatus[s.id] ?? ConnStatus.idle;
                        final bool checking =
                            ctrl.lanChecking.contains(s.id);
                        final bool onLan = ctrl.lanUsing[s.id] ?? false;
                        final bool busy =
                            ctrl.manualRefreshing.contains(s.id);
                        final bool refreshing =
                            busy || st == ConnStatus.connecting || checking;
                        final bool showBadge =
                            s.hasLan || st != ConnStatus.idle;
                        final bool suspended = ctrl.isSuspended(s.id);
                        final bool failed = st == ConnStatus.failed;
                        final bool showRetry = suspended || failed;

                        final String verText =
                            (refreshing || failed)
                                ? ''
                                : ctrl.serverVersion[s.id] ?? '';
                        final bool showIo = !failed &&
                            s.isQbittorrent &&
                            ctrl.ioJobs.containsKey(s.id) &&
                            !refreshing;
                        final String verTag = '${_verTag(s)} $verText';
                        final int ioJobs = ctrl.ioJobs[s.id] ?? 0;
                        final List<_BadgeEntry> badges = <_BadgeEntry>[
                          if (busy)
                            _BadgeEntry(
                              widget: _refreshingChip(context),
                              width: _chipWidth('刷新中', lead: 13),
                            ),
                          if (showBadge)
                            _BadgeEntry(
                              widget: _connBadge(
                                context,
                                status: st,
                                checking: checking,
                                onLan: onLan,
                                error: ctrl.connError[s.id],
                              ),
                              width: _chipWidth(
                                _connBadgeLabel(
                                  status: st,
                                  checking: checking,
                                  onLan: onLan,
                                ),
                              ),
                            ),
                          if (verText.isNotEmpty)
                            _BadgeEntry(
                              widget: _versionChip(context, verTag),
                              width: _chipWidth(verTag, lead: 0),
                            ),
                          if (showIo)
                            _BadgeEntry(
                              widget: IoChip(jobs: ioJobs),
                              width: _chipWidth('I/O: $ioJobs',
                                  fontSize: af(context, 8), padH: 3, lead: 0),
                            ),
                          if (showRetry)
                            _BadgeEntry(
                              widget: _retryButton(
                                context,
                                onPressed: () {
                                  AppLog.instance.act('服务器列表',
                                      '卡片[重试]',
                                      target: raw.name);
                                  ctrl.retryOne(raw);
                                },
                              ),
                              width: _chipWidth(S.retry,
                                  padH: 7, lead: 14),
                            ),
                        ];
                        return _badgeStrip(badgeMax, badges);
                      }),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${s.type} · ${s.displayAddress}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: af(context, 10)),
                  ),
                ],
              ),
            ),
            Obx(() {
              final ServerData cur = ctrl.servers.firstWhere(
                (ServerData e) => e.id == raw.id,
                orElse: () => raw,
              );
              final bool allHidden = cur.hideAddress && cur.hidePort;
              return IconButton(
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints:
                    BoxConstraints.tightFor(width: af(context, 30), height: af(context, 30)),
                tooltip: allHidden ? S.srvShowPrivacy : S.srvHidePrivacy,
                icon: Icon(
                  allHidden ? Icons.visibility_off : Icons.visibility,
                  size: af(context, 18),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: () async {
                  AppLog.instance.act('服务器列表', '卡片[隐私]',
                      target: raw.name,
                      detail: allHidden ? '显示地址与端口' : '隐藏地址与端口');
                  await ctrl.toggleHideAddressPort(
                    raw.id,
                    hide: ServerController.nextPrivacyHidden(
                      hideAddress: cur.hideAddress,
                      hidePort: cur.hidePort,
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  Widget _connBadge(
    BuildContext context, {
    required ConnStatus status,
    required bool checking,
    required bool onLan,
    String? error,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool failed = status == ConnStatus.failed;
    final bool busy = !failed && (status == ConnStatus.connecting || checking);

    final Color tint = failed
        ? Colors.red
        : (busy ? cs.primary : (onLan ? Colors.green : cs.onSurfaceVariant));
    final IconData icon = failed
        ? Icons.error_outline
        : (busy ? Icons.hourglass_top : (onLan ? Icons.wifi : Icons.public));
    final String label = _connBadgeLabel(
      status: status,
      checking: checking,
      onLan: onLan,
    );

    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: failed
            ? Colors.red.withValues(alpha: 0.18)
            : (onLan && !busy
                ? Colors.green.withValues(alpha: 0.15)
                : cs.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: af(context, 10), color: tint),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: af(context, 9), color: tint),
          ),
        ],
      ),
    );

    final Widget body = failed && error != null && error.isNotEmpty
        ? Tooltip(message: error, child: chip)
        : chip;

    return failed ? _BlinkingBadge(child: body) : body;
  }

  Widget _retryButton(BuildContext context, {required VoidCallback onPressed}) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.55),
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.refresh, size: af(context, 11), color: cs.primary),
              const SizedBox(width: 3),
              Text(
                S.retry,
                style: TextStyle(fontSize: af(context, 9), color: cs.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _versionChip(BuildContext context, String text) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: af(context, 9), color: cs.onTertiaryContainer),
      ),
    );
  }

  String _verTag(ServerData s) => s.isQbittorrent ? 'qB' : 'TR';

  Widget _refreshingChip(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: af(context, 9),
            height: 9,
            child: CircularProgressIndicator(
              strokeWidth: 1.4,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
          const SizedBox(width: 4),
          Text('刷新中', style: TextStyle(fontSize: af(context, 9), color: cs.primary)),
        ],
      ),
    );
  }

  static String _failureLine(String error, {bool isFinal = false}) {
    if (isFinal) return error;
    const List<String> prefixed = <String>[
      '刷新失败：',
      '登录失败：',
      '连接失败：',
    ];
    for (final String p in prefixed) {
      if (error.startsWith(p)) return error;
    }
    for (final String full in <String>[
      S.srvIpBanned,
      S.srvCredsMissing,
      S.srvConfigIncomplete,
    ]) {
      if (error.startsWith(full)) return error;
    }
    return '刷新失败：$error';
  }

  Widget _statsRefreshingPlaceholder(
    BuildContext context, {
    String? error,
    bool errorIsFinal = false,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final double k = adaptiveScale(context);
    final Color bar = cs.onSurface.withValues(alpha: 0.08);
    final Color barSoft = cs.onSurface.withValues(alpha: 0.055);

    Widget block(double? w, double h, {Color? c}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: c ?? bar,
            borderRadius: BorderRadius.circular(AppTheme.radiusBar),
          ),
        );

    final Widget speedBand = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        block(56 * k, 20 * k),
        SizedBox(width: af(context, 14) * k),
        block(84 * k, 20 * k),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            block(14 * k, 12 * k),
            SizedBox(height: 2 * k),
            block(26 * k, 8 * k, c: bar),
          ],
        ),
      ],
    );

    final Widget legend = Row(
      children: <Widget>[
        for (int i = 0; i < 6; i++)
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 5 * k,
                  height: 5 * k,
                  decoration: BoxDecoration(
                    color: bar,
                    borderRadius: BorderRadius.circular(1.5 * k),
                  ),
                ),
                SizedBox(width: 3 * k),
                block((16.0 + (i % 2) * 6) * k, 11 * k, c: barSoft),
              ],
            ),
          ),
      ],
    );

    final Widget bottom = Row(
      children: <Widget>[
        for (int i = 0; i < 3; i++)
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                block(11 * k, 11 * k, c: barSoft),
                SizedBox(width: 3 * k),
                block((34.0 - i * 7) * k, 12 * k, c: barSoft),
              ],
            ),
          ),
      ],
    );

    return SizedBox(
      key: const Key('serverStatsPlaceholder'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          speedBand,
          SizedBox(height: 9 * k),
          block(double.infinity, 7 * k, c: barSoft),
          SizedBox(height: 6 * k),
          legend,
          SizedBox(height: 8 * k),
          block(double.infinity, 1, c: bar),
          SizedBox(height: 7 * k),
          bottom,
          if (error != null && error.isNotEmpty) ...<Widget>[
            SizedBox(height: 8 * k),
            Row(
              children: <Widget>[
                Icon(Icons.error_outline, size: af(context, 12) * k, color: cs.error),
                SizedBox(width: 4 * k),
                Expanded(
                  child: Text(
                    _failureLine(error, isFinal: errorIsFinal),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9 * k, color: cs.error),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BlinkingBadge extends StatefulWidget {
  const _BlinkingBadge({required this.child});

  final Widget child;

  @override
  State<_BlinkingBadge> createState() => _BlinkingBadgeState();
}

class _BlinkingBadgeState extends State<_BlinkingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.25).animate(_ctrl),
      child: widget.child,
    );
  }
}

class _SpinningRefreshIcon extends StatefulWidget {
  const _SpinningRefreshIcon({
    required this.spinning,
    required this.onPressed,
  });

  final bool spinning;
  final Future<void> Function() onPressed;

  @override
  State<_SpinningRefreshIcon> createState() => _SpinningRefreshIconState();
}

class _SpinningRefreshIconState extends State<_SpinningRefreshIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_SpinningRefreshIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning == oldWidget.spinning) return;
    if (widget.spinning) {
      _ctrl.repeat();
    } else {
      _ctrl
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: S.srvManualRefresh,
      onPressed: widget.spinning ? null : () => widget.onPressed(),
      icon: RotationTransition(
        turns: _ctrl,
        child: Icon(
          Icons.refresh,
          size: AppTheme.iconSize,
          color: widget.spinning
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : null,
        ),
      ),
    );
  }
}

Widget _serverDragProxy(
  Widget child,
  int index,
  Animation<double> animation,
) =>
    AnimatedBuilder(
      animation: animation,
      builder: (BuildContext _, Widget? c) => Material(
        elevation: 8,
        shadowColor: const Color(0x59000000),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Transform.scale(
          scale: 1 + 0.02 * Curves.easeOut.transform(animation.value),
          child: c,
        ),
      ),
      child: child,
    );
