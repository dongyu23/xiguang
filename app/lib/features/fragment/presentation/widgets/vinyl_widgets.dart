import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../design/tokens/colors.dart';

// MOTION_EXEMPT: self-painted
// 此文件包含自绘动画——黑胶旋转(4200ms)、声波(5600ms)、音乐轨迹(4800ms)、唱针(360ms)。
// 这类动画是音频播放器的"绘画"性表达，需要超长且互相非整齐的周期来营造自然感，
// 强行对齐 AppMotion 令牌会破坏视觉效果。
//
// 豁免规则参见 CLAUDE.md §9.14 "动效令牌强约束"。所有自绘动画组件必须：
//   1. 文件顶部首行（package 导入之后）声明 `// MOTION_EXEMPT: self-painted` 标记
//   2. 紧随其后用 2-5 行说明：动画清单 + 周期数值 + 豁免理由
// 没有标记的文件，AppMotion 强约束依然适用。
//
// 当前豁免范围参考 lib/ui/spaces/（沉浸式空间）。
//
// 文件位置约束：feature 私有自绘组件保留在 features/{domain}/presentation/widgets/，
// 不强制迁移到 lib/ui/scenes/，避免破坏 feature 隔离。

bool get isRunningWidgetTest {
  return const bool.fromEnvironment('FLUTTER_TEST', defaultValue: false);
}

/// 平静波浪动画 — 黑胶唱片背景
class CalmWavePainterWidget extends StatefulWidget {
  const CalmWavePainterWidget({super.key, required this.color});

  final Color color;

  @override
  State<CalmWavePainterWidget> createState() => _CalmWavePainterWidgetState();
}

class _CalmWavePainterWidgetState extends State<CalmWavePainterWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    );
    if (!isRunningWidgetTest) {
      _controller.repeat();
    }
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
      builder: (context, _) => RepaintBoundary(
        child: CustomPaint(
          painter: CalmWavePainter(
            widget.color,
            _controller.value * pi * 2,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class CalmWavePainter extends CustomPainter {
  const CalmWavePainter(this.color, this.phase);

  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final glowPaint = Paint()
      ..color = color.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.1;
    for (var i = 0; i < 9; i++) {
      final path = Path();
      final y = 38.0 + i * 18 + sin(phase + i * .52) * 2.4;
      path.moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 14) {
        final drift = sin(x / 34 + phase * 1.28 + i * .62) * 5.2;
        final undertow = sin(x / 92 - phase * .72 + i * .9) * 2.4;
        path.lineTo(x, y + drift + undertow);
      }
      if (path.getBounds().right < size.width) {
        final x = size.width;
        final drift = sin(x / 34 + phase * 1.28 + i * .62) * 5.2;
        final undertow = sin(x / 92 - phase * .72 + i * .9) * 2.4;
        path.lineTo(x, y + drift + undertow);
      }
      if (i == 2 || i == 5) canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CalmWavePainter old) {
    return old.color != color || old.phase != phase;
  }
}

/// 黑胶唱片光源 — 可播放音频的旋转黑胶
class VinylLightSource extends StatefulWidget {
  const VinylLightSource({
    super.key,
    required this.size,
    required this.moodColor,
    required this.nightMode,
    required this.audioAsset,
  });

  final double size;
  final Color moodColor;
  final bool nightMode;
  final String audioAsset;

  @override
  State<VinylLightSource> createState() => _VinylLightSourceState();
}

class _VinylLightSourceState extends State<VinylLightSource>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _needleController;
  AudioPlayer? _player;
  String? _loadedAsset;
  bool _playing = false;
  bool _playerInitialized = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _needleController.value = 1;
  }

  Future<void> _ensurePlayer() async {
    if (_playerInitialized) return;
    _playerInitialized = true;
    _player = AudioPlayer();
    await _player!.setLoopMode(LoopMode.one);
    await _player!.setAsset(widget.audioAsset);
    _loadedAsset = widget.audioAsset;
  }

  @override
  void didUpdateWidget(covariant VinylLightSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioAsset != widget.audioAsset) {
      unawaited(_switchAudioAsset(resume: _playing));
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    _rotationController.dispose();
    _needleController.dispose();
    super.dispose();
  }

  Future<void> _ensureAudioAsset(String asset) async {
    final player = _player;
    if (player == null || _loadedAsset == asset) return;
    await player.setAsset(asset);
    _loadedAsset = asset;
  }

  Future<void> _switchAudioAsset({required bool resume}) async {
    try {
      await _ensureAudioAsset(widget.audioAsset);
      if (!mounted || !_playing || !resume) return;
      await _player?.play();
    } catch (_) {
      if (!mounted || !resume) return;
      _pauseVisualPlayback();
    }
  }

  Future<void> _togglePlayback() async {
    if (_playing) {
      _pauseVisualPlayback();
      try {
        await _player?.pause();
      } catch (_) {}
      return;
    }

    _playVisualPlayback();
    try {
      await _ensurePlayer();
      if (!mounted || !_playing) return;
      await _player?.play();
    } catch (_) {
      if (mounted) _pauseVisualPlayback();
    }
  }

  void _playVisualPlayback() {
    setState(() => _playing = true);
    _needleController.reverse();
    if (!isRunningWidgetTest) {
      _rotationController.repeat();
    }
  }

  void _pauseVisualPlayback() {
    setState(() => _playing = false);
    _needleController.forward();
    _rotationController.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _playing ? '暂停黑胶' : '播放黑胶',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePlayback,
        child: AnimatedBuilder(
          animation: Listenable.merge([_rotationController, _needleController]),
          builder: (context, _) => SizedBox(
            width: widget.size,
            height: widget.size,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: VinylLightPainter(
                  phase: _rotationController.value * pi * 2,
                  needleLift: _needleController.value,
                  moodColor: widget.moodColor,
                  nightMode: widget.nightMode,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VinylLightPainter extends CustomPainter {
  VinylLightPainter({
    required this.phase,
    required this.needleLift,
    required this.moodColor,
    required this.nightMode,
  });

  final double phase;
  final double needleLift;
  final Color moodColor;
  final bool nightMode;

  // H1: Cache Paint objects that don't change per frame
  static final _outerStrokePaint = Paint()
    ..color = AppColors.white.withValues(alpha: .24)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  static final _groovePaint = Paint()
    ..color = AppColors.white.withValues(alpha: .18)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  static final _shinePaint = Paint()
    ..color = AppColors.white.withValues(alpha: .22)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  static final _centerWhitePaint = Paint()
    ..color = AppColors.white.withValues(alpha: .88);
  static final _toneArmPaint = Paint()
    ..color = AppColors.ink.withValues(alpha: .92)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round;
  static final _armDotPaint = Paint()..color = AppColors.ink;
  static final _needleShadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: .12)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.4
    ..strokeCap = StrokeCap.round;

  // H1: Cache shader paints keyed by (moodColor, nightMode, canvasSize)
  static Color? _lastOuterColor1;
  static Paint? _cachedOuterPaint;
  static Rect? _lastOuterRect;
  static Color? _lastDiscColor1;
  static Paint? _cachedDiscPaint;
  static Rect? _lastDiscRect;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final outerRadius = radius * .84;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(phase);
    final outerRect = Rect.fromCircle(center: Offset.zero, radius: outerRadius);

    // H1: Reuse outer circle shader paint when colors haven't changed
    if (_lastOuterColor1 != moodColor ||
        _lastOuterRect != outerRect ||
        _cachedOuterPaint == null) {
      _lastOuterColor1 = moodColor;
      _lastOuterRect = outerRect;
      _cachedOuterPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.nightCardDark.withValues(alpha: .98),
            AppColors.nightCardMid.withValues(alpha: .96),
            AppColors.nightCardLight.withValues(alpha: .82),
          ],
          stops: const [0, .68, 1],
        ).createShader(outerRect);
    }
    canvas.drawCircle(Offset.zero, outerRadius, _cachedOuterPaint!);
    canvas.drawCircle(Offset.zero, outerRadius, _outerStrokePaint);

    final discRect = Rect.fromCircle(center: Offset.zero, radius: radius * .61);
    // H1: Reuse disc shader paint
    if (_lastDiscColor1 != moodColor ||
        _lastDiscRect != discRect ||
        _cachedDiscPaint == null) {
      _lastDiscColor1 = moodColor;
      _lastDiscRect = discRect;
      _cachedDiscPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.nightVinylDark.withValues(alpha: .95),
            AppColors.nightVinylMid.withValues(alpha: .92),
            AppColors.ink.withValues(alpha: .88),
          ],
        ).createShader(discRect);
    }
    canvas.drawCircle(Offset.zero, radius * .61, _cachedDiscPaint!);
    for (final r in [.28, .39, .50, .61, .72, .82]) {
      canvas.drawCircle(Offset.zero, radius * r, _groovePaint);
    }
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius * .46),
      -1.1,
      .58,
      false,
      _shinePaint,
    );
    canvas.restore();

    canvas.drawCircle(center, radius * .20, _centerWhitePaint);
    // Center mood dot — color changes with moodColor, use inline paint
    canvas.drawCircle(
      center,
      radius * .07,
      Paint()..color = moodColor.withValues(alpha: .78),
    );
    final armStart = Offset(size.width * .83, size.height * .14);
    final armEndOnDisc = Offset(size.width * .72, size.height * .78);
    final armEndResting = Offset(size.width * .91, size.height * .42);
    final armEnd = Offset.lerp(armEndOnDisc, armEndResting, needleLift)!;
    final needleEndOnDisc = Offset(size.width * .66, size.height * .88);
    final needleEndResting = Offset(size.width * .96, size.height * .48);
    final needleEnd =
        Offset.lerp(needleEndOnDisc, needleEndResting, needleLift)!;
    if (needleLift > 0) {
      _needleShadowPaint.color =
          Colors.black.withValues(alpha: .12 * needleLift);
      canvas.drawLine(
        armStart.translate(1.8, 2.4),
        armEnd.translate(1.8, 2.4),
        _needleShadowPaint,
      );
    }
    canvas.drawLine(armStart, armEnd, _toneArmPaint);
    canvas.drawCircle(armStart, 5, _armDotPaint);
    canvas.drawCircle(armEnd, 5, _armDotPaint);
    canvas.drawLine(armEnd, needleEnd, _toneArmPaint);
  }

  @override
  bool shouldRepaint(covariant VinylLightPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.needleLift != needleLift ||
        oldDelegate.moodColor != moodColor ||
        oldDelegate.nightMode != nightMode;
  }
}

/// 音乐轨迹动画 — 黑胶唱片旁边的音符飘动
class AnimatedMusicTrail extends StatefulWidget {
  const AnimatedMusicTrail({
    super.key,
    required this.compact,
    required this.color,
  });

  final bool compact;
  final Color color;

  @override
  State<AnimatedMusicTrail> createState() => _AnimatedMusicTrailState();
}

class _AnimatedMusicTrailState extends State<AnimatedMusicTrail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    );
    if (!isRunningWidgetTest) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => RepaintBoundary(
          child: CustomPaint(
            painter: MusicTrailPainter(
              compact: widget.compact,
              color: widget.color,
              phase: _controller.value,
            ),
          ),
        ),
      ),
    );
  }
}

class MusicTrailPainter extends CustomPainter {
  const MusicTrailPainter({
    required this.compact,
    required this.color,
    required this.phase,
  });

  final bool compact;
  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width * .52, size.height * .79);
    final control = Offset(size.width * .72, size.height * .93);
    final end = Offset(size.width * .91, size.height * .69);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: compact ? 0.08 : 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1.2 : 1.6
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < 5; i++) {
      final t = (phase + i * .18) % 1.0;
      final point = _quadratic(start, control, end, t);
      final lift = sin(t * pi) * (compact ? 18 : 26);
      final alpha = sin(t * pi).clamp(.0, 1.0);
      _drawNote(
        canvas,
        size,
        Offset(point.dx, point.dy - lift),
        i,
        alpha,
        compact ? .82 : 1,
      );
    }
  }

  Offset _quadratic(Offset a, Offset b, Offset c, double t) {
    final mt = 1 - t;
    return Offset(
      mt * mt * a.dx + 2 * mt * t * b.dx + t * t * c.dx,
      mt * mt * a.dy + 2 * mt * t * b.dy + t * t * c.dy,
    );
  }

  void _drawNote(Canvas canvas, Size size, Offset p, int index, double alpha,
      double scale) {
    final noteColor = index.isEven ? AppColors.ink : color;
    final margin = 18 * scale;
    final point = Offset(
      p.dx.clamp(margin, size.width - margin).toDouble(),
      p.dy.clamp(margin + 18 * scale, size.height - margin).toDouble(),
    );
    final fill = Paint()
      ..color = noteColor.withValues(alpha: .35 + alpha * .55)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = noteColor.withValues(alpha: .35 + alpha * .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;
    final head = Rect.fromCenter(
      center: point,
      width: 9.6 * scale,
      height: 7.2 * scale,
    );
    canvas.drawOval(head, fill);

    final stemBottom = Offset(point.dx + 4 * scale, point.dy - 1 * scale);
    final stemTop = Offset(point.dx + 4 * scale, point.dy - 22 * scale);
    canvas.drawLine(stemBottom, stemTop, stroke);

    final flagPath = Path()
      ..moveTo(stemTop.dx, stemTop.dy)
      ..cubicTo(
        stemTop.dx + 8 * scale,
        stemTop.dy + 1.5 * scale,
        stemTop.dx + 12 * scale,
        stemTop.dy + 7 * scale,
        stemTop.dx + 6 * scale,
        stemTop.dy + 11 * scale,
      );
    canvas.drawPath(flagPath, stroke);

    if (index == 2 || index == 4) {
      final lowerFlag = Path()
        ..moveTo(stemTop.dx, stemTop.dy + 6 * scale)
        ..cubicTo(
          stemTop.dx + 7 * scale,
          stemTop.dy + 7 * scale,
          stemTop.dx + 10 * scale,
          stemTop.dy + 12 * scale,
          stemTop.dx + 5 * scale,
          stemTop.dy + 15 * scale,
        );
      canvas.drawPath(lowerFlag, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant MusicTrailPainter oldDelegate) {
    return oldDelegate.compact != compact ||
        oldDelegate.color != color ||
        oldDelegate.phase != phase;
  }
}
