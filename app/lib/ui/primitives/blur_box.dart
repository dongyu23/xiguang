import 'dart:ui';

import 'package:flutter/material.dart';

import '../../design/tokens/blur.dart';
import '../../design/tokens/radius.dart';

/// 毛玻璃容器 — BackdropFilter + ImageFilter.blur
///
/// 用法：
/// ```dart
/// BlurBox(sigma: AppBlur.medium, child: YourContent())
/// ```
class BlurBox extends StatelessWidget {
  const BlurBox({
    super.key,
    required this.child,
    this.sigma = AppBlur.medium,
    this.borderRadius = AppRadius.md,
    this.tint = const Color(0xFFFFFCF6),
    this.tintOpacity = .86,
    this.padding,
    this.width,
    this.height,
  });

  final Widget child;
  final double sigma;
  final double borderRadius;
  final Color tint;
  final double tintOpacity;
  final EdgeInsets? padding;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: tintOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: child,
        ),
      ),
    );
  }
}
