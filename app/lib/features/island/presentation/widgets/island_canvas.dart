import 'package:flutter/material.dart';

class IslandCanvas extends StatelessWidget {
  const IslandCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        painter: _IslandPainter(), child: const SizedBox.expand());
  }
}

class _IslandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant _IslandPainter oldDelegate) => false;
}
