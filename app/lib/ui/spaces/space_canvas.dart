import 'dart:math';

import 'package:flutter/material.dart';
import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/colors.dart';
import '../../design/tokens/motion.dart';

/// 沉浸式空间画布基类 — 全屏 CustomPaint + 可选子组件
class SpaceCanvas extends StatelessWidget {
  const SpaceCanvas(
      {super.key, required this.painter, this.child, this.backgroundColor});

  final CustomPainter painter;
  final Widget? child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: CustomPaint(
          painter: painter, child: child ?? const SizedBox.expand()),
    );
  }
}

/// 氛围背景 — 莫兰迪渐变 + 低透明度横向线条
///
/// [animated] 为 false 时渲染静态版本，适用于登录页等不需要持续动画的场景。
class AtmosphereBackground extends StatefulWidget {
  const AtmosphereBackground(
      {super.key, this.lineCount = 6, this.animated = true});
  final int lineCount;
  final bool animated;

  @override
  State<AtmosphereBackground> createState() => _AtmosphereBackgroundState();
}

class _AtmosphereBackgroundState extends State<AtmosphereBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.canvasAmbient,
    );
    if (widget.animated && !_isRunningWidgetTest) {
      // 延迟一帧启动动画，避免页面切换时首帧卡顿
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.repeat();
      });
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.animated) return;
    if (state == AppLifecycleState.resumed && !_controller.isAnimating) {
      _controller.repeat();
    } else if (state == AppLifecycleState.paused && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    if (widget.animated) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final gradient = theme.isNight
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.nightBackground,
              AppColors.nightGradientMid,
              AppColors.nightGradientEnd,
            ],
          )
        : AppColors.gradientAtmosphere;
    final lineColor = (theme.isNight ? theme.foreground : theme.accent)
        .withValues(alpha: theme.isNight ? .07 : .08);
    if (!widget.animated) {
      // 静态模式：只渲染一次，不驱动动画
      return CustomPaint(
        painter: _AtmoPainter(
          lineCount: widget.lineCount,
          gradient: gradient,
          lineColor: lineColor,
          phase: 0,
        ),
        child: const SizedBox.expand(),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _AtmoPainter(
          lineCount: widget.lineCount,
          gradient: gradient,
          lineColor: lineColor,
          phase: _controller.value * pi * 2,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

bool get _isRunningWidgetTest {
  return WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');
}

class _AtmoPainter extends CustomPainter {
  _AtmoPainter({
    this.lineCount = 6,
    required this.gradient,
    required this.lineColor,
    required this.phase,
  });

  final int lineCount;
  final Gradient gradient;
  final Color lineColor;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..shader = gradient.createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < lineCount; i++) {
      final y = size.height * (.12 + i * .12) + sin(phase + i) * 2.2;
      final path = Path()..moveTo(-20, y);
      for (var x = -20.0; x <= size.width + 20; x += 32) {
        path.lineTo(
          x,
          y + sin((x / 38) + i + phase * .7) * 8,
        );
      }
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AtmoPainter oldDelegate) =>
      oldDelegate.lineCount != lineCount ||
      oldDelegate.gradient != gradient ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.phase != phase;
}
