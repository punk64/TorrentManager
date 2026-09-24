import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/models/torrent.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';

/// 服务器列表顶部的「总计数据卡」。
///
/// 布局：左侧环形图（种子状态分布 + 总数），右侧 4 行 × 2 列数据
/// （连接 / 累计下载 / 累计上传 / 在线 / 上下行速度 / 状态图例）。
/// 目标是**竖向占高最小**：整卡约 91px（旧三段式约 208px）。
class ServerStatsPanel extends StatelessWidget {
  const ServerStatsPanel({
    super.key,
    required this.dlSpeed,
    required this.upSpeed,
    required this.counts,
    required this.serversOnline,
    required this.serversTotal,
    required this.totals,
  });

  final int dlSpeed;

  final int upSpeed;

  final TorrentStatusCounts counts;

  final int serversOnline;

  final int serversTotal;

  final TransferTotals totals;

  /// 环形图边长（同时决定整卡高度）
  static const double kDonutSize = 62;

  static const double _kDonutStroke = 7;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Brightness b = Theme.of(context).brightness;
    final _Palette p = _Palette.of(b, cs);
    final Color dlColor = _adaptColor(_kDlBase, b);
    final Color upColor = _adaptColor(_kUlBase, b);
    final Color peersColor = _adaptColor(_kPeersBase, b);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // ① 环形：种子状态分布，中心显示总数
          SizedBox(
            width: kDonutSize,
            height: kDonutSize,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CustomPaint(
                  key: const Key('stats-status-donut'),
                  size: const Size(kDonutSize, kDonutSize),
                  painter: _DonutPainter(
                    segments: <(Color, int)>[
                      (p.seeding, counts.seeding),
                      (p.downloading, counts.downloading),
                      (p.paused, counts.paused),
                      (p.checking, counts.checking),
                      (p.error, counts.error),
                      (p.other, counts.other),
                    ],
                    track: cs.outlineVariant.withValues(alpha: 0.35),
                    stroke: _kDonutStroke,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${counts.total}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                    Text(
                      S.statsLabelTorrents,
                      style: TextStyle(
                        fontSize: 8,
                        color: cs.onSurfaceVariant,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ② 右侧 4 行 × 2 列
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _cell(context, Icons.hub, '${totals.peers}',
                          S.statsLabelPeers, peersColor),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: _cell(
                          context,
                          Icons.download,
                          Formatter.setSize(totals.downloadedBytes),
                          S.statsLabelTotalDl,
                          dlColor),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _cell(
                          context,
                          Icons.upload,
                          Formatter.setSize(totals.uploadedBytes),
                          S.statsLabelTotalUl,
                          upColor),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: _cell(context, Icons.circle,
                          '$serversOnline/$serversTotal',
                          S.chartLabelServersOnline, p.online,
                          dot: true),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _speed(
                          context,
                          S.downArrow,
                          Formatter.setSpeed(dlSpeed < 0 ? 0 : dlSpeed),
                          S.chartLabelDownload,
                          dlColor),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: _speed(
                          context,
                          S.upArrow,
                          Formatter.setSpeed(upSpeed < 0 ? 0 : upSpeed),
                          S.chartLabelUpload,
                          upColor),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _legendGroup(context, <(Color, int, String)>[
                        (p.seeding, counts.seeding, S.stSeeding),
                        (p.downloading, counts.downloading,
                            S.chartLabelDownload),
                        (p.paused, counts.paused, S.stPaused),
                      ]),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: _legendGroup(context, <(Color, int, String)>[
                        (p.checking, counts.checking, S.chartLabelVerifying),
                        (p.error, counts.error, S.error),
                        (p.other, counts.other, S.stUnknownState),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 单行式数据单元：图标 + 数值 + 右侧标签，三者同色。
  /// 外层 FittedBox 保证窄屏只缩放、不出现省略号。
  Widget _cell(BuildContext context, IconData icon, String value, String label,
      Color color,
      {bool dot = false}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          dot
              ? Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                )
              : Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text.rich(
            TextSpan(
              children: <TextSpan>[
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const TextSpan(text: ' ', style: TextStyle(fontSize: 11.5)),
                TextSpan(
                  text: label,
                  style: TextStyle(fontSize: 8, color: color),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 速度：箭头 + 数值 + 右侧标签，同色。
  Widget _speed(BuildContext context, String arrow, String value, String label,
      Color color) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: '$arrow ',
              style: TextStyle(fontSize: 10, color: color),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const TextSpan(text: ' ', style: TextStyle(fontSize: 11.5)),
            TextSpan(
              text: label,
              style: TextStyle(fontSize: 8, color: color),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 状态图例组（每组 3 项），文字与色点同色。
  Widget _legendGroup(BuildContext context, List<(Color, int, String)> items) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 6),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: items[i].$1,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 3),
            Text.rich(
              TextSpan(
                children: <TextSpan>[
                  TextSpan(
                    text: '${items[i].$2}',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: items[i].$1,
                    ),
                  ),
                  const TextSpan(text: ' ', style: TextStyle(fontSize: 8)),
                  TextSpan(
                    text: items[i].$3,
                    style: TextStyle(fontSize: 8, color: items[i].$1),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// 种子状态环形图：按占比绘制彩色弧段，段间留细缝。
class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.segments,
    required this.track,
    this.stroke = 7,
  });

  final List<(Color, int)> segments;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final double r = math.min(size.width, size.height) / 2 - 4;
    final Offset c = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    final int total = segments.fold<int>(
        0, (int a, (Color, int) e) => a + (e.$2 > 0 ? e.$2 : 0));
    if (total <= 0) return;

    final Rect rect = Rect.fromCircle(center: c, radius: r);
    double start = -math.pi / 2;
    for (final (Color, int) e in segments) {
      if (e.$2 <= 0) continue;
      final double sweep = 2 * math.pi * e.$2 / total;
      canvas.drawArc(
        rect,
        start + 0.03,
        math.max(sweep - 0.06, 0.01),
        false,
        Paint()
          ..color = e.$1
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.segments != segments || old.stroke != stroke;
}

Color _adaptColor(Color base, Brightness b) {
  final HSLColor h = HSLColor.fromColor(base);
  return h
      .withLightness(b == Brightness.dark ? 0.66 : 0.42)
      .withSaturation(h.saturation.clamp(0.35, 0.75))
      .toColor();
}

const Color _kDlBase = Color(0xFF1A73E8);

const Color _kUlBase = Color(0xFF0F9D58);

const Color _kPeersBase = Color(0xFF8E24AA);

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
