import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// 隙光 ThemeData 组装 — 完全绕过 Material 默认样式
ThemeData xiguangTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'PingFang SC',
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teaGreen,
      brightness: Brightness.light,
      surface: AppColors.paper,
    ),
    // 覆盖所有默认 Material 样式
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.white.withValues(alpha: .92),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.paper,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.teaGreen),
      ),
      contentPadding: const EdgeInsets.all(14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.teaGreen),
    ),
  );
}
