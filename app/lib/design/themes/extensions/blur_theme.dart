import 'package:flutter/material.dart';

/// 毛玻璃主题扩展 — 组件可通过 Theme.of(context).extension<BlurTheme>() 访问
class BlurTheme extends ThemeExtension<BlurTheme> {
  const BlurTheme({
    required this.sigma,
    required this.opacity,
    required this.tint,
  });

  final double sigma; // BackdropFilter 模糊量
  final double opacity; // 容器透明度
  final Color tint; // 着色

  /// 默认毛玻璃参数
  factory BlurTheme.light() => const BlurTheme(
        sigma: 8,
        opacity: .86,
        tint: Color(0xFFFFFCF6),
      );

  factory BlurTheme.heavy() => const BlurTheme(
        sigma: 12,
        opacity: .92,
        tint: Color(0xFFF6F3EC),
      );

  @override
  BlurTheme copyWith({double? sigma, double? opacity, Color? tint}) {
    return BlurTheme(
      sigma: sigma ?? this.sigma,
      opacity: opacity ?? this.opacity,
      tint: tint ?? this.tint,
    );
  }

  @override
  BlurTheme lerp(ThemeExtension<BlurTheme>? other, double t) {
    if (other is! BlurTheme) return this;
    return BlurTheme(
      sigma: sigma + (other.sigma - sigma) * t,
      opacity: opacity + (other.opacity - opacity) * t,
      tint: Color.lerp(tint, other.tint, t)!,
    );
  }
}
