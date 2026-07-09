import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/motion.dart';
import '../tokens/radius.dart';
import 'extensions/night_theme.dart';

/// 隙光页面切换：纯 Fade（不带 Material 3 默认的 zoom），与产品"不打扰"气质一致。
/// 替代 ZoomPageTransitionsBuilder（用户反馈："明显看到一个重置效果"）。
class _FadeOnlyPageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeOnlyPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: AppMotion.easeOut),
      child: child,
    );
  }
}

/// 隙光 ThemeData 组装 — 同时支持日间和夜间，按 [nightMode] 切换 scaffold/canvas 颜色。
///
/// 历史问题：原先 scaffoldBackgroundColor 固定为日间纸色，夜间模式下切换页面时，
/// 页面转场动画会先用 canvasColor/Material 默认底色绘制一帧，导致夜间出现白色闪屏。
///
/// 修复：根据 [nightMode] 同步切换 scaffoldBackgroundColor、canvasColor、appBar、
/// colorScheme.brightness 等，使路由动画期间底层颜色就和夜间背景一致。
ThemeData xiguangTheme({bool nightMode = false}) {
  final night = nightMode ? NightTheme.night() : NightTheme.day();
  final background = night.background;
  final brightness = nightMode ? Brightness.dark : Brightness.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    dialogTheme: DialogThemeData(backgroundColor: night.surface),
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teaGreen,
      brightness: brightness,
      surface: nightMode ? night.surface : AppColors.paper,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: nightMode ? night.surface : AppColors.white.withValues(alpha: .92),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: nightMode ? night.surface : AppColors.paper,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: night.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: night.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: night.accent),
      ),
      contentPadding: const EdgeInsets.all(14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        // 与 FilledButton 等高，避免并排时一高一矮。
        // 单独使用的 OutlinedButton 想要更紧凑（例如行内"重试"），
        // 在调用处显式覆盖 minimumSize 即可。
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: night.accent),
    ),
    // 全 App 页面切换统一用 Fade，覆盖 Material 3 默认的 ZoomPageTransitionsBuilder。
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _FadeOnlyPageTransitionsBuilder(),
        TargetPlatform.iOS: _FadeOnlyPageTransitionsBuilder(),
        TargetPlatform.linux: _FadeOnlyPageTransitionsBuilder(),
        TargetPlatform.macOS: _FadeOnlyPageTransitionsBuilder(),
        TargetPlatform.windows: _FadeOnlyPageTransitionsBuilder(),
        TargetPlatform.fuchsia: _FadeOnlyPageTransitionsBuilder(),
      },
    ),
    extensions: [night],
  );
}
