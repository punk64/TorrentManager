import 'package:flutter/material.dart';

import '../app/theme.dart';




















class ThemePreview extends StatelessWidget {
  const ThemePreview({
    super.key,
    required this.theme,
    required this.transparency,
  });

  
  
  
  
  final ThemeData theme;

  
  
  
  
  
  
  
  
  final double transparency;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text('效果预览',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              transparency <= 0
                  ? '组件底衬：完全不透明'
                  : (transparency >= 1
                      ? '组件底衬：完全透明'
                      : '组件底衬：透明度 ${(transparency * 100).round()}%'),
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          
          
          child: CustomPaint(
            painter: const _CheckerPainter(),
            child: Theme(
              data: theme,
              
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    decoration: BoxDecoration(
                      
                      
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: theme.dividerColor, width: 0.5),
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                    child: Column(
                      
                      
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.folder_open,
                                size: AppTheme.iconSize, color: cs.primary),
                            const SizedBox(width: 6),
                            Text('示例卡片',
                                style: TextStyle(
                                    fontSize: 11, color: cs.onSurface)),
                            const Spacer(),
                            Switch(
                              value: true,
                              onChanged: (_) {},
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                        
                        
                        Text('示例文本',
                            style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                        Slider(value: 0.62, onChanged: (_) {}),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}




class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();

  
  static const double _cell = 12;

  
  
  static const Color _light = Color(0xFFF2F2F2);
  static const Color _dark = Color(0xFFD9D9D9);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..style = PaintingStyle.fill;
    final int cols = (size.width / _cell).ceil();
    final int rows = (size.height / _cell).ceil();
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        p.color = (r + c).isEven ? _light : _dark;
        canvas.drawRect(Rect.fromLTWH(c * _cell, r * _cell, _cell, _cell), p);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) => false;
}
