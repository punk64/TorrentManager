import 'package:flutter/material.dart';
import '../app/adaptive.dart';

class SpeedSparkline extends StatelessWidget {
  const SpeedSparkline({
    super.key,
    required this.dl,
    required this.ul,
    this.height = 46,
  });

  final List<double> dl;

  final List<double> ul;

  final double height;

  static const Color kDlColor = Color(0xFF1A73E8);
  static const Color kUlColor = Color(0xFF0F9D58);

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool empty = dl.isEmpty && ul.isEmpty;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: empty
          ? Center(
              child: Text(
                '等待采样…',
                style: TextStyle(fontSize: af(context, 10), color: cs.onSurfaceVariant),
              ),
            )
          : CustomPaint(
              painter: _SparkPainter(dl: dl, ul: ul, grid: cs.outlineVariant),
            ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.dl, required this.ul, required this.grid});

  final List<double> dl;
  final List<double> ul;
  final Color grid;

  double get _maxV {
    double m = 0;
    for (final double v in dl) {
      if (v > m) m = v;
    }
    for (final double v in ul) {
      if (v > m) m = v;
    }
    return m <= 0 ? 1 : m;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width, 0),
      Paint()
        ..color = grid
        ..strokeWidth = 0.5,
    );
    final double maxV = _maxV;
    void line(List<double> data, Color c) {
      if (data.length < 2) return;
      final double dx = size.width / (data.length - 1);
      final Path p = Path();
      for (int i = 0; i < data.length; i++) {
        final double x = i * dx;

        final double y =
            size.height - 1 - (data[i] / maxV) * (size.height - 2);
        if (i == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      canvas.drawPath(
        p,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      final Path fill = Path.from(p)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(fill, Paint()..color = c.withValues(alpha: 0.12));
    }

    line(ul, SpeedSparkline.kUlColor);
    line(dl, SpeedSparkline.kDlColor);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => true;
}
