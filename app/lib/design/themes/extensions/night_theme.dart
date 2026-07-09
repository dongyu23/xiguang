import 'package:flutter/material.dart';
import '../../tokens/colors.dart';

/// 夜间模式主题扩展 — 替代 prop drilling 的 nightMode 参数
class NightTheme extends ThemeExtension<NightTheme> {
  const NightTheme({
    required this.isNight,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.foreground,
    required this.foregroundMuted,
    required this.accent,
    required this.border,
    required this.navBackground,
  });

  final bool isNight;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color foreground;
  final Color foregroundMuted;
  final Color accent;
  final Color border;
  final Color navBackground;

  factory NightTheme.day() => const NightTheme(
        isNight: false,
        background: AppColors.paper,
        surface: Color(0xFFFFFCF6),
        surfaceHigh: Color(0xFFFFFCF6),
        foreground: AppColors.ink,
        foregroundMuted: AppColors.inkMuted,
        accent: AppColors.teaGreen,
        border: AppColors.line,
        navBackground: Color(0xFFFFFCF6),
      );

  factory NightTheme.night() => const NightTheme(
        isNight: true,
        background: Color(0xFF142322),
        surface: Color(0xFF213433),
        surfaceHigh: Color(0xFF172625),
        foreground: Color(0xFFF4EFE4),
        foregroundMuted: Color(0xFFC9D0C8),
        accent: Color(0xFFA6CDBB),
        border: Color(0xFF2A3E3C),
        navBackground: Color(0xFF172625),
      );

  static NightTheme of(BuildContext context) {
    return Theme.of(context).extension<NightTheme>() ?? NightTheme.day();
  }

  @override
  NightTheme copyWith({
    bool? isNight,
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? foreground,
    Color? foregroundMuted,
    Color? accent,
    Color? border,
    Color? navBackground,
  }) {
    return NightTheme(
      isNight: isNight ?? this.isNight,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      foreground: foreground ?? this.foreground,
      foregroundMuted: foregroundMuted ?? this.foregroundMuted,
      accent: accent ?? this.accent,
      border: border ?? this.border,
      navBackground: navBackground ?? this.navBackground,
    );
  }

  @override
  NightTheme lerp(NightTheme? other, double t) {
    if (other is! NightTheme) return this;
    return NightTheme(
      isNight: t < 0.5 ? isNight : other.isNight,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      foregroundMuted: Color.lerp(foregroundMuted, other.foregroundMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      border: Color.lerp(border, other.border, t)!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
    );
  }
}
