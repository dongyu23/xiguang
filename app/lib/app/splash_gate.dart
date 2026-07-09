import 'dart:async';

import 'package:flutter/material.dart';

import '../design/tokens/colors.dart';
import '../design/tokens/motion.dart';

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
      duration: AppMotion.linger,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startSplash());
    });
  }

  Future<void> _startSplash() async {
    // 并行：图片预解码与 1.5s 入场动画同时进行，省掉串行 await precacheImage 的时间
    await Future.wait([
      precacheImage(SplashGate.openingImage, context),
      _controller.forward(),
    ]);
    if (!mounted) return;
    setState(() => _showSplash = false);
    await Future<void>.delayed(AppMotion.normal);
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
            duration: AppMotion.fast,
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
            final exit = AppMotion.easeIn.transform(
              ((animation.value - .74) / .26).clamp(0, 1),
            );
            final appear = AppMotion.easeOut.transform(
              (animation.value / .40).clamp(0, 1),
            );
            final visible = (appear * (1 - exit)).clamp(0.0, 1.0);
            return Material(
              color: Colors.transparent,
              child: Container(
                color: AppColors.paperDark,
                child: Stack(textDirection: TextDirection.ltr, children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: visible,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.asset(
                            SplashGate.openingImage.assetName,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            gaplessPlayback: true,
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
