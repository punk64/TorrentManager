import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../app/adaptive.dart';

class ColorPicker extends StatefulWidget {
  const ColorPicker({
    super.key,
    required this.color,
    required this.onChanged,
    this.showPresets = true,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  final bool showPresets;

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late HSVColor _hsv;

  static const List<Color> _presets = <Color>[
    Color(0xFF282828),
    Color(0xFF464646),
    Color(0xFF1E1E1E),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFC62828),
    Color(0xFF6A1B9A),
    Color(0xFFEF6C00),
    Color(0xFF00838F),
    Color(0xFFAABEFF),
    Color(0xFFA0B4E1),
    Color(0xFFE1D2E1),
  ];

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.color);
  }

  @override
  void didUpdateWidget(covariant ColorPicker old) {
    super.didUpdateWidget(old);
    if (old.color != widget.color) {
      _hsv = HSVColor.fromColor(widget.color);
    }
  }

  void _emit(HSVColor next) {
    setState(() => _hsv = next);
    widget.onChanged(next.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final Color c = _hsv.toColor();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[

        Container(
          height: af(context, 44),
          width: double.infinity,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          alignment: Alignment.center,
          child: Text(
            '#${(((c.r * 255).round() << 16) | ((c.g * 255).round() << 8) | (c.b * 255).round()).toRadixString(16).padLeft(6, '0').toUpperCase()}',
            style: TextStyle(
              fontSize: af(context, 12),
              color: ThemeData.estimateBrightnessForColor(c) == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
        ),
        SizedBox(height: af(context, 10)),

        _slider('H', _hsv.hue, 0, 360, (double v) {
          _emit(_hsv.withHue(v));
        }, _hueGradient()),
        _slider('S', _hsv.saturation, 0, 1, (double v) {
          _emit(_hsv.withSaturation(v));
        }, _satGradient()),
        _slider('V', _hsv.value, 0, 1, (double v) {
          _emit(_hsv.withValue(v));
        }, _valGradient()),

        if (widget.showPresets) ...<Widget>[
          SizedBox(height: af(context, 8)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((Color p) {
              return InkWell(
                onTap: () => _emit(HSVColor.fromColor(p)),
                child: Container(
                  width: af(context, 26),
                  height: af(context, 26),
                  decoration: BoxDecoration(
                    color: p,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(
                      color: p == c
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                      width: p == c ? 2 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    Gradient gradient,
  ) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: af(context, 14),
          child: Text(label, style: TextStyle(fontSize: af(context, 11))),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: value.clamp(min, max).toDouble(),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: af(context, 40),
          child: Text(
            value.toStringAsFixed(label == 'H' ? 0 : 2),
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: af(context, 10)),
          ),
        ),
      ],
    );
  }

  Gradient _hueGradient() => const LinearGradient(
        colors: <Color>[
          Color(0xFFFF0000),
          Color(0xFFFFFF00),
          Color(0xFF00FF00),
          Color(0xFF00FFFF),
          Color(0xFF0000FF),
          Color(0xFFFF00FF),
          Color(0xFFFF0000),
        ],
      );

  Gradient _satGradient() => LinearGradient(
        colors: <Color>[
          HSVColor.fromAHSV(1, _hsv.hue, 0, _hsv.value).toColor(),
          HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
        ],
      );

  Gradient _valGradient() => LinearGradient(
        colors: <Color>[
          HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 0).toColor(),
          HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
        ],
      );
}
