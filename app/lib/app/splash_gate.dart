import 'dart:async';

import 'package:flutter/material.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  static const openingImage = AssetImage('assets/picture/打开展示.png');

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
    await precacheImage(SplashGate.openingImage, context);
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
    return Stack(textDirection: TextDirection.ltr, children: [
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
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final exit = Curves.easeInCubic.transform(
              ((animation.value - .74) / .26).clamp(0, 1),
            );
            final appear = Curves.easeOutCubic.transform(
              (animation.value / .40).clamp(0, 1),
            );
            final visible = (appear * (1 - exit)).clamp(0.0, 1.0);
            return Material(
              color: Colors.transparent,
              child: Container(
                color: const Color(0xFFFBF7EF),
                child: Stack(textDirection: TextDirection.ltr, children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: visible,
                      child: Image.asset(
                        SplashGate.openingImage.assetName,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        gaplessPlayback: true,
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
