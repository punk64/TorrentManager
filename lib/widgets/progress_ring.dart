import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/adaptive.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size,
    this.strokeWidth = 8,
    this.color,
    this.trackColor,
    this.child,
  });

  final double progress;

  final double? size;

  final double strokeWidth;

  final Color? color;

  final Color? trackColor;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final double d = size ?? af(context, 96);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size(d, d),
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              color: color ?? cs.primary,
              trackColor: trackColor ?? cs.surfaceContainerHighest,
            ),
          ),
          if (child != null)
            SizedBox(
              width: math.max(0, d - strokeWidth * 2 - 4),
              child: Center(child: child),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double progress;

  final double strokeWidth;

  final Color color;

  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = (math.min(size.width, size.height) - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: c, radius: r);

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(c, r, track);

    if (progress <= 0) return;
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
