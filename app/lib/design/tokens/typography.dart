import 'package:flutter/material.dart';

import 'colors.dart';

/// 隙光字体层级 — 使用系统默认字体，保持低压力阅读节奏
class AppText {
  AppText._();

  static const nightInk = AppColors.nightInk;
  static const nightInkMuted = AppColors.nightInkMuted;
  static const nightAccent = AppColors.nightAccent;

  // 标签行
  static const eyebrow = TextStyle(
    fontSize: 11,
    height: 1.1,
    fontWeight: FontWeight.w700,
    color: AppColors.teaGreen,
    letterSpacing: 0,
  );

  // 比 eyebrow 略大的强化标签，常用于登录/注册/账本顶部品牌行。
  // 替代 `eyebrow.copyWith(fontSize: 13)` 这类临时放大。
  static const eyebrowLarge = TextStyle(
    fontSize: 13,
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

  // 次级页面标题（比 hero 小一档，常用于子页面）。
  // 替代 `hero.copyWith(fontSize: 28)` 这类临时缩放。
  static const subHero = TextStyle(
    fontFamily: 'PingFangShiGuangTi',
    fontSize: 28,
    height: 1.12,
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

  // 子页面/弹窗标题，比 titleMedium 大一档。
  // 替代 `titleMedium.copyWith(fontSize: 20)` 这类临时放大。
  static const titleLarge = TextStyle(
    fontSize: 20,
    height: 1.2,
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

  // 加粗正文 — 替代 `body.copyWith(fontWeight: w600)`。
  static const bodyStrong = TextStyle(
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w600,
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

  // 加粗辅助说明 — 替代 `caption.copyWith(fontWeight: w600)`。
  static const captionStrong = TextStyle(
    fontSize: 12,
    height: 1.32,
    fontWeight: FontWeight.w600,
    color: AppColors.inkMuted,
    letterSpacing: 0,
  );

  // 更小号辅助说明（角标、密度极高的二级标签）。
  // 替代 `caption.copyWith(fontSize: 10)` / `fontSize: 11` 这类临时缩小。
  static const microLabel = TextStyle(
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w700,
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
