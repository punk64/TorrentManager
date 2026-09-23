import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/models/torrent.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';

class ServerStatsPanel extends StatelessWidget {
  const ServerStatsPanel({
    super.key,
    required this.dlSpeed,
    required this.upSpeed,
    required this.counts,
    required this.serversOnline,
    required this.serversTotal,
  });

  final int dlSpeed;

  final int upSpeed;

  final TorrentStatusCounts counts;

  final int serversOnline;

  final int serversTotal;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ThroughputRow(dl: dlSpeed, up: upSpeed),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          _TorrentBreakdown(
            counts: counts,
            serversOnline: serversOnline,
            serversTotal: serversTotal,
          ),
        ],
      ),
    );
  }
}

Color _adaptColor(Color base, Brightness b) {
  final HSLColor h = HSLColor.fromColor(base);
  return h
      .withLightness(b == Brightness.dark ? 0.66 : 0.42)
      .withSaturation(h.saturation.clamp(0.35, 0.75))
      .toColor();
}

class _ThroughputRow extends StatelessWidget {
  const _ThroughputRow({required this.dl, required this.up});

  final int dl;
  final int up;

  static const Color kDlColor = Color(0xFF1A73E8);

  static const Color kUlColor = Color(0xFF0F9D58);

  @override
  Widget build(BuildContext context) {
    final Brightness b = Theme.of(context).brightness;
    final Color dlColor = _adaptColor(kDlColor, b);
    final Color upColor = _adaptColor(kUlColor, b);

    final int safeDl = dl < 0 ? 0 : dl;
    final int safeUp = up < 0 ? 0 : up;

    return Row(
      children: <Widget>[
        _side(context, S.downArrow, S.chartLabelDownload,
            Formatter.setSpeed(safeDl), dlColor),
        const SizedBox(width: 8),
        Expanded(child: _stackedBar(context, safeDl, safeUp, dlColor, upColor)),
        const SizedBox(width: 8),
        _side(context, S.upArrow, S.chartLabelUpload,
            Formatter.setSpeed(safeUp), upColor),
      ],
    );
  }

  Widget _side(
    BuildContext context,
    String arrow,
    String label,
    String value,
    Color color,
  ) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text.rich(
          TextSpan(
            children: <TextSpan>[
              TextSpan(text: arrow, style: TextStyle(color: color, fontSize: 9)),
              TextSpan(
                text: value,
                style:
                    const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 8.5, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _stackedBar(
      BuildContext context, int dl, int up, Color dlColor, Color upColor) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int total = dl + up;
    if (total <= 0) {
      return Container(
        height: 6,
        decoration: BoxDecoration(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusBar),
        ),
      );
    }
    final int dlFlex = (dl * 999 ~/ total).clamp(1, 998);
    final int upFlex = 999 - dlFlex;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusBar),
      child: SizedBox(
        key: const Key('stats-throughput-bar'),
        height: 6,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: dlFlex,
              child: ColoredBox(
                key: const Key('stats-throughput-dl'),
                color: dlColor,
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              flex: upFlex,
              child: ColoredBox(
                key: const Key('stats-throughput-up'),
                color: upColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TorrentBreakdown extends StatelessWidget {
  const _TorrentBreakdown({
    required this.counts,
    required this.serversOnline,
    required this.serversTotal,
  });

  final TorrentStatusCounts counts;
  final int serversOnline;
  final int serversTotal;

  static const double _barHeight = 8;

  static const int _maxDots = 10;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Brightness b = Theme.of(context).brightness;
    final _Palette p = _Palette.of(b, cs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                S.torrentCount(counts.total),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            _serverDots(context, p),
          ],
        ),
        const SizedBox(height: 6),
        _bar(context, p),
        const SizedBox(height: 6),
        Wrap(
          spacing: 9,
          runSpacing: 3,
          children: <Widget>[
            _legend(context, p.seeding, counts.seeding, S.stSeeding),
            _legend(context, p.downloading, counts.downloading,
                S.chartLabelDownload),
            _legend(context, p.paused, counts.paused, S.stPaused),
            _legend(context, p.checking, counts.checking, S.chartLabelVerifying),
            _legend(context, p.error, counts.error, S.error),
            _legend(context, p.other, counts.other, S.stUnknownState),
          ],
        ),
      ],
    );
  }

  Widget _serverDots(BuildContext context, _Palette p) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<Widget> dots = <Widget>[];
    if (serversTotal > 0 && serversTotal <= _maxDots) {
      final n = serversOnline.clamp(0, serversTotal);
      for (int i = 0; i < serversTotal; i++) {
        dots.add(Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: i < n ? p.online : cs.outlineVariant.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
        ));
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ...dots,
        SizedBox(width: dots.isEmpty ? 0 : 5),
        Text(
          '$serversOnline/$serversTotal',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 4),
        Text(
          S.chartLabelServersOnline,
          style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _bar(BuildContext context, _Palette p) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int total = counts.total;
    if (total <= 0) {
      return Container(
        key: const Key('stats-status-bar'),
        height: _barHeight,
        decoration: BoxDecoration(
          color: cs.outlineVariant.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppTheme.radiusBar),
        ),
      );
    }
    final List<(Color, int)> segs = <(Color, int)>[
      (p.seeding, counts.seeding),
      (p.downloading, counts.downloading),
      (p.paused, counts.paused),
      (p.checking, counts.checking),
      (p.error, counts.error),
      (p.other, counts.other),
    ].where(((Color, int) e) => e.$2 > 0).toList(growable: false);

    if (segs.length == 1) {
      return Container(
        key: const Key('stats-status-bar'),
        height: _barHeight,
        decoration: BoxDecoration(
          color: segs.first.$1,
          borderRadius: BorderRadius.circular(AppTheme.radiusBar),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusBar),
      child: SizedBox(
        key: const Key('stats-status-bar'),
        height: _barHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < segs.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 1),
              Expanded(flex: segs[i].$2, child: ColoredBox(color: segs[i].$1)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, int n, String label) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    if (n <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '$n',
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Palette {
  const _Palette({
    required this.seeding,
    required this.downloading,
    required this.paused,
    required this.checking,
    required this.error,
    required this.other,
    required this.online,
  });

  factory _Palette.of(Brightness b, ColorScheme cs) {
    final bool dark = b == Brightness.dark;
    return _Palette(
      seeding: _adaptColor(const Color(0xFF0F9D58), b),
      downloading: _adaptColor(const Color(0xFF1A73E8), b),
      paused: dark
          ? const Color(0xFF8A8F98)
          : const Color(0xFF9AA0A6), // 中性灰，不参与 HSL 适配
      checking: _adaptColor(const Color(0xFF8E24AA), b),
      error: _adaptColor(const Color(0xFFD93025), b),
      other: dark
          ? const Color(0xFF5F6368)
          : const Color(0xFFBDC1C6), // 比 paused 更淡一档
      online: dark ? const Color(0xFF7DDC9B) : const Color(0xFF1E8E3E),
    );
  }

  final Color seeding;
  final Color downloading;
  final Color paused;
  final Color checking;
  final Color error;
  final Color other;
  final Color online;
}
