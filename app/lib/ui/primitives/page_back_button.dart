import 'package:flutter/material.dart';

import '../../design/tokens/colors.dart';

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
    this.nightMode = false,
    this.iconColor,
    this.size = 42,
  });

  final VoidCallback onTap;
  final bool nightMode;
  final Color? iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fg = iconColor ?? (nightMode ? AppColors.white : AppColors.inkMuted);
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: nightMode
            ? AppColors.white.withValues(alpha: .10)
            : AppColors.white.withValues(alpha: .74),
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Icon(Icons.arrow_back_rounded, size: 20, color: fg),
          ),
        ),
      ),
    );
  }
}
