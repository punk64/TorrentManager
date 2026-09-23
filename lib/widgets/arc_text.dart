import 'dart:math' as math;

import 'package:flutter/material.dart';

class ArcText extends StatelessWidget {
  const ArcText({
    super.key,
    required this.text,
    this.radius = 80,
    this.style,
    this.startAngle = -math.pi / 2,
    this.clockwise = true,
  });

  final String text;

  final double radius;

  final TextStyle? style;

  final double startAngle;

  final bool clockwise;

  @override
  Widget build(BuildContext context) {
    final double size = (radius + (style?.fontSize ?? 14)) * 2;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ArcTextPainter(
          text: text,
          radius: radius,
          style: style ??
              TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
          startAngle: startAngle,
          clockwise: clockwise,
        ),
      ),
    );
  }
}

class _ArcTextPainter extends CustomPainter {
  _ArcTextPainter({
    required this.text,
    required this.radius,
    required this.style,
    required this.startAngle,
    required this.clockwise,
  });

  final String text;
  final double radius;
  final TextStyle style;
  final double startAngle;
  final bool clockwise;

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final List<TextPainter> painters = <TextPainter>[];
    for (final String ch in text.characters) {
      final TextPainter tp = TextPainter(
        text: TextSpan(text: ch, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      painters.add(tp);
    }
    final double totalWidth =
        painters.fold(0, (double a, TextPainter p) => a + p.width);
    final double totalAngle = totalWidth / radius;

    double angle = clockwise ? startAngle - totalAngle / 2 : startAngle + totalAngle / 2;

    for (final TextPainter tp in painters) {
      final double half = tp.width / radius / 2;
      angle += clockwise ? half : -half;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(clockwise ? angle : angle + math.pi);

      final double dy = clockwise ? -radius : radius - tp.height;
      tp.paint(canvas, Offset(-tp.width / 2, dy));
      canvas.restore();

      angle += clockwise ? half : -half;
    }
  }

  @override
  bool shouldRepaint(_ArcTextPainter old) =>
      old.text != text ||
      old.radius != radius ||
      old.style != style ||
      old.startAngle != startAngle ||
      old.clockwise != clockwise;
}
