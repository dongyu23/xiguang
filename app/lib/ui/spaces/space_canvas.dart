import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../design/tokens/colors.dart';

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
class AtmosphereBackground extends ConsumerStatefulWidget {
  const AtmosphereBackground({super.key, this.lineCount = 6});
  final int lineCount;

  @override
  ConsumerState<AtmosphereBackground> createState() =>
      _AtmosphereBackgroundState();
}

class _AtmosphereBackgroundState extends ConsumerState<AtmosphereBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 11000),
    );
    if (!_isRunningWidgetTest) {
      _controller.repeat();
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_controller.isAnimating) {
      _controller.repeat();
    } else if (state == AppLifecycleState.paused && _controller.isAnimating) {
      _controller.stop();
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
    final nightMode = ref.watch(nightModeProvider);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _AtmoPainter(
          lineCount: widget.lineCount,
          nightMode: nightMode,
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
    required this.nightMode,
    required this.phase,
  });

  final int lineCount;
  final bool nightMode;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = (nightMode
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF142322),
                    Color(0xFF243D3A),
                    Color(0xFF4E6054),
                  ],
                )
              : AppColors.gradientAtmosphere)
          .createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);

    final linePaint = Paint()
      ..color = (nightMode ? AppColors.white : AppColors.teaGreen)
          .withValues(alpha: nightMode ? .07 : .08)
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
      oldDelegate.nightMode != nightMode ||
      oldDelegate.phase != phase;
}
