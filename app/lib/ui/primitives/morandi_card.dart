import 'package:flutter/material.dart';

import '../../design/tokens/colors.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/shadows.dart';

/// 莫兰迪风格卡片基类 — 圆角+低饱和底色+柔和投影+毛玻璃可选
///
/// 所有光片卡片、主题岛卡片、设置卡片的基础组件
class MorandiCard extends StatelessWidget {
  const MorandiCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color = AppColors.white,
    this.radius = AppRadius.md,
    this.onTap,
    this.withBorder = true,
  });

  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color color;
  final double radius;
  final VoidCallback? onTap;
  final bool withBorder;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(radius),
        border: withBorder ? Border.all(color: AppColors.line) : null,
        boxShadow: softShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
