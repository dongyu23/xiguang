import 'package:flutter/material.dart';

class IslandSpace extends StatelessWidget {
  const IslandSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        painter: _IslandSpacePainter(), child: const SizedBox.expand());
  }
}

class _IslandSpacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant _IslandSpacePainter oldDelegate) => false;
}
