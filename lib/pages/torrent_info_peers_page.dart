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

  final Set<String> _expanded = <String>{};

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
              .compareTo(_num(b['up_speed'] ?? a['rateToPeer']));
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

  Future<void> _addPeer() async {
    final s = sc.current.value;
    final t = ctrl.current.value;
    if (s == null || t == null) return;
    if (!s.isQbittorrent) {
      Formatter.showToast('仅 qBittorrent 支持添加 Peer', isError: true);
      return;
    }

    final TextEditingController input = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('添加 Peer', style: TextStyle(fontSize: af(context, 14))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('每行一个，格式 IP:端口（最多 10 个）',
                style: TextStyle(fontSize: af(context, 10), color: Theme.of(ctx).hintColor)),
            SizedBox(height: af(context, 8)),
            TextField(
              controller: input,
              maxLines: 3,
              style: TextStyle(fontSize: af(context, 11)),
              decoration: InputDecoration(
                hintText: '1.2.3.4:6881\n[::1]:6881',
                hintStyle: TextStyle(fontSize: af(context, 11)),
                border: const OutlineInputBorder(),
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
            onPressed: () => Navigator.of(ctx).pop(input.text.trim()),
            child: Text(S.confirmExecute),
          ),
        ],
      ),
    ).whenComplete(input.dispose);
    if (result == null || result.isEmpty) return;

    final List<String> peers = <String>[];
    for (final String line in result.split('\n')) {
      final String v = line.trim();
      if (v.isEmpty) continue;
      if (!v.contains(':') && !v.contains(' ')) {
        Formatter.showToast('格式无效：$v', isError: true);
        return;
      }
      peers.add(v);
      if (peers.length >= 10) break;
    }
    if (peers.isEmpty) return;

    await ctrl.addPeersTo(t.hash, peers);
    if (ctrl.lastActionOk.value == true) {
      if (mounted) Formatter.showToast('已添加 ${peers.length} 个 Peer');
    } else {
      if (mounted) {
        Formatter.showToast('${S.execFailed}: ${ctrl.error.value ?? ''}',
            isError: true);
      }
    }
  }

  // ─────────────────────────── 展示辅助 ───────────────────────────

  String? _flagOf(Map<String, dynamic> p, bool isQb) {
    if (!isQb) return null;
    final String cc = (p['country_code'] ?? '').toString().trim();
    if (cc.length != 2) return null;
    final int a = cc.codeUnitAt(0);
    final int b = cc.codeUnitAt(1);
    if (a < 0x41 || a > 0x5A || b < 0x41 || b > 0x5A) return null;
    const int base = 0x1F1E6;
    return String.fromCharCode(base + a - 0x41) +
        String.fromCharCode(base + b - 0x41);
  }

  /// qB flags / TR flagStr → 徽章字符列表（最多 6 个）
  List<String> _flagChars(Map<String, dynamic> p, bool isQb) {
    final String raw = isQb
        ? (p['flags'] ?? '').toString()
        : (p['flagStr'] ?? '').toString();
    if (raw.isEmpty) return const <String>[];
    final List<String> out = <String>[];
    for (int i = 0; i < raw.length && out.length < 6; i++) {
      final String c = raw[i].trim().toUpperCase();
      if (c.isEmpty) continue;
      if (!out.contains(c)) out.add(c);
    }
    return out;
  }

  Color _flagColor(String c, ColorScheme cs) {
    switch (c) {
      case 'D':
        return const Color(0xFF1A73E8);
      case 'U':
        return const Color(0xFF0F9D58);
      case 'E':
        return const Color(0xFF8E44AD);
      case 'K':
        return const Color(0xFFE8710A);
      default:
        return cs.outline;
    }
  }

  String? _flagDescOf(Map<String, dynamic> p, String c, bool isQb) {
    if (!isQb) return null;
    final String desc = (p['flags_desc'] ?? '').toString();
    if (desc.isEmpty) return null;
    for (final String part in desc.split(';')) {
      final String seg = part.trim();
      if (seg.startsWith(c) || seg.startsWith('$c:')) {
        return seg;
      }
    }
    return null;
  }

  String _peerKey(Map<String, dynamic> p) {
    final String ip = ((p['ip'] ?? p['address']) ?? '').toString();
    final String port = (p['port'] ?? '').toString();
    return '$ip:$port';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ColorScheme cs = Theme.of(context).colorScheme;
      final bool isQb = sc.current.value?.isQbittorrent == true;
      final bool canAddPeer = isQb && ctrl.capabilities.addPeers;
      return Column(
        children: <Widget>[

          _summaryBar(cs, isQb: isQb, canAddPeer: canAddPeer),
          _sortBar(cs),
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
                padding: EdgeInsets.fromLTRB(af(context, 10), 4, af(context, 10), af(context, 20)),
                itemCount: peers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 5),
                itemBuilder: (BuildContext context, int i) {
                  return _peerCard(context, peers[i], isQb: isQb);
                },
              );
            }),
          ),
        ],
      );
    });
  }

  Widget _summaryBar(ColorScheme cs, {required bool isQb, required bool canAddPeer}) {
    int dl = 0;
    int ul = 0;
    for (final Map<String, dynamic> p in ctrl.peers) {
      if (_num(p['dl_speed'] ?? p['rateToClient']) > 0) dl++;
      if (_num(p['up_speed'] ?? p['rateToPeer']) > 0) ul++;
    }
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(af(context, 10), af(context, 8), af(context, 10), 0),
      padding: EdgeInsets.symmetric(horizontal: af(context, 10), vertical: af(context, 7)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.75), width: 0.6),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '${ctrl.peers.length} 个 Peer',
                style: TextStyle(fontSize: af(context, 11), fontWeight: FontWeight.w600),
                children: <TextSpan>[
                  TextSpan(
                    text: ' · 下载中 ',
                    style: TextStyle(
                        fontSize: af(context, 10),
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant),
                  ),
                  TextSpan(
                    text: '$dl',
                    style: TextStyle(
                        fontSize: af(context, 11),
                        color: const Color(0xFF1A73E8),
                        fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: ' · 对其上传 ',
                    style: TextStyle(
                        fontSize: af(context, 10),
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant),
                  ),
                  TextSpan(
                    text: '$ul',
                    style: TextStyle(
                        fontSize: af(context, 11),
                        color: const Color(0xFF0F9D58),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (canAddPeer)
            SizedBox(
              height: af(context, 26),
              child: OutlinedButton.icon(
                icon: Icon(Icons.add, size: af(context, 13)),
                label: Text('添加 Peer', style: TextStyle(fontSize: af(context, 10))),
                onPressed: _addPeer,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 26),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sortBar(ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.fromLTRB(af(context, 10), af(context, 6), af(context, 10), 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
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
    );
  }

  Widget _peerCard(BuildContext context, Map<String, dynamic> p, {required bool isQb}) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String ip = ((p['ip'] ?? p['address']) ?? '-').toString();
    final String port = (p['port'] ?? '').toString();
    final String client =
        ((p['client'] ?? p['clientName']) ?? '-').toString();
    final double progress =
        (p['progress'] as num?)?.toDouble() ?? 0.0;
    final int dl = _num(p['dl_speed'] ?? p['rateToClient']);
    final int up = _num(p['up_speed'] ?? p['rateToPeer']);
    final String target =
        port.isEmpty || port == '0' ? ip : '$ip:$port';
    final String key = _peerKey(p);
    final bool expanded = _expanded.contains(key);

    final String? flag = _flagOf(p, isQb);
    final List<String> flagChars = _flagChars(p, isQb);
    final _Geo g = _geoOf(ip).value;

    final bool encrypted =
        isQb ? flagChars.contains('E') : p['isEncrypted'] == true;
    final bool utp = isQb
        ? (p['connection'] ?? '').toString().toLowerCase().contains('utp')
        : p['isUTP'] == true;
    final bool incoming = !isQb && p['isIncoming'] == true;

    return Container(
      padding: EdgeInsets.fromLTRB(af(context, 10), af(context, 8), af(context, 6), af(context, 8)),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.75), width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: () => setState(() {
              if (expanded) {
                _expanded.remove(key);
              } else {
                _expanded.add(key);
              }
            }),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (flag != null) ...<Widget>[
                      Text(flag, style: TextStyle(fontSize: af(context, 13))),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 0,
                        children: <Widget>[
                          Text(
                            ip,
                            style: TextStyle(
                              fontSize: af(context, 11.5),
                              fontWeight: FontWeight.w600,
                              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                            ),
                          ),
                          if (port.isNotEmpty && port != '0')
                            Text(
                              ':$port',
                              style: TextStyle(
                                fontSize: af(context, 10.5),
                                color: cs.outline,
                                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _verBadge(cs, ip.contains(':') ? 'IPv6' : 'IPv4'),
                    const SizedBox(width: 4),
                    for (final String c in flagChars) ...<Widget>[
                      _flagBadge(cs, c, isQb, p),
                      const SizedBox(width: 3),
                    ],
                    _miniButton(
                      icon: Icons.copy,
                      tooltip: S.peerCopyIp,
                      color: cs.outline,
                      onPressed: () => _copy(ip),
                    ),
                    const SizedBox(width: 2),
                    _miniButton(
                      icon: Icons.copy_all,
                      tooltip: S.peerCopyIpPort,
                      color: cs.outline,
                      onPressed: () => _copy(target),
                    ),
                    if (isQb) ...<Widget>[
                      const SizedBox(width: 2),
                      _miniButton(
                        icon: Icons.block,
                        tooltip: S.peerBanTitle,
                        color: cs.error,
                        onPressed: () => _ban(target),
                      ),
                    ],
                    SizedBox(width: af(context, 4)),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: af(context, 15),
                      color: cs.outline,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 6,
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
                      Expanded(
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
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    _speedCell('▼', Formatter.setSpeed(dl), const Color(0xFF1A73E8)),
                    const SizedBox(width: 8),
                    _speedCell('▲', Formatter.setSpeed(up), const Color(0xFF0F9D58)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Formatter.setProgress(progress),
                      style: TextStyle(
                        fontSize: af(context, 10),
                        fontWeight: FontWeight.w600,
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (isQb) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    _totalText(p),
                    style: TextStyle(fontSize: af(context, 9), color: cs.outline),
                  ),
                ],
              ],
            ),
          ),
          if (expanded) ...<Widget>[
            const SizedBox(height: 6),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
            const SizedBox(height: 6),
            _detailGrid(p, isQb: isQb, encrypted: encrypted, utp: utp, incoming: incoming),
          ],
        ],
      ),
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

  Widget _speedCell(String arrow, String speed, Color c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(arrow,
            style: TextStyle(fontSize: af(context, 9), color: c, fontWeight: FontWeight.w700)),
        const SizedBox(width: 1),
        Text(
          speed,
          style: TextStyle(
            fontSize: af(context, 10.5),
            fontWeight: FontWeight.w600,
            color: c,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _flagBadge(ColorScheme cs, String c, bool isQb, Map<String, dynamic> p) {
    final Color color = _flagColor(c, cs);
    final String? desc = _flagDescOf(p, c, isQb);
    return Tooltip(
      message: desc ?? c,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          c,
          style: TextStyle(
            fontSize: af(context, 8.5),
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _detailGrid(
    Map<String, dynamic> p, {
    required bool isQb,
    required bool encrypted,
    required bool utp,
    required bool incoming,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String peerId =
        (p['peer_id_client'] ?? p['peer_id'] ?? '').toString();
    final String connection = (p['connection'] ?? '').toString();
    final double relevance =
        ((p['relevance'] ?? 0) as num?)?.toDouble() ?? 0;
    final String files = (p['files'] ?? '').toString();
    final num ratio = (p['ratios'] as num?) ?? 0;

    final List<Widget> cells = <Widget>[
      if (peerId.isNotEmpty) _dCell('PeerID', peerId),
      if (connection.isNotEmpty) _dCell('连接', connection),
      if (encrypted) _dCell('加密', '✓'),
      if (utp) _dCell('传输', 'uTP'),
      if (incoming) _dCell('方向', '入站'),
      if (!isQb && ratio > 0)
        _dCell('对其分享率', ratio.toStringAsFixed(2)),
      if (isQb && relevance > 0)
        _dCell('相关度', '${(relevance * 100).toStringAsFixed(0)}%'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (cells.isNotEmpty)
          Wrap(spacing: 14, runSpacing: 4, children: cells),
        if (files.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            '正在提供 $files',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: af(context, 10), color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Widget _dCell(String label, String value) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$label ',
            style: TextStyle(fontSize: af(context, 10), color: cs.onSurfaceVariant)),
        Text(value,
            style: TextStyle(
                fontSize: af(context, 10),
                fontWeight: FontWeight.w600,
                color: cs.onSurface)),
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
