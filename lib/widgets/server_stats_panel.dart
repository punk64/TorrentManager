import 'package:flutter/material.dart';

import '../app/adaptive.dart';
import '../app/theme.dart';
import '../data/models/torrent.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';
import 'metric_row.dart';

class ServerStatsPanel extends StatelessWidget {
  const ServerStatsPanel({
    super.key,
    required this.dlSpeed,
    required this.upSpeed,
    required this.counts,
    required this.serversOnline,
    required this.serversTotal,
    required this.totals,
    this.expanded = true,
    this.onToggle,
    this.hasData = true,
  });

  final int dlSpeed;

  final int upSpeed;

  final TorrentStatusCounts counts;

  final int serversOnline;

  final int serversTotal;

  final TransferTotals totals;

  final bool expanded;

  final VoidCallback? onToggle;

  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Brightness b = Theme.of(context).brightness;
    final _Palette p = _Palette.of(b);
    final Color dlColor = adaptSemantic(kSemanticDownload, b);
    final Color upColor = adaptSemantic(kSemanticUpload, b);
    final Color peersColor = adaptSemantic(kSemanticPeer, b);

    final double k = adaptiveScale(context);

    final Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _speedBand(context, dlColor, upColor, peersColor, cs, k),
        if (expanded) ...<Widget>[
          SizedBox(height: 9 * k),
          _ratioBar(context, p, k),
          SizedBox(height: 6 * k),
          _legend(context, p, k),
          SizedBox(height: 8 * k),
          _divider(cs),
          SizedBox(height: 7 * k),

          MetricRow(
            gap: 10 * k,
            inline: true,
            valueSize: 11 * k,
            labelSize: 8.5 * k,
            minValueSize: 8 * k,
            iconSize: 11 * k,
            items: <MetricItem>[
              MetricItem(
                icon: Icons.download_rounded,
                value: hasData ? Formatter.setSize(totals.downloadedBytes) : '--',
                label: S.statsLabelTotalDl,
                color: dlColor,
                flex: 3,
              ),
              MetricItem(
                icon: Icons.upload_rounded,
                value: hasData ? Formatter.setSize(totals.uploadedBytes) : '--',
                label: S.statsLabelTotalUl,
                color: upColor,
                flex: 3,
              ),
              MetricItem(
                icon: Icons.dns_rounded,
                value: '$serversOnline/$serversTotal',
                label: S.chartLabelServersOnline,
                color: cs.onSurface,
                flex: 2,
              ),
            ],
          ),
        ],
      ],
    );

    return Container(
      margin: afEdgeInsets(context, left: 12, top: 8, right: 12, bottom: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: onToggle,
          child: Padding(
            padding: afEdgeInsets(context,
                left: 12, top: 9, right: 12, bottom: 9),
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _speedBand(
    BuildContext context,
    Color dl,
    Color up,
    Color peers,
    ColorScheme cs,
    double k,
  ) {

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[

        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.arrow_downward_rounded, size: af(context, 16) * k, color: dl),
                SizedBox(width: 3 * k),
                Text(
                  hasData ? Formatter.setSpeed(dlSpeed < 0 ? 0 : dlSpeed) : '--',
                  style: TextStyle(
                    fontSize: 19 * k,
                    fontWeight: FontWeight.w800,
                    color: dl,
                    height: 1.05,
                  ),
                ),
                SizedBox(width: af(context, 14) * k),
                Icon(Icons.arrow_upward_rounded, size: af(context, 16) * k, color: up),
                SizedBox(width: 3 * k),
                Text(
                  hasData ? Formatter.setSpeed(upSpeed < 0 ? 0 : upSpeed) : '--',
                  style: TextStyle(
                    fontSize: 19 * k,
                    fontWeight: FontWeight.w800,
                    color: up,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 8 * k),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              hasData ? '${totals.peers}' : '--',
              style: TextStyle(
                fontSize: 12 * k,
                fontWeight: FontWeight.w800,
                color: peers,
                height: 1.1,
              ),
            ),
            Text(
              S.statsLabelPeers,
              style: TextStyle(
                fontSize: 8 * k,
                height: 1.2,
                color: cs.onSurfaceVariant.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
        if (onToggle != null) ...<Widget>[
          SizedBox(width: 8 * k),
          Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: af(context, 18) * k,
            color: cs.onSurfaceVariant,
          ),
        ],
      ],
    );
  }

  Widget _divider(ColorScheme cs) => Container(
        height: 1,
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(1),
        ),
      );

  Widget _ratioBar(BuildContext context, _Palette p, double k) {
    final List<int> v = <int>[
      counts.seeding,
      counts.downloading,
      counts.paused,
      counts.checking,
      counts.error,
      counts.other,
    ];
    final List<Color> c = <Color>[
      p.seeding,
      p.downloading,
      p.paused,
      p.checking,
      p.error,
      p.other,
    ];
    final int sum = v.fold<int>(0, (int a, int e) => a + e);
    if (sum <= 0) {
      return Container(
        height: 7 * k,
        decoration: BoxDecoration(
          color: p.other.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(4 * k),
        ),
      );
    }
    return Row(
      children: <Widget>[
        for (int i = 0; i < v.length; i++) ...<Widget>[
          if (v[i] > 0) ...<Widget>[
            if (i > 0) SizedBox(width: 1.5 * k),
            Expanded(
              flex: v[i],
              child: Container(
                height: 7 * k,
                decoration: BoxDecoration(
                  color: c[i],
                  borderRadius: BorderRadius.horizontal(
                    left: i == 0 ? Radius.circular(4 * k) : Radius.zero,
                    right: i == v.length - 1
                        ? Radius.circular(4 * k)
                        : Radius.zero,
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _legend(BuildContext context, _Palette p, double k) => MetricRow(
        gap: 6,
        inline: true,
        fitRow: true,
        fixedValueChars: 5,
        valueSize: 10,
        labelSize: 8,
        items: <MetricItem>[
          MetricItem(
            value: hasData ? '${counts.seeding}' : '--',
            label: S.stSeeding,
            color: p.seeding,
            dot: true,
          ),
          MetricItem(
            value: hasData ? '${counts.downloading}' : '--',
            label: S.chartLabelDownload,
            color: p.downloading,
            dot: true,
          ),
          MetricItem(
            value: hasData ? '${counts.paused}' : '--',
            label: S.stPaused,
            color: p.paused,
            dot: true,
          ),
          MetricItem(
            value: hasData ? '${counts.checking}' : '--',
            label: S.chartLabelVerifying,
            color: p.checking,
            dot: true,
          ),
          MetricItem(
            value: hasData ? '${counts.error}' : '--',
            label: S.error,
            color: p.error,
            dot: true,
          ),
          MetricItem(
            value: hasData ? '${counts.other}' : '--',
            label: S.stUnknownState,
            color: p.other,
            dot: true,
          ),
        ],
      );
}

class _Palette {
  const _Palette({
    required this.seeding,
    required this.downloading,
    required this.paused,
    required this.checking,
    required this.error,
    required this.other,
  });

  factory _Palette.of(Brightness b) {
    final bool dark = b == Brightness.dark;
    return _Palette(
      seeding: adaptSemantic(kSemanticUpload, b),
      downloading: adaptSemantic(kSemanticDownload, b),
      paused: dark
          ? const Color(0xFF9BA3AD)
          : const Color(0xFF5F6B76),
      checking: adaptSemantic(kSemanticPeer, b),
      error: adaptSemantic(kSemanticError, b),
      other: dark
          ? const Color(0xFF9AA0A6)
          : const Color(0xFF66707A),
    );
  }

  final Color seeding;
  final Color downloading;
  final Color paused;
  final Color checking;
  final Color error;
  final Color other;
}
