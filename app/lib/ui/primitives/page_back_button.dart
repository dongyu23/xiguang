import 'package:flutter/material.dart';

import '../../design/themes/extensions/night_theme.dart';

/// 统一返回按钮 — 全 App 子页面共用。
///
/// 替代各页面自造的 `Material + InkWell + SizedBox(42x42) + Icon` 返回按钮，
/// 解决"每个页面返回按钮长得都不一样"的视觉不一致问题。
///
/// - 日间：半透明白底 + 描边
/// - 夜间：半透明白底（暗色背景下显形）
/// - 圆形 hit area 44×44，满足最小触控目标
class PageBackButton extends StatelessWidget {
  const PageBackButton({
    super.key,
    required this.onTap,
    this.iconColor,
    this.size = 42,
  });

  final VoidCallback onTap;
  final Color? iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final foreground = iconColor ?? theme.foregroundMuted;
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: theme.surface.withValues(alpha: .74),
        shape: CircleBorder(
          side: BorderSide(color: theme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Icon(Icons.arrow_back_rounded, size: 20, color: foreground),
          ),
        ),
      ),
    );
  }
}
