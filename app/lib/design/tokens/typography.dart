import 'package:flutter/material.dart';

import 'colors.dart';

/// 隙光字体层级 — 使用系统默认字体，保持低压力阅读节奏
class AppText {
  AppText._();

  static const nightInk = Color(0xFFF4EFE4);
  static const nightInkMuted = Color(0xFFC9D0C8);
  static const nightAccent = Color(0xFFA6CDBB);

  static TextStyle onNight(TextStyle style, bool nightMode) {
    if (!nightMode) return style;
    final color = style.color;
    if (color == AppColors.ink) {
      return style.copyWith(color: nightInk);
    }
    if (color == AppColors.inkMuted) {
      return style.copyWith(color: nightInkMuted);
    }
    if (color == AppColors.teaGreen) {
      return style.copyWith(color: nightAccent);
    }
    return style;
  }

  // 标签行
  static const eyebrow = TextStyle(
    fontSize: 11,
    height: 1.1,
    fontWeight: FontWeight.w700,
    color: AppColors.teaGreen,
    letterSpacing: 0,
  );

  // 页面大标题
  static const hero = TextStyle(
    fontFamily: 'PingFangShiGuangTi',
    fontSize: 34,
    height: 1.08,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    letterSpacing: 0,
  );

  // 区块标题
  static const titleMedium = TextStyle(
    fontSize: 18,
    height: 1.22,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: 0,
  );

  // 卡片标题
  static const titleSmall = TextStyle(
    fontSize: 15,
    height: 1.28,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: 0,
  );

  // 正文
  static const body = TextStyle(
    fontSize: 14,
    height: 1.58,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
    letterSpacing: 0,
  );

  // 次要正文
  static const bodyMuted = TextStyle(
    fontSize: 13,
    height: 1.45,
    color: AppColors.inkMuted,
    letterSpacing: 0,
  );

  // 占位文字
  static const placeholder = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: AppColors.inkMuted,
    letterSpacing: 0,
  );

  // 辅助说明
  static const caption = TextStyle(
    fontSize: 12,
    height: 1.32,
    color: AppColors.inkMuted,
    letterSpacing: 0,
  );

  // 芯片/Chip 文字
  static const chip = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  // 底部导航
  static const nav = TextStyle(
    fontSize: 11,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  // 深色背景上的标题
  static const inverseTitle = TextStyle(
    fontSize: 20,
    height: 1.22,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 0,
  );

  // 深色背景上的正文
  static const inverseBody = TextStyle(
    fontSize: 13,
    height: 1.5,
    color: Colors.white,
    letterSpacing: 0,
  );
}
