import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
import '../widgets/server_stats_panel.dart';
import '../widgets/slidable_tile.dart';
import 'drawer_page.dart';
import 'server_dialog.dart';

const bool kEnableServerGroup = false;

const double _kStatsBlockHeight = 82;

class ServerListPage extends StatefulWidget {
  const ServerListPage({super.key});

  @override
  State<ServerListPage> createState() => _ServerListPageState();
}

class _ServerListPageState extends State<ServerListPage> {
  bool _cardOpen = false;
  bool _drawerOpen = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(StartupUpdatePrompt.runOnce());
    });
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
            icon: const Icon(Icons.more_vert, size: AppTheme.iconSize),
            onSelected: (String v) => Get.toNamed(v),
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: Routes.log, child: Text('日志')),
              PopupMenuItem<String>(
                  value: Routes.logQb, child: Text('服务器日志')),
            ],
          ),
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
                  Image.asset('assets/images/empty.webp', width: 96),
                  const SizedBox(height: 12),
                  const Text('暂无服务器', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text(
                    '点击 + 添加；无需登录',
                    style: TextStyle(fontSize: 10),
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
              onPressed: () {
                AppLog.instance.act('服务器列表', '悬浮按钮[添加服务器]');
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
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: ctrl.servers.length,

        onReorderItem: ctrl.reorderServer,

        proxyDecorator: _noProxyMaterial,
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
      padding: const EdgeInsets.only(bottom: 96),
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

              proxyDecorator: _noProxyMaterial,
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
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          Text(S.countLabel(count), style: const TextStyle(fontSize: 10)),
          const Spacer(),
          Text('${S.upArrow}${Formatter.setSpeed(up)}',
              style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 8),
          Text('${S.downArrow}${Formatter.setSpeed(dl)}',
              style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _totalSpeedPanel(BuildContext context, ServerController ctrl) {
    return Obx(() => ServerStatsPanel(
          dlSpeed: ctrl.totalDlSpeed,
          upSpeed: ctrl.totalUpSpeed,
          counts: ctrl.totalStatusCounts,
          serversOnline: ctrl.onlineServerCount,
          serversTotal: ctrl.servers.length,
        ));
  }

  Widget _serverPanel(
    BuildContext context,
    ServerController ctrl,
    ServerData raw,
  ) {
    final ServerData s = ctrl.withSnapshot(raw);

    return SlidableTile(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
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
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Image.asset(
                    s.isQbittorrent
                        ? 'assets/images/qbittorrent.png'
                        : 'assets/images/transmission.png',
                    width: 30,
                    height: 30,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          ],
                        ),
                        Text(
                          '${s.type} · ${s.displayAddress}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),

                        Obx(() {
                          final ConnStatus st =
                              ctrl.connStatus[s.id] ?? ConnStatus.idle;
                          final bool checking = ctrl.lanChecking.contains(s.id);
                          final bool onLan = ctrl.lanUsing[s.id] ?? false;

                        final bool busy = ctrl.manualRefreshing.contains(s.id);
                        final bool refreshing =
                            busy || st == ConnStatus.connecting || checking;
                        final bool showBadge =
                            s.hasLan || st != ConnStatus.idle;

                          final bool showIo = s.isQbittorrent &&
                              ctrl.ioJobs.containsKey(s.id) &&
                              !refreshing;

                          final String verText =
                              refreshing ? '' : ctrl.serverVersion[s.id] ?? '';

                          final bool suspended = ctrl.isSuspended(s.id);
                          final bool showRetry = suspended ||
                              st == ConnStatus.failed;

                          if (!showBadge &&
                              verText.isEmpty &&
                              !showIo &&
                              !busy &&
                              !showRetry) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 3),

                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: <Widget>[

                                      if (busy) _refreshingChip(context),
                                      if (showBadge)
                                        _connBadge(
                                          context,
                                          status: st,
                                          checking: checking,
                                          onLan: onLan,
                                          error: ctrl.connError[s.id],
                                        ),
                                      if (suspended) _suspendedChip(context),
                                      if (verText.isNotEmpty)
                                        _versionChip(
                                            context, '${_verTag(s)} $verText'),
                                      if (showIo)
                                        IoChip(jobs: ctrl.ioJobs[s.id] ?? 0),
                                    ],
                                  ),
                                ),
                                if (showRetry) ...<Widget>[
                                  const SizedBox(width: 6),
                                  _retryButton(
                                    context,
                                    onPressed: () {
                                      AppLog.instance.act(
                                          '服务器列表', '卡片[重试]', target: raw.name);
                                      ctrl.retryOne(raw);
                                    },
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  PopupMenuButton<String>(
                    onSelected: (String v) async {
                      if (v == 'hide') {
                        AppLog.instance.act('服务器列表', '卡片菜单[隐藏地址]',
                            target: raw.name,
                            detail: raw.hideAddress ? '改为显示' : '改为隐藏');
                        await ctrl.toggleHideAddress(raw.id);
                      } else if (v == 'port') {
                        AppLog.instance.act('服务器列表', '卡片菜单[隐藏端口]',
                            target: raw.name,
                            detail: raw.hidePort ? '改为显示' : '改为隐藏');

                        await ctrl.toggleHidePort(raw.id);
                      }
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'hide',
                        child: Text(
                          raw.hideAddress ? '显示服务器地址' : S.srvHideAddress,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'port',
                        child: Text(
                          raw.hidePort ? '显示端口' : S.srvHidePort,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

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

                int num(String key, int Function() real) => real();
                final ColorScheme cs = Theme.of(context).colorScheme;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _statCell(context, Icons.list_alt,
                              num('total', () => live.totalTorrents), S.fieldCount, cs.onSurface),
                        ),
                        Expanded(
                          child: _statCell(
                              context,
                              Icons.arrow_circle_down,
                              num('downloading', () => live.totalDownloading),
                              S.fieldDlLoading,
                              cs.secondary),
                        ),
                        Expanded(
                          child: _statCell(context, Icons.arrow_circle_up,
                              num('seeding', () => live.totalSeeding), S.stSeeding, cs.primary),
                        ),
                        Expanded(
                          child: _statCell(context, Icons.upload,
                              num('uploading', () => live.totalUploading), S.fieldUpLoading, cs.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _statCell(context, Icons.pause,
                              num('pausedDL', () => live.totalPausedDL), S.stPausedDl, cs.tertiary),
                        ),
                        Expanded(
                          child: _statCell(
                              context,
                              Icons.pause_circle,
                              num('pausedUP', () => live.totalPausedUP),
                              S.stPausedUp,
                              cs.tertiary),
                        ),
                        Expanded(
                          child: _statCell(
                              context,
                              Icons.fact_check_outlined,
                              num('checking', () => live.totalChecking),
                              S.fieldVerifyState,
                              cs.onSurfaceVariant),
                        ),
                        Expanded(
                          child: _statCell(context, Icons.error_outline,
                              num('error', () => live.totalError), S.error, cs.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: <Widget>[
                        Expanded(
                          flex: 2,
                          child: _speedCell(context, Icons.arrow_circle_up,
                              num('upSpeed', () => live.totalUpSpeed), cs.primary),
                        ),
                        Expanded(
                          flex: 2,
                          child: _speedCell(context, Icons.arrow_circle_down,
                              num('dlSpeed', () => live.totalDlSpeed), cs.secondary),
                        ),

                        Expanded(
                          flex: 3,
                          child: _sizeCell(
                              Formatter.setSize(num('size', () => live.totalSize)),
                              cs.onSurfaceVariant),
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
    final String label = failed

        ? L.t('连接失败')
        : (busy ? L.t('连接中...') : (onLan ? L.t('局域网') : L.t('公网')));

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
          Icon(icon, size: 10, color: tint),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: tint),
          ),
        ],
      ),
    );

    final Widget body = failed && error != null && error.isNotEmpty
        ? Tooltip(message: error, child: chip)
        : chip;

    return failed ? _BlinkingBadge(child: body) : body;
  }

  Widget _suspendedChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.pause_circle_outline, size: 10, color: Colors.orange),
          const SizedBox(width: 3),
          Text(
            S.srvSuspended,
            style: const TextStyle(fontSize: 9, color: Colors.orange),
          ),
        ],
      ),
    );
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
              Icon(Icons.refresh, size: 11, color: cs.primary),
              const SizedBox(width: 3),
              Text(
                S.retry,
                style: TextStyle(fontSize: 9, color: cs.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCell(
    BuildContext context,
    IconData icon,
    int value,
    String label,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _speedCell(
    BuildContext context,
    IconData icon,
    int bytesPerSecond,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            Formatter.setSpeed(bytesPerSecond),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: color),
          ),
        ),
      ],
    );
  }

  Widget _sizeCell(String text, Color color) {
    return Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 10, color: color),
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
        style: TextStyle(fontSize: 9, color: cs.onTertiaryContainer),
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
            width: 9,
            height: 9,
            child: CircularProgressIndicator(
              strokeWidth: 1.4,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
          const SizedBox(width: 4),
          Text('刷新中', style: TextStyle(fontSize: 9, color: cs.primary)),
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
    final Color barColor = cs.onSurface.withValues(alpha: 0.08);
    final Color barLabel = cs.onSurface.withValues(alpha: 0.14);

    Widget cell({required double valueWidth}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: valueWidth,
              height: 11,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusBar),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 26,
              height: 8,
              decoration: BoxDecoration(
                color: barLabel,
                borderRadius: BorderRadius.circular(AppTheme.radiusBar),
              ),
            ),
          ],
        );

    return SizedBox(

      key: const Key('serverStatsPlaceholder'),
      height: error == null ? _kStatsBlockHeight : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (int i = 0; i < 4; i++)
                Expanded(child: cell(valueWidth: 22 + (i % 2) * 6.0)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              for (int i = 0; i < 4; i++)
                Expanded(child: cell(valueWidth: 20 + (i % 2) * 8.0)),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: Container(
                  width: 64,
                  height: 11,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusBar),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  width: 64,
                  height: 11,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusBar),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 48,
                    height: 11,
                    decoration: BoxDecoration(
                      color: barLabel,
                      borderRadius: BorderRadius.circular(AppTheme.radiusBar),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (error != null && error.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Icons.error_outline, size: 12, color: cs.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _failureLine(error, isFinal: errorIsFinal),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: cs.error),
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

Widget _noProxyMaterial(
  Widget child,
  int index,
  Animation<double> animation,
) =>
    child;
