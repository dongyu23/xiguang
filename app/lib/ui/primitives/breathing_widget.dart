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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    // M11: Delay animation start by one frame to avoid first-frame jank
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.repeat(reverse: true);
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // M11: Pause animation when app is backgrounded
    if (state == AppLifecycleState.paused && _controller.isAnimating) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
