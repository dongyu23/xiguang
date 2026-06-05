import 'package:flutter/material.dart';

/// 微光主题扩展 — 光晕效果的参数
class GlowTheme extends ThemeExtension<GlowTheme> {
  const GlowTheme({
    required this.radius,
    required this.intensity,
    required this.color,
  });

  final double radius;     // 径向渐变半径
  final double intensity;  // 强度 (0-1)
  final Color color;       // 光晕颜色

  factory GlowTheme.default_() => const GlowTheme(
        radius: 120,
        intensity: .3,
        color: Color(0xFFFFFCF6),
      );

  @override
  GlowTheme copyWith({double? radius, double? intensity, Color? color}) {
    return GlowTheme(
      radius: radius ?? this.radius,
      intensity: intensity ?? this.intensity,
      color: color ?? this.color,
    );
  }

  @override
  GlowTheme lerp(ThemeExtension<GlowTheme>? other, double t) {
    if (other is! GlowTheme) return this;
    return GlowTheme(
      radius: radius + (other.radius - radius) * t,
      intensity: intensity + (other.intensity - intensity) * t,
      color: Color.lerp(color, other.color, t)!,
    );
  }
}
