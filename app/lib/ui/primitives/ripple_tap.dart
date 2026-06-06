import 'package:flutter/material.dart';

import '../../design/tokens/motion.dart';

/// 水波纹点击反馈 — 从触摸点向外扩散的涟漪
///
/// 包裹任意 widget，点击时产生波纹动画
class RippleTap extends StatefulWidget {
  const RippleTap({
    super.key,
    required this.child,
    this.onTap,
    this.rippleColor = const Color(0xFF72A58F),
    this.rippleOpacity = .16,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color rippleColor;
  final double rippleOpacity;

  @override
  State<RippleTap> createState() => _RippleTapState();
}

class _RippleTapState extends State<RippleTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Offset? _tapPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.ripple,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        _tapPosition = details.localPosition;
        _controller.forward(from: 0);
      },
      onTap: widget.onTap,
      child: Stack(
        children: [
          widget.child,
          if (_tapPosition != null)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, child) => CustomPaint(
                  painter: _RipplePainter(
                    center: _tapPosition!,
                    radius: _controller.value * 80,
                    color: widget.rippleColor.withValues(
                        alpha: widget.rippleOpacity * (1 - _controller.value)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(
      {required this.center, required this.radius, required this.color});

  final Offset center;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) =>
      old.center != center || old.radius != radius;
}
