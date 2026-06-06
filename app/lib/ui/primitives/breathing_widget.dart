import 'package:flutter/material.dart';

import '../../design/tokens/motion.dart';

/// 呼吸感动画包装器 — 正弦缓动透明度 + 缩放
///
/// 包裹任意 widget，使其产生柔和呼吸感（透明度 + 1%-3% 缩放浮动）
class BreathingWidget extends StatefulWidget {
  const BreathingWidget({
    super.key,
    required this.child,
    this.duration = AppMotion.breath,
    this.minOpacity = .82,
    this.maxOpacity = 1.0,
    this.scaleRange = .02,
  });

  final Widget child;
  final Duration duration;
  final double minOpacity;
  final double maxOpacity;
  final double scaleRange;

  @override
  State<BreathingWidget> createState() => _BreathingWidgetState();
}

class _BreathingWidgetState extends State<BreathingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Opacity(
        opacity: widget.minOpacity +
            (widget.maxOpacity - widget.minOpacity) * _controller.value,
        child: Transform.scale(
          scale: 1.0 + widget.scaleRange * _controller.value,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
