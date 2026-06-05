import 'dart:math';

import 'package:flutter/material.dart';

import '../../design/tokens/colors.dart';

/// 星空沉浸式空间 — 粒子系统（随机位置 + 亮度 + 大小 + 正弦微动）
///
/// 用于小宇宙视图的背景星图
class StarrySpace extends StatefulWidget {
  const StarrySpace({super.key, this.starCount = 22, this.nodePositions});

  final int starCount;
  final List<Offset>? nodePositions;  // 星点位置（光片节点）

  @override
  State<StarrySpace> createState() => StarrySpaceState();
}

class StarrySpaceState extends State<StarrySpace> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
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
        painter: StarryPainter(
          phase: _controller.value * 2 * pi,
          starCount: widget.starCount,
          nodePositions: widget.nodePositions,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class StarryPainter extends CustomPainter {
  StarryPainter({
    required this.phase,
    this.starCount = 22,
    this.nodePositions,
  });

  final double phase;
  final int starCount;
  final List<Offset>? nodePositions;

  @override
  void paint(Canvas canvas, Size size) {
    // 背景星尘
    for (var i = 0; i < starCount; i++) {
      final x = (i * 37 % size.width).toDouble();
      final y = (i * 53 % size.height).toDouble();
      final brightness = .08 + .06 * sin(phase + i * .7);
      canvas.drawCircle(
        Offset(x, y),
        i.isEven ? 1.4 : 2.1,
        Paint()..color = AppColors.white.withValues(alpha: brightness),
      );
    }

    // 星点节点（光片位置）
    final positions = nodePositions ?? _defaultPositions(size);
    final linePaint = Paint()
      ..color = AppColors.white.withValues(alpha: .24)
      ..strokeWidth = 1.2;
    for (var i = 0; i < positions.length - 1; i++) {
      canvas.drawLine(positions[i], positions[i + 1], linePaint);
    }

    final glowPaint = Paint()..color = AppColors.white.withValues(alpha: .22);
    final starPaint = Paint()..color = AppColors.white.withValues(alpha: .86);
    for (var i = 0; i < positions.length; i++) {
      canvas.drawCircle(positions[i], 18 + i * 2, glowPaint);
      canvas.drawCircle(positions[i], 5 + i.toDouble(), starPaint);
    }
  }

  List<Offset> _defaultPositions(Size size) => [
    Offset(size.width * .18, size.height * .34),
    Offset(size.width * .44, size.height * .22),
    Offset(size.width * .68, size.height * .38),
    Offset(size.width * .36, size.height * .56),
    Offset(size.width * .72, size.height * .66),
  ];

  @override
  bool shouldRepaint(covariant StarryPainter old) =>
      old.phase != phase || old.nodePositions != nodePositions;
}
