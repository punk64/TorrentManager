import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/adaptive.dart';

const Color kSemanticDownload = Color(0xFFD81B60);
const Color kSemanticUpload = Color(0xFF347F59);
const Color kSemanticActive = Color(0xFF1A73E8);
const Color kSemanticPeer = Color(0xFF8E24AA);
const Color kSemanticError = Color(0xFFA63F87);

Color adaptSemantic(Color base, Brightness brightness) {
  final HSLColor h = HSLColor.fromColor(base);
  final bool dark = brightness == Brightness.dark;
  final bool greenish = h.hue >= 130 && h.hue <= 170;
  final double target = greenish ? (dark ? 0.60 : 0.36) : (dark ? 0.66 : 0.42);
  return h
      .withLightness(target)
      .withSaturation(h.saturation.clamp(0.35, 0.75))
      .toColor();
}

@immutable
class MetricItem {
  const MetricItem({
    required this.value,
    required this.label,
    required this.color,
    this.icon,
    this.dot = false,
    this.flex = 1,
  });

  final String value;

  final String label;

  final Color color;

  final IconData? icon;

  final bool dot;

  final int flex;
}

class MetricRow extends StatelessWidget {
  const MetricRow({
    super.key,
    required this.items,
    this.gap = 8,
    this.valueSize = 12,
    this.labelSize = 8.5,
    this.minValueSize = 8,
    this.minLabelSize = 6.5,
    this.iconSize = 12,
    this.valueWeight = FontWeight.w700,
    this.centered = false,
    this.labelOpacity = 0.78,
    this.inline = false,
    this.fitRow = false,
    this.fixedValueChars,
  });

  final List<MetricItem> items;

  final double gap;

  final double valueSize;

  final double labelSize;

  final double minValueSize;

  final double minLabelSize;

  final double iconSize;

  final FontWeight valueWeight;

  final bool centered;

  final bool inline;

  final bool fitRow;

  final int? fixedValueChars;

  final double labelOpacity;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    if (fitRow) {
      final ColorScheme cs = Theme.of(context).colorScheme;
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < items.length; i++) ...<Widget>[
              if (i > 0) SizedBox(width: gap),
              _tile(context, items[i], valueSize, labelSize, cs, natural: true),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final int n = items.length;

        final int flexSum =
            items.fold<int>(0, (int a, MetricItem e) => a + e.flex);
        double colOf(int i) =>
            (c.maxWidth - gap * (n - 1)) * items[i].flex / flexSum;

        final bool hasLeading =
            items.any((MetricItem e) => e.icon != null || e.dot);
        final double valueRoom =
            math.max(0, colOf(0) - (hasLeading ? iconSize + 3 : 0));

        final ColorScheme cs = Theme.of(context).colorScheme;

        double vs;
        double ls;
        if (inline) {

          double k = 1.0;
          for (int i = 0; i < n; i++) {
            final MetricItem e = items[i];
            final double need = _unitWidth(e.label) * labelSize +
                _unitWidth(e.value) * valueSize +
                0.35 * valueSize;
            final double room = math.max(
                0, colOf(i) - ((e.icon != null || e.dot) ? iconSize + 3 : 0));
            k = math.min(k, room / need);
          }
          k = k.clamp(minValueSize / valueSize, 1.0);
          vs = valueSize * k;
          ls = math.max(minLabelSize, labelSize * k);
        } else {
          vs = _solve(
            items.map((MetricItem e) => e.value),
            valueRoom,
            valueSize,
            minValueSize,
          );
          ls = _solve(
            items.map((MetricItem e) => e.label),
            colOf(0),
            labelSize,
            minLabelSize,
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int i = 0; i < n; i++) ...<Widget>[
              if (i > 0) SizedBox(width: gap),
              Expanded(
                  flex: items[i].flex,
                  child: _tile(context, items[i], vs, ls, cs)),
            ],
          ],
        );
      },
    );
  }

  Widget _tile(
    BuildContext context,
    MetricItem it,
    double vs,
    double ls,
    ColorScheme cs, {
    bool natural = false,
  }) {

    final double k = adaptiveScale(context);
    final Widget? lead = it.dot
        ? Container(
            width: 5 * k,
            height: 5 * k,
            decoration: BoxDecoration(
              color: it.color,
              borderRadius: BorderRadius.circular(1.5 * k),
            ),
          )
        : (it.icon != null
            ? Icon(it.icon, size: iconSize, color: it.color)
            : null);

    if (inline) {
      final TextStyle labelStyle = TextStyle(
        fontSize: ls,
        height: 1.15,
        color: cs.onSurfaceVariant.withValues(alpha: labelOpacity),
      );
      final TextStyle valueStyle = TextStyle(
        fontSize: vs,
        height: 1.15,
        fontWeight: valueWeight,
        color: it.color,
      );

      final InlineSpan valueSpan = fixedValueChars == null
          ? TextSpan(text: it.value, style: valueStyle)
          : WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(
                width: _unitWidth('8' * fixedValueChars!) * vs + 1,
                child: Text(
                  it.value,

                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: valueStyle,
                ),
              ),
            );

      final Widget rich = Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: it.label, style: labelStyle),
            TextSpan(text: ' ', style: labelStyle),
            valueSpan,
          ],
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      );

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (lead != null) ...<Widget>[lead, SizedBox(width: 3 * k)],
          natural ? rich : Flexible(child: rich),
        ],
      );
    }

    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (lead != null) ...<Widget>[lead, SizedBox(width: 3 * k)],
            Flexible(
              child: Text(
                it.value,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: vs,
                  fontWeight: valueWeight,
                  color: it.color,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 1 * k),
        Text(
          it.label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ls,
            height: 1.2,
            color: cs.onSurfaceVariant.withValues(alpha: labelOpacity),
          ),
        ),
      ],
    );
  }

  static double _solve(
    Iterable<String> texts,
    double room,
    double max,
    double min,
  ) {
    double unit = 0;
    for (final String t in texts) {
      unit = math.max(unit, _unitWidth(t));
    }
    if (unit <= 0 || room <= 0) return max;
    return (room / unit).clamp(min, max);
  }

  static double _unitWidth(String s) {
    double w = 0;
    for (final int c in s.runes) {
      if (c > 0x2E80) {
        w += 1.02;
      } else if (c == 0x20) {
        w += 0.30;
      } else if (c == 0x2E) {
        w += 0.32;
      } else if (c >= 0x30 && c <= 0x39) {
        w += 0.58;
      } else {
        w += 0.62;
      }
    }
    return w;
  }
}
