import 'package:flutter/material.dart';

import 'colors.dart';
import 'radius.dart';

/// 隙光柔和阴影 — 带色彩倾向的非纯黑投影，元素像漂浮在轻雾里
final softShadow = [
  BoxShadow(
    color: AppColors.nightShadow.withValues(alpha: .08),
    blurRadius: 28,
    offset: const Offset(0, 16),
  ),
];

// ─── Decoration 缓存 ─────────────────────────────────────────────
// 每次 build 调用 softDecoration() 会新建 BoxDecoration，全局高频分配。
// 用 Map 缓存常见参数组合，命中时直接返回已有实例。

final Map<int, BoxDecoration> _softCache = {};
final Map<double, BoxDecoration> _nightCache = {};

// L9: Use Object.hash instead of XOR to avoid collision risk
int _softKey(Color color, double radius) => Object.hash(color, radius);

/// 隙光卡片通用装饰 — 毛玻璃质感 + 柔和投影 + 圆角
BoxDecoration softDecoration(Color color,
    {double radius = AppRadius.md, bool nightMode = false}) {
  if (nightMode) return nightDecoration(radius: radius);
  final key = _softKey(color, radius);
  return _softCache.putIfAbsent(
      key,
      () => BoxDecoration(
            color: color.withValues(alpha: .92),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.line),
            boxShadow: softShadow,
          ));
}

/// 夜间模式卡片装饰 — 全局统一，替代各页面的 _nightCard() / _nightPanelDecoration()
BoxDecoration nightDecoration({double radius = AppRadius.md}) {
  return _nightCache.putIfAbsent(
      radius,
      () => BoxDecoration(
            color: AppColors.nightSurface.withValues(alpha: .78),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.white.withValues(alpha: .13)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .16),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ));
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
