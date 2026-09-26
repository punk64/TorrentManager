import 'package:flutter/material.dart';
import '../app/adaptive.dart';

const double kDesignWidthDp = 445;

const double kNoScaleMinDp = 360;

const double kNoScaleMaxDp = 480;

const double kAdaptiveMinScale = 0.85;
const double kAdaptiveMaxScale = 1.15;

double adaptiveScale(BuildContext context) {
  final MediaQueryData? mq = MediaQuery.maybeOf(context);
  final double w = mq?.size.width ?? 0;
  if (w <= 0) return 1.0;
  if (w < kNoScaleMinDp) {
    return (w / kNoScaleMinDp).clamp(kAdaptiveMinScale, 1.0);
  }
  if (w > kNoScaleMaxDp) {
    return (w / kNoScaleMaxDp).clamp(1.0, kAdaptiveMaxScale);
  }
  return 1.0;
}

double af(BuildContext context, double base) => base * adaptiveScale(context);

EdgeInsets afEdgeInsets(
  BuildContext context, {
  double left = 0,
  double top = 0,
  double right = 0,
  double bottom = 0,
}) {
  final double k = adaptiveScale(context);
  return EdgeInsets.fromLTRB(left * k, top * k, right * k, bottom * k);
}
