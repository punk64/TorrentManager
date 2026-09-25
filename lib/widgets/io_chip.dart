import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../app/adaptive.dart';

class IoChip extends StatelessWidget {
  const IoChip({super.key, required this.jobs});

  final int jobs;

  static const Color colorIdle = Color(0xFF4CAF50);
  static const Color colorBusy = Color(0xFFFF9800);
  static const Color colorJam = Color(0xFFE91E63);

  static Color colorFor(int jobs) {
    if (jobs <= 0) return colorIdle;
    if (jobs < 1000) return colorBusy;
    return colorJam;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 1, 3, 1),
      decoration: BoxDecoration(
        color: colorFor(jobs),
        borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
      ),
      child: Text(
        'I/O: $jobs',
        style: TextStyle(fontSize: af(context, 8), color: Colors.white),
      ),
    );
  }
}
