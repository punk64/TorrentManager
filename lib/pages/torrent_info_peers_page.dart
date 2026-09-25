import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../controllers/torrent_controller.dart';
import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../utils/ip_geo.dart';
import '../utils/strings.dart';
import '../app/adaptive.dart';

class TorrentInfoPeersPage extends StatefulWidget {
  const TorrentInfoPeersPage({super.key});

  @override
  State<TorrentInfoPeersPage> createState() => _TorrentInfoPeersPageState();
}

enum PeerSort { progress, dlSpeed, upSpeed, ip }

class _Geo {
  const _Geo.loading()
      : loading = true,
        text = '';
  const _Geo.value(this.text) : loading = false;

  final bool loading;
  final String text;
}

class _TorrentInfoPeersPageState extends State<TorrentInfoPeersPage> {
  final TorrentController ctrl = Get.find<TorrentController>();
  final ServerController sc = Get.find<ServerController>();

  PeerSort _sort = PeerSort.dlSpeed;
  bool _asc = false;

  final Map<String, Rx<_Geo>> _geo = <String, Rx<_Geo>>{};

  int _num(dynamic v) => (v as num?)?.toInt() ?? 0;

  List<Map<String, dynamic>> get _sorted {
    final List<Map<String, dynamic>> list =
        List<Map<String, dynamic>>.of(ctrl.peers);
    int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      switch (_sort) {
        case PeerSort.dlSpeed:
          return _num(a['dl_speed'] ?? a['rateToClient'])
              .compareTo(_num(b['dl_speed'] ?? b['rateToClient']));
        case PeerSort.upSpeed:
          return _num(a['up_speed'] ?? a['rateToPeer'])
              .compareTo(_num(b['up_speed'] ?? b['rateToPeer']));
        case PeerSort.ip:
          return ((a['ip'] ?? a['address']) ?? '')
              .toString()
              .compareTo(((b['ip'] ?? b['address']) ?? '').toString());
        case PeerSort.progress:
          return ((a['progress'] as num?) ?? 0)
              .compareTo((b['progress'] as num?) ?? 0);
      }
    }

    list.sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
        _asc ? cmp(a, b) : cmp(b, a));
    return list;
  }

  static const PageStorageKey<String> _listKey =
      PageStorageKey<String>('torrent_info_peers_list');

  static const int _geoLimit = 400;

  Rx<_Geo> _geoOf(String ip) {
    final Rx<_Geo>? exist = _geo[ip];
    if (exist != null) return exist;
    if (_geo.length >= _geoLimit) _pruneGeo();

    if (!Formatter.ipNeedsLookup(ip)) {
      final Rx<_Geo> g = _Geo.value(Formatter.getIpInfo(ip)).obs;
      _geo[ip] = g;
      return g;
    }
    final Rx<_Geo> g = const _Geo.loading().obs;
    _geo[ip] = g;
    unawaited(_fetchGeo(ip));
    return g;
  }

  void _pruneGeo() {
    final Set<String> live = <String>{};
    for (final Map<String, dynamic> p in ctrl.peers) {
      final String ip = ((p['ip'] ?? p['address']) ?? '').toString();
      if (ip.isNotEmpty) live.add(ip);
    }
    _geo.removeWhere((String k, Rx<_Geo> _) => !live.contains(k));

    if (_geo.length >= _geoLimit) _geo.clear();
  }

  Future<void> _fetchGeo(String ip) async {
    final String? text = await IpGeo.instance.lookup(ip);
    if (!mounted) return;
    _geo[ip]?.value = _Geo.value(text ?? S.unknown);
  }

  String _totalText(Map<String, dynamic> p) {
    final num up = (p['uploaded'] as num?) ?? 0;
    final num dl = (p['downloaded'] as num?) ?? 0;
    return '${S.ioUploadPrefix}${Formatter.setSizeCompact(up)}'
        ' · ${S.ioDownloadPrefix}${Formatter.setSizeCompact(dl)}';
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    Formatter.showToast(S.peerCopied(text));
  }

  Future<void> _ban(String target) async {
    if (sc.current.value?.isQbittorrent != true) {
      Formatter.showToast('仅 qBittorrent 支持封禁 Peer', isError: true);
      return;
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(S.peerBanTitle, style: TextStyle(fontSize: af(context, 14))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(S.peerBanConfirm(target),
                style: TextStyle(fontSize: af(context, 12))),
            const SizedBox(height: 6),
            Text(
              S.peerBanNoDuration,
              style: TextStyle(fontSize: af(context, 10), color: Theme.of(ctx).hintColor),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.confirmExecute),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await sc.qb.showBanPeers(target);

      AppLog.instance.op('封禁 Peer：$target'
          '（${ctrl.current.value?.name ?? '-'} · ${sc.current.value?.name ?? '-'}）',
          scope: sc.current.value?.logScope);
      Formatter.showToast('${S.peerBanOk}$target');
    } catch (e) {
      AppLog.instance.error('封禁 Peer 失败：$target · ${Formatter.safeErr(e)}',
          scope: sc.current.value?.logScope);
      Formatter.showToast('${S.peerBanFail}: ${Formatter.safeErr(e)}',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[

        Padding(
          padding: EdgeInsets.fromLTRB(af(context, 10), af(context, 8), af(context, 10), 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                S.fieldSort,
                style: TextStyle(fontSize: af(context, 10), color: cs.outline),
              ),
              for (final PeerSort s in PeerSort.values)
                Tooltip(
                  message: _sortTip(s),
                  child: ChoiceChip(
                    label:
                        Text(_sortLabel(s), style: TextStyle(fontSize: af(context, 11))),
                    selected: _sort == s,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _sort = s),
                  ),
                ),
              Tooltip(
                message: '切换升序 / 降序',
                child: ActionChip(
                  avatar: Icon(
                    _asc ? Icons.arrow_upward : Icons.arrow_downward,
                    size: af(context, 14),
                  ),

                  label: Text(_dirLabel, style: TextStyle(fontSize: af(context, 11))),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _asc = !_asc),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Obx(() {
            final List<Map<String, dynamic>> peers = _sorted;
            if (peers.isEmpty) {
              return Center(
                child: Text('暂无 Peer 数据', style: TextStyle(fontSize: af(context, 12))),
              );
            }

            return ListView.separated(
              key: _listKey,
              itemCount: peers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int i) {
                final Map<String, dynamic> p = peers[i];
                final String ip = ((p['ip'] ?? p['address']) ?? '-').toString();
                final String port = (p['port'] ?? '').toString();
                final String client =
                    ((p['client'] ?? p['clientName']) ?? '-').toString();
                final double progress =
                    (p['progress'] as num?)?.toDouble() ?? 0.0;
                final int dl = _num(p['dl_speed'] ?? p['rateToClient']);
                final int up = _num(p['up_speed'] ?? p['rateToPeer']);
                final bool isQb = sc.current.value?.isQbittorrent == true;
                final String target =
                    port.isEmpty || port == '0' ? ip : '$ip:$port';

                final _Geo g = _geoOf(ip).value;

                return ListTile(
                  key: ValueKey<String>('peer_$ip'),
                  dense: true,
                  leading: Icon(Icons.devices, size: AppTheme.iconSize),

                  title: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[

                            Text(ip, style: TextStyle(fontSize: af(context, 12))),
                            _verBadge(cs, ip.contains(':') ? 'IPv6' : 'IPv4'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      _actions(cs, ip, target, isQb),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[

                        Row(
                          children: <Widget>[
                            Flexible(
                              flex: 5,
                              child: Text(
                                client,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: af(context, 10)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (g.loading)
                              SizedBox(
                                width: af(context, 10),
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: cs.outline,
                                ),
                              )
                            else if (g.text.isNotEmpty)
                              Flexible(
                                flex: 5,
                                child: Text(
                                  g.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style:
                                      TextStyle(fontSize: af(context, 9), color: cs.outline),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 1),

                        Row(
                          children: <Widget>[
                            Flexible(
                              flex: 6,
                              child: Text(
                                '↓${Formatter.setSpeed(dl)} ↑${Formatter.setSpeed(up)}'
                                ' · ${Formatter.setProgress(progress)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: af(context, 10)),
                              ),
                            ),
                            if (isQb) ...<Widget>[
                              const SizedBox(width: 6),
                              Flexible(
                                flex: 5,
                                child: Text(
                                  _totalText(p),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style:
                                      TextStyle(fontSize: af(context, 9), color: cs.outline),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _verBadge(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: cs.outline.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: af(context, 9), color: cs.outline, height: 1.15),
      ),
    );
  }

  Widget _actions(ColorScheme cs, String ip, String target, bool isQb) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _miniButton(
          icon: Icons.copy,
          tooltip: S.peerCopyIp,
          color: cs.outline,
          onPressed: () => _copy(ip),
        ),
        _miniButton(
          icon: Icons.copy_all,
          tooltip: S.peerCopyIpPort,
          color: cs.outline,
          onPressed: () => _copy(target),
        ),
        if (isQb)
          _miniButton(
            icon: Icons.block,
            tooltip: S.peerBanTitle,
            color: cs.error,
            onPressed: () => _ban(target),
          ),
      ],
    );
  }

  Widget _miniButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: af(context, 22),
      height: af(context, 22),
      child: IconButton(
        icon: Icon(icon, size: af(context, 15), color: color),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      ),
    );
  }

  String _sortLabel(PeerSort s) {
    switch (s) {
      case PeerSort.progress:
        return S.fieldProgress;
      case PeerSort.dlSpeed:
        return S.fieldDlSpeed;
      case PeerSort.upSpeed:
        return S.fieldUpSpeed;
      case PeerSort.ip:
        return S.fieldIp;
    }
  }

  String _sortTip(PeerSort s) {
    switch (s) {
      case PeerSort.progress:
        return '按${S.fieldProgress}排序';
      case PeerSort.dlSpeed:
        return '按${S.fieldDlSpeed}排序';
      case PeerSort.upSpeed:
        return '按${S.fieldUpSpeed}排序';
      case PeerSort.ip:
        return '按${S.fieldIp}排序';
    }
  }

  String get _dirLabel {
    switch (_sort) {
      case PeerSort.dlSpeed:
        return _asc ? '从慢到快' : '从快到慢';
      case PeerSort.upSpeed:
        return _asc ? '从慢到快' : '从快到慢';
      case PeerSort.progress:
        return _asc ? '从少到多' : '从多到少';
      case PeerSort.ip:
        return _asc ? '正序' : '倒序';
    }
  }
}
