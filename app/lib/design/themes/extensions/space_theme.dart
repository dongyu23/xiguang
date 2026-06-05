import 'package:flutter/material.dart';

/// 沉浸式空间主题扩展
class SpaceTheme extends ThemeExtension<SpaceTheme> {
  const SpaceTheme({
    required this.starDensity,
    required this.waveAmplitude,
    required this.islandSpacing,
  });

  final double starDensity;    // 星空粒子密度 (0-1)
  final double waveAmplitude;  // 海洋波浪振幅
  final double islandSpacing;  // 岛屿间距

  factory SpaceTheme.default_() => const SpaceTheme(
        starDensity: .08,
        waveAmplitude: 8,
        islandSpacing: 24,
      );

  @override
  SpaceTheme copyWith({double? starDensity, double? waveAmplitude, double? islandSpacing}) {
    return SpaceTheme(
      starDensity: starDensity ?? this.starDensity,
      waveAmplitude: waveAmplitude ?? this.waveAmplitude,
      islandSpacing: islandSpacing ?? this.islandSpacing,
    );
  }

  @override
  SpaceTheme lerp(ThemeExtension<SpaceTheme>? other, double t) {
    if (other is! SpaceTheme) return this;
    return SpaceTheme(
      starDensity: starDensity + (other.starDensity - starDensity) * t,
      waveAmplitude: waveAmplitude + (other.waveAmplitude - waveAmplitude) * t,
      islandSpacing: islandSpacing + (other.islandSpacing - islandSpacing) * t,
    );
  }
}
