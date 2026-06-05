import 'package:flutter/material.dart';

import '../../design/tokens/colors.dart';
import '../../design/tokens/radius.dart';

/// 微光按钮 — ShaderMask 径向渐变光晕
///
/// "捕光"等核心按钮使用，背景色 + 顶部微光层
class GlowButton extends StatelessWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor = AppColors.ink,
    this.foregroundColor = Colors.white,
    this.icon,
    this.height = 52,
    this.glowColor = AppColors.white,
    this.glowIntensity = .18,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;
  final double height;
  final Color glowColor;
  final double glowIntensity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          minimumSize: Size.fromHeight(height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 20) : null,
        label: Text(label),
      ),
    );
  }
}
