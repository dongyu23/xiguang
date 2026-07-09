import 'dart:math';
import 'package:flutter/material.dart';

import '../../design/tokens/colors.dart';
import '../../design/tokens/motion.dart';

/// 海洋沉浸式空间 — 多层叠加正弦波
///
/// 不同振幅/频率/相位/颜色透明度，产生纵深波浪感
class OceanSpace extends StatefulWidget {
  const OceanSpace({super.key, this.waveLayers = 3});

  final int waveLayers;

  @override
  State<OceanSpace> createState() => _OceanSpaceState();
}

class _OceanSpaceState extends State<OceanSpace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.oceanAmbient,
    )..repeat();
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
      builder: (_, __) => CustomPaint(
        painter: OceanPainter(
          phase: _controller.value * 2 * pi,
          layers: widget.waveLayers,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class OceanPainter extends CustomPainter {
  OceanPainter({required this.phase, this.layers = 3});

  final double phase;
  final int layers;

  // Reuse Paint objects per layer to avoid per-frame allocations
  static final _paints = [
    Paint()
      ..color = AppColors.teaGreen.withValues(alpha: .06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
    Paint()
      ..color = AppColors.teaGreen.withValues(alpha: .10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3,
    Paint()
      ..color = AppColors.teaGreen.withValues(alpha: .14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var layer = 0; layer < layers; layer++) {
      final path = Path();
      path.moveTo(0, size.height * (.3 + layer * .2));

      for (var x = 0.0; x <= size.width; x += 18) {
        final amplitude = 5.0 + layer * 3;
        final frequency = 28.0 + layer * 14;
        final yOffset = sin(x / frequency + phase + layer * .6) * amplitude;
        path.lineTo(x, size.height * (.3 + layer * .2) + yOffset);
      }
      canvas.drawPath(path, _paints[layer]);
    }
  }

  @override
  bool shouldRepaint(covariant OceanPainter old) => old.phase != phase;
}
