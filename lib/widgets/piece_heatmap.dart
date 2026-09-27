import 'package:flutter/material.dart';

class PieceHeatmap extends StatelessWidget {
  const PieceHeatmap({
    super.key,
    required this.states,
    this.height = 30,
    this.maxCells = 160,
    this.cellSide = 7,
    this.gap = 2,
  });

  final List<int> states;

  final double height;

  final int maxCells;

  final double cellSide;

  final double gap;

  static const Color cDone = Color(0xFF1A73E8);

  static const Color cActive = Color(0x5C1A73E8);

  static const Color cMissing = Color(0xFFDFE5EE);

  static const Color cChecking = Color(0xFFE8710A);

  static Color stateColor(int s) {
    switch (s) {
      case 2:
        return cDone;
      case 1:
        return cActive;
      case 3:
        return cChecking;
      default:
        return cMissing;
    }
  }

  List<int> _downsample() {
    if (states.length <= maxCells) return states;
    final List<int> out = <int>[];
    final double step = states.length / maxCells;
    for (int i = 0; i < maxCells; i++) {
      final int lo = (i * step).floor();
      final int hi = (((i + 1) * step).ceil()).clamp(lo + 1, states.length);
      int worst = 2;
      for (int j = lo; j < hi; j++) {
        final int s = states[j];
        if (s == 3) {
          worst = 3;
          break;
        }
        if (s == 0) {
          worst = 0;
        } else if (s == 1 && worst == 2) {
          worst = 1;
        }
      }
      out.add(worst);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (states.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(painter: _HeatPainter(cells: _downsample(), side: cellSide, gap: gap)),
    );
  }
}

class _HeatPainter extends CustomPainter {
  const _HeatPainter({required this.cells, required this.side, required this.gap});

  final List<int> cells;

  final double side;

  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty || size.width <= 0) return;
    final int cols = ((size.width + gap) / (side + gap)).floor().clamp(1, cells.length);
    final Paint p = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < cells.length; i++) {
      final int row = i ~/ cols;
      final int col = i % cols;
      final double x = col * (side + gap);
      final double y = row * (side + gap);
      if (y > size.height) break;
      p.color = PieceHeatmap.stateColor(cells[i]);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, side, side),
          const Radius.circular(1.6),
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeatPainter old) =>
      old.cells.length != cells.length || old.side != side;
}
