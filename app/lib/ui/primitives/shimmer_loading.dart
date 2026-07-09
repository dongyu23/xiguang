import 'package:flutter/material.dart';

import '../../design/tokens/colors.dart';
import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/motion.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/spacing.dart';

/// 骨架屏加载组件 — 柔和的闪烁效果
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.shimmer,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? AppColors.shimmerBase;
    final highlight = widget.highlightColor ?? AppColors.shimmerHighlight;
    // C6: Pass child to AnimatedBuilder to avoid rebuilding it every frame
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

/// 骨架屏卡片 — 用于列表加载态
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({
    super.key,
    this.height = 80,
    this.borderRadius = 8,
  });

  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: AppSpacing.s9),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// 骨架屏圆形头像
class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({super.key, this.size = 42});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: .72),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 骨架屏文本行
class ShimmerTextLine extends StatelessWidget {
  const ShimmerTextLine({
    super.key,
    this.widthFactor = 0.7,
    this.height = 10,
  });

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: theme.surface.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}
