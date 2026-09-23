import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../app/theme.dart';














class FilteredImage extends StatelessWidget {
  const FilteredImage({
    super.key,
    required this.image,
    this.brightness = 0,
    this.fade = 0,
    this.blur = 0,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallback,
  });

  final ImageProvider<Object> image;

  
  final double brightness;

  
  final double fade;

  
  final double blur;

  final BoxFit fit;
  final double? width;
  final double? height;

  
  
  
  final ImageProvider<Object>? fallback;

  @override
  Widget build(BuildContext context) {
    
    final Color? tint = brightness == 0
        ? null
        : (brightness > 0 ? Colors.white : Colors.black)
            .withValues(alpha: brightness.abs().clamp(0.0, 1.0));

    Widget img = Image(
      image: image,
      fit: fit,
      width: width,
      height: height,
      color: tint,
      colorBlendMode: tint == null ? null : BlendMode.srcATop,
      errorBuilder: fallback == null
          ? null
          : (BuildContext _, Object __, StackTrace? ___) => Image(
                image: fallback!,
                fit: fit,
                width: width,
                height: height,
              ),
    );
    
    if (fade > 0) {
      img = ColorFiltered(
        colorFilter: AppTheme.saturationFilter(1.0 - fade),
        child: img,
      );
    }
    if (blur > 0) {
      img = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: img,
      );
    }
    return img;
  }
}
