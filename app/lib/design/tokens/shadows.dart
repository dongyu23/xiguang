import 'package:flutter/material.dart';

import 'colors.dart';
import 'radius.dart';

/// 隙光柔和阴影 — 带色彩倾向的非纯黑投影，元素像漂浮在轻雾里
final softShadow = [
  BoxShadow(
    color: const Color(0xFF23413F).withValues(alpha: .08),
    blurRadius: 28,
    offset: const Offset(0, 16),
  ),
];

/// 隙光卡片通用装饰 — 毛玻璃质感 + 柔和投影 + 圆角
BoxDecoration softDecoration(Color color, {double radius = AppRadius.md}) {
  return BoxDecoration(
    color: color.withValues(alpha: .92),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.line),
    boxShadow: softShadow,
  );
}

/// 底部导航栏专用装饰
BoxDecoration navBarDecoration() {
  return BoxDecoration(
    color: AppColors.white.withValues(alpha: .94),
    borderRadius: BorderRadius.circular(AppRadius.md),
    boxShadow: softShadow,
    border: Border.all(color: AppColors.line),
  );
}
