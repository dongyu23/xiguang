import 'dart:math';

import 'package:flutter/material.dart';

import '../../design/tokens/colors.dart';

/// 沉浸式空间画布基类 — 全屏 CustomPaint + 可选子组件
class SpaceCanvas extends StatelessWidget {
  const SpaceCanvas({super.key, required this.painter, this.child, this.backgroundColor});

  final CustomPainter painter;
  final Widget? child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: CustomPaint(painter: painter, child: child ?? const SizedBox.expand()),
    );
  }
}

/// 氛围背景 — 莫兰迪渐变 + 低透明度横向线条
class AtmosphereBackground extends StatelessWidget {
  const AtmosphereBackground({super.key, this.lineCount = 6});
  final int lineCount;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AtmoPainter(lineCount: lineCount),
      child: const SizedBox.expand(),
    );
  }
}

class _AtmoPainter extends CustomPainter {
  _AtmoPainter({this.lineCount = 6});
  final int lineCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = AppColors.gradientAtmosphere.createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);

    final linePaint = Paint()
      ..color = AppColors.teaGreen.withValues(alpha: .08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < lineCount; i++) {
      final y = size.height * (.12 + i * .12);
      final path = Path()..moveTo(-20, y);
      for (var x = -20.0; x <= size.width + 20; x += 32) {
        path.lineTo(x, y + sin((x / 38) + i) * 8);
      }
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AtmoPainter oldDelegate) => false;
}
