import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../design/tokens/colors.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  static const openingImage = AssetImage('assets/picture/打开展示.png');
  static const curtainImage = AssetImage('assets/picture/窗帘舞动.gif');

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _mountSplash = true;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startSplash());
    });
  }

  Future<void> _startSplash() async {
    await Future.wait([
      precacheImage(SplashGate.openingImage, context),
      precacheImage(SplashGate.curtainImage, context),
    ]);
    if (!mounted) return;
    await _controller.forward();
    if (!mounted) return;
    setState(() => _showSplash = false);
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;
    setState(() => _mountSplash = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
      widget.child,
      if (_mountSplash)
        IgnorePointer(
          ignoring: true,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _showSplash ? 1 : 0,
            child: _OpeningSplash(animation: _controller),
          ),
        ),
    ]);
  }
}

class _OpeningSplash extends StatelessWidget {
  const _OpeningSplash({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final splashSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final logoWidth = min(
          splashSize.width * .78,
          splashSize.height * .42,
        ).clamp(220.0, 430.0);
        final curtainWidth = min(
          splashSize.width * .64,
          splashSize.height * .54,
        ).clamp(230.0, 430.0);

        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(animation.value.clamp(0, 1));
            final exit = Curves.easeInCubic.transform(
              ((animation.value - .74) / .26).clamp(0, 1),
            );
            final logo = Curves.easeOutBack.transform(
              ((animation.value - .22) / .48).clamp(0, 1),
            );
            final curtain = Curves.easeOutQuart.transform(
              ((animation.value - .02) / .50).clamp(0, 1),
            );
            final curtainFade = 1 -
                Curves.easeInCubic.transform(
                  ((animation.value - .56) / .26).clamp(0, 1),
                );
            return Material(
              color: Colors.transparent,
              child: Container(
                color: Color.lerp(
                  const Color(0xFF090D0C),
                  const Color(0xFFFBF7EF),
                  min(t * 1.12, 1),
                ),
                child: Stack(
                  textDirection: TextDirection.ltr,
                  children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SplashAtmospherePainter(
                        progress: animation.value,
                        exit: exit,
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(.22, -.08),
                    child: Transform.translate(
                      offset: Offset(
                        -96 * (1 - curtain),
                        -22 + 8 * sin(t * pi),
                      ),
                      child: Transform.scale(
                        scale: .98 + .03 * sin(animation.value * pi),
                        child: Opacity(
                          opacity: ((1 - exit) * curtainFade * .46).clamp(0, 1),
                          child: SizedBox(
                            width: curtainWidth,
                            child: Image.asset(
                              SplashGate.curtainImage.assetName,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - logo) - 8 * exit),
                      child: Opacity(
                        opacity: (logo * (1 - exit)).clamp(0, 1),
                        child: SizedBox(
                          width: logoWidth,
                          child: AspectRatio(
                            aspectRatio: 2 / 3,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF5B4A3F)
                                        .withValues(alpha: .12 * (1 - exit)),
                                    blurRadius: 38,
                                    offset: const Offset(0, 20),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  SplashGate.openingImage.assetName,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

class _SplashAtmospherePainter extends CustomPainter {
  const _SplashAtmospherePainter({
    required this.progress,
    required this.exit,
  });

  final double progress;
  final double exit;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final wash = Paint()
      ..shader = RadialGradient(
        center: const Alignment(.08, -.18),
        radius: 1.05,
        colors: [
          const Color(0xFFFFF7D8).withValues(alpha: .50 * (1 - exit)),
          const Color(0xFF8DC5B5).withValues(alpha: .12 * (1 - exit)),
          Colors.transparent,
        ],
        stops: const [.0, .48, 1],
      ).createShader(rect);
    canvas.drawRect(rect, wash);

    final linePaint = Paint()
      ..color = AppColors.teaGreen.withValues(alpha: .12 * (1 - exit))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 7; i++) {
      final y = size.height * (.18 + i * .105);
      final dx = size.width * (.08 * sin(progress * pi + i));
      final path = Path()..moveTo(-30 + dx, y);
      path.cubicTo(
        size.width * .28,
        y + 22 * sin(progress * pi + i),
        size.width * .68,
        y - 28,
        size.width + 30,
        y + 10 * cos(progress * pi + i),
      );
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashAtmospherePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.exit != exit;
  }
}
