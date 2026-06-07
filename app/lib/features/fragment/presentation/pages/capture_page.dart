import 'dart:io' show Platform;

import 'dart:math';
import 'dart:convert';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/emotion_picker.dart';
import '../../../../ui/composites/night_mode_button.dart';
import '../../../../ui/spaces/space_canvas.dart';
import 'audio_capture_file_stub.dart'
    if (dart.library.io) 'audio_capture_file_io.dart';
import 'image_attachment_picker.dart';

bool _isDesktopPlatform() =>
    !kIsWeb &&
    (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// 捕光页 — 首页，快速记录入口
///
/// "今天有什么光落下来吗？"
class CapturePage extends ConsumerWidget {
  const CapturePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _CapturePageBody();
  }
}

class _CapturePageBody extends ConsumerStatefulWidget {
  const _CapturePageBody();

  @override
  ConsumerState<_CapturePageBody> createState() => _CapturePageBodyState();
}

class _CapturePageBodyState extends ConsumerState<_CapturePageBody> {
  String _emotion = '说不清';
  String _customEmotion = '';

  @override
  Widget build(BuildContext context) {
    final nightMode = ref.watch(nightModeProvider);
    final moodColor = AppColors.emotionColor(_effectiveEmotion);
    final vinylAudioAsset = _vinylAudioForEmotion(_effectiveEmotion);
    final isActive = ref.watch(activeTabIndexProvider) == 0;
    return _XiguangPage(
      moodColor: moodColor,
      nightMode: nightMode,
      child: TickerMode(
        enabled: isActive,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(
            label: 'GAP OF LIGHT',
            title: '隙',
            subtitle: '不用解释，也不用整理。先把这一束光轻轻放下。',
            nightMode: nightMode,
          ),
          const SizedBox(height: 12),
          _BreathingLightBanner(
            moodColor: moodColor,
            nightMode: nightMode,
            audioAsset: vinylAudioAsset,
          ),
          const SizedBox(height: 14),
          _QuickRecordComposer(
            selectedEmotion: _emotion,
            customEmotion: _customEmotion,
            onEmotionChanged: (emotion) => setState(() => _emotion = emotion),
            onCustomEmotionChanged: (value) =>
                setState(() => _customEmotion = value),
          ),
        ],
      ),
    ),
    );
  }

  String get _effectiveEmotion {
    if (_emotion == '自定义' && _customEmotion.trim().isNotEmpty) {
      return _customEmotion.trim();
    }
    return _emotion == '自定义' ? '说不清' : _emotion;
  }
}

String _vinylAudioForEmotion(String emotion) {
  return switch (emotion) {
    '开心' || '被击中' || '混乱' => 'assets/audio/Light music 律动欢快.m4a',
    '失落' => 'assets/audio/haoyvnlai(1).m4a',
    _ => 'assets/audio/Light music 舒缓.m4a',
  };
}

// --- Shared widgets (moved from original main.dart) ---

class _XiguangPage extends StatelessWidget {
  const _XiguangPage({
    required this.child,
    required this.moodColor,
    required this.nightMode,
  });

  final Widget child;
  final Color moodColor;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final hp = constraints.maxWidth > 520 ? 34.0 : 16.0;
      return Stack(children: [
        const Positioned.fill(child: AtmosphereBackground()),
        Positioned.fill(
          child: _MoodBackground(moodColor: moodColor, nightMode: nightMode),
        ),
        SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hp, 18, hp, 104),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}

class _MoodBackground extends StatelessWidget {
  const _MoodBackground({
    required this.moodColor,
    required this.nightMode,
  });

  final Color moodColor;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _MoodBackgroundPainter(moodColor, nightMode),
      ),
    );
  }
}

class _MoodBackgroundPainter extends CustomPainter {
  const _MoodBackgroundPainter(this.moodColor, this.nightMode);

  final Color moodColor;
  final bool nightMode;

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: nightMode
            ? [
                const Color(0xFF172625).withValues(alpha: .34),
                moodColor.withValues(alpha: .13),
                Colors.transparent,
              ]
            : [
                moodColor.withValues(alpha: .14),
                AppColors.white.withValues(alpha: .10),
                AppColors.emotionHappy.withValues(alpha: .07),
              ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final linePaint = Paint()
      ..color = moodColor.withValues(alpha: nightMode ? .17 : .11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 7; i++) {
      final y = size.height * (.18 + i * .115);
      final path = Path()..moveTo(-26, y);
      path.cubicTo(
        size.width * .26,
        y + sin(i * .8) * 22,
        size.width * .66,
        y - 24,
        size.width + 28,
        y + 8,
      );
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MoodBackgroundPainter oldDelegate) {
    return oldDelegate.moodColor != moodColor ||
        oldDelegate.nightMode != nightMode;
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.nightMode,
  });

  final String label;
  final String title;
  final String subtitle;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppText.onNight(AppText.eyebrow, nightMode)),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(
          child: Text(title, style: AppText.onNight(AppText.hero, nightMode)),
        ),
        const NightModeButton(),
      ]),
      const SizedBox(height: 4),
      Text(subtitle, style: AppText.onNight(AppText.body, nightMode)),
    ]);
  }
}

class _BreathingLightBanner extends StatelessWidget {
  const _BreathingLightBanner({
    required this.moodColor,
    required this.nightMode,
    required this.audioAsset,
  });

  final Color moodColor;
  final bool nightMode;
  final String audioAsset;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Container(
      height: compact ? 154 : 204,
      decoration: softDecoration(AppColors.ink).copyWith(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: nightMode
              ? [
                  const Color(0xFF172625),
                  AppColors.ink,
                  moodColor.withValues(alpha: .7),
                ]
              : [
                  AppColors.ink,
                  moodColor.withValues(alpha: .82),
                  AppColors.emotionHappy.withValues(alpha: .72),
                ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(children: [
          Positioned.fill(child: _CalmWavePainterWidget(color: moodColor)),
          Positioned(
              left: 20,
              right: compact ? 116 : 164,
              top: compact ? 18 : 26,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '留下一束光',
                      style: AppText.inverseTitle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nightMode ? '夜间轻开：慢一点放下。' : '沿着今天的节律，轻轻落下。',
                      style: AppText.inverseBody,
                    ),
                  ])),
          Positioned(
            right: compact ? 15 : 28,
            top: compact ? 18 : 28,
            child: _VinylLightSource(
              size: compact ? 96 : 124,
              moodColor: moodColor,
              nightMode: nightMode,
              audioAsset: audioAsset,
            ),
          ),
          Positioned.fill(
            child: _AnimatedMusicTrail(
              compact: compact,
              color: moodColor,
            ),
          ),
        ]),
      ),
    );
  }
}

class _CalmWavePainterWidget extends StatefulWidget {
  const _CalmWavePainterWidget({required this.color});

  final Color color;

  @override
  State<_CalmWavePainterWidget> createState() => _CalmWavePainterWidgetState();
}

class _CalmWavePainterWidgetState extends State<_CalmWavePainterWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    );
    if (!_isRunningWidgetTest) {
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
      builder: (context, _) => CustomPaint(
        painter: _CalmWavePainter(
          widget.color,
          _controller.value * pi * 2,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CalmWavePainter extends CustomPainter {
  const _CalmWavePainter(this.color, this.phase);

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
  bool shouldRepaint(covariant _CalmWavePainter old) {
    return old.color != color || old.phase != phase;
  }
}

class _VinylLightSource extends StatefulWidget {
  const _VinylLightSource({
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
  State<_VinylLightSource> createState() => _VinylLightSourceState();
}

class _VinylLightSourceState extends State<_VinylLightSource>
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
  void didUpdateWidget(covariant _VinylLightSource oldWidget) {
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
    if (!_isRunningWidgetTest) {
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
            child: CustomPaint(
              painter: _VinylLightPainter(
                phase: _rotationController.value * pi * 2,
                needleLift: _needleController.value,
                moodColor: widget.moodColor,
                nightMode: widget.nightMode,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VinylLightPainter extends CustomPainter {
  const _VinylLightPainter({
    required this.phase,
    required this.needleLift,
    required this.moodColor,
    required this.nightMode,
  });

  final double phase;
  final double needleLift;
  final Color moodColor;
  final bool nightMode;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final outerRadius = radius * .84;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(phase);
    final outerRect = Rect.fromCircle(center: Offset.zero, radius: outerRadius);
    canvas.drawCircle(
      Offset.zero,
      outerRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF0F1D1B).withValues(alpha: .98),
            const Color(0xFF263936).withValues(alpha: .96),
            const Color(0xFF52615C).withValues(alpha: .82),
          ],
          stops: const [0, .68, 1],
        ).createShader(outerRect),
    );
    canvas.drawCircle(
      Offset.zero,
      outerRadius,
      Paint()
        ..color = AppColors.white.withValues(alpha: .24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    final discRect = Rect.fromCircle(center: Offset.zero, radius: radius * .61);
    canvas.drawCircle(
      Offset.zero,
      radius * .61,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF162422).withValues(alpha: .95),
            const Color(0xFF31413D).withValues(alpha: .92),
            AppColors.ink.withValues(alpha: .88),
          ],
        ).createShader(discRect),
    );
    final groove = Paint()
      ..color = AppColors.white.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in [.28, .39, .50, .61, .72, .82]) {
      canvas.drawCircle(Offset.zero, radius * r, groove);
    }
    final shine = Paint()
      ..color = AppColors.white.withValues(alpha: .22)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius * .46),
      -1.1,
      .58,
      false,
      shine,
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      radius * .20,
      Paint()..color = AppColors.white.withValues(alpha: .88),
    );
    canvas.drawCircle(
      center,
      radius * .07,
      Paint()..color = moodColor.withValues(alpha: .78),
    );
    final toneArm = Paint()
      ..color = AppColors.ink.withValues(alpha: .92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final armStart = Offset(size.width * .83, size.height * .14);
    final armEndOnDisc = Offset(size.width * .72, size.height * .78);
    final armEndResting = Offset(size.width * .91, size.height * .42);
    final armEnd = Offset.lerp(armEndOnDisc, armEndResting, needleLift)!;
    final needleEndOnDisc = Offset(size.width * .66, size.height * .88);
    final needleEndResting = Offset(size.width * .96, size.height * .48);
    final needleEnd =
        Offset.lerp(needleEndOnDisc, needleEndResting, needleLift)!;
    final liftedShadow = Paint()
      ..color = Colors.black.withValues(alpha: .12 * needleLift)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.4
      ..strokeCap = StrokeCap.round;
    if (needleLift > 0) {
      canvas.drawLine(
        armStart.translate(1.8, 2.4),
        armEnd.translate(1.8, 2.4),
        liftedShadow,
      );
    }
    canvas.drawLine(armStart, armEnd, toneArm);
    canvas.drawCircle(armStart, 5, Paint()..color = AppColors.ink);
    canvas.drawCircle(armEnd, 5, Paint()..color = AppColors.ink);
    canvas.drawLine(armEnd, needleEnd, toneArm);
  }

  @override
  bool shouldRepaint(covariant _VinylLightPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.needleLift != needleLift ||
        oldDelegate.moodColor != moodColor ||
        oldDelegate.nightMode != nightMode;
  }
}

class _AnimatedMusicTrail extends StatefulWidget {
  const _AnimatedMusicTrail({
    required this.compact,
    required this.color,
  });

  final bool compact;
  final Color color;

  @override
  State<_AnimatedMusicTrail> createState() => _AnimatedMusicTrailState();
}

class _AnimatedMusicTrailState extends State<_AnimatedMusicTrail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    );
    if (!_isRunningWidgetTest) {
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
        builder: (context, _) => CustomPaint(
          painter: _MusicTrailPainter(
            compact: widget.compact,
            color: widget.color,
            phase: _controller.value,
          ),
        ),
      ),
    );
  }
}

class _MusicTrailPainter extends CustomPainter {
  const _MusicTrailPainter({
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
  bool shouldRepaint(covariant _MusicTrailPainter oldDelegate) {
    return oldDelegate.compact != compact ||
        oldDelegate.color != color ||
        oldDelegate.phase != phase;
  }
}

bool get _isRunningWidgetTest {
  return WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');
}

class _QuickRecordComposer extends ConsumerStatefulWidget {
  const _QuickRecordComposer({
    required this.selectedEmotion,
    required this.customEmotion,
    required this.onEmotionChanged,
    required this.onCustomEmotionChanged,
  });

  final String selectedEmotion;
  final String customEmotion;
  final ValueChanged<String> onEmotionChanged;
  final ValueChanged<String> onCustomEmotionChanged;

  @override
  ConsumerState<_QuickRecordComposer> createState() =>
      _QuickRecordComposerState();
}

class _QuickRecordComposerState extends ConsumerState<_QuickRecordComposer> {
  static const _draftTextKey = 'capture_draft_text';
  static const _draftEmotionKey = 'capture_draft_emotion';
  static const _draftCustomEmotionKey = 'capture_draft_custom_emotion';

  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final _attachmentRecorder = AudioRecorder();
  final List<XFile> _images = [];
  Timer? _draftTimer;
  Timer? _audioTimer;
  bool _recordingAudio = false;
  int _audioSeconds = 0;
  String? _audioPath;
  bool _saving = false;
  bool _restoredDraft = false;
  bool _draftSaved = false;
  bool _suppressDraftSave = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleDraftInputChanged);
    _restoreDraft();
  }

  @override
  void didUpdateWidget(covariant _QuickRecordComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedEmotion != widget.selectedEmotion ||
        oldWidget.customEmotion != widget.customEmotion) {
      _scheduleDraftSave();
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _audioTimer?.cancel();
    unawaited(_attachmentRecorder.dispose());
    _controller.removeListener(_handleDraftInputChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 18,
        compact ? 14 : 20,
        compact ? 14 : 18,
        compact ? 14 : 18,
      ),
      decoration: softDecoration(AppColors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('把这一瞬间放在这里', style: AppText.titleMedium),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _draftSaved || _restoredDraft
              ? Padding(
                  key: ValueKey('draft-${_draftSaved ? 'saved' : 'restored'}'),
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Icon(
                      _draftSaved
                          ? Icons.check_circle_outline_rounded
                          : Icons.history_rounded,
                      size: 15,
                      color: AppColors.teaGreen,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _draftSaved ? '已轻轻存下草稿' : '已找回上次没写完的光',
                      style: AppText.caption,
                    ),
                  ]),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 10),
        Container(
          constraints: BoxConstraints(minHeight: compact ? 104 : 144),
          decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line)),
          child: TextField(
            key: const ValueKey('capture-content'),
            controller: _controller,
            minLines: compact ? 3 : 6,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '今天发生了什么？',
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ComposerMetaRow(
          writtenCount: _writtenCount,
          hasDraft: _hasDraftLikeContent,
          draftSaved: _draftSaved,
          restoredDraft: _restoredDraft,
          onClearDraft: _saving ? null : _clearCurrentDraft,
        ),
        const SizedBox(height: 14),
        EmotionPicker(
            selected: widget.selectedEmotion,
            customValue: widget.customEmotion,
            onCustomChanged: widget.onCustomEmotionChanged,
            onSelected: (e) => widget.onEmotionChanged(e)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.wb_sunny_outlined),
            label: Text(_saving ? '落下中' : '捕光'),
          ),
        ),
        const SizedBox(height: 12),
        _AttachmentBar(
          imageCount: _images.length,
          hasAudioCue: _audioSeconds > 0,
          recordingAudio: _recordingAudio,
          saving: _saving,
          onPickImages: _pickImages,
          onToggleAudio: _toggleAudio,
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final image = _images[index];
                return Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _SelectedImagePreview(
                      image: image,
                      width: 76,
                      height: 76,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: IconButton.filledTonal(
                      constraints:
                          const BoxConstraints.tightFor(width: 28, height: 28),
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      onPressed: () => setState(() => _images.removeAt(index)),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ],
        if (_recordingAudio || _audioSeconds > 0) ...[
          const SizedBox(height: 10),
          _AudioCuePreview(
            seconds: _audioSeconds,
            recording: _recordingAudio,
            onStop: _recordingAudio ? () => unawaited(_stopAudio()) : null,
            onRemove: () => unawaited(_clearAudio()),
          ),
        ],
      ]),
    );
  }

  Future<void> _pickImages() async {
    try {
      final picked = await pickImageAttachments(
        context: context,
        picker: _picker,
        limit: 6,
      );
      if (picked.isEmpty) return;
      setState(() {
        _images
          ..clear()
          ..addAll(picked.take(6));
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂时无法打开图片选择。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('至少留下一句话。'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _saving = true);
    final mediaUrls = await _mediaUrlsForSave();
    if (!mounted) return;
    try {
      await ref.read(fragmentsProvider.notifier).captureWithResult(
            text: text,
            emotion: _emotionForSave(),
            tags: const [],
            mediaUrls: mediaUrls,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('暂时无法保存这束光，请稍后再试。'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _recordingAudio = false;
      _audioSeconds = 0;
      _audioPath = null;
      _draftSaved = false;
      _restoredDraft = false;
    });
    _audioTimer?.cancel();
    _draftTimer?.cancel();
    _suppressDraftSave = true;
    try {
      await _clearDraft();
      if (!mounted) return;
      _controller.clear();
      _images.clear();
    } finally {
      _suppressDraftSave = false;
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('这束光已经轻轻放好了。'), behavior: SnackBarBehavior.floating),
    );
  }

  static const _maxInlineImageBytes = 2 * 1024 * 1024; // 2MB per image for inline base64

  Future<List<String>> _mediaUrlsForSave() async {
    final urls = <String>[];
    if (!kIsWeb) {
      urls.addAll(_images.map((image) => image.path));
    } else {
      for (final image in _images) {
        final bytes = await image.readAsBytes();
        if (bytes.length > _maxInlineImageBytes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('图片过大 (${(bytes.length / 1024 / 1024).toStringAsFixed(1)}MB)，请使用小于2MB的图片。'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          continue;
        }
        urls.add('data:${_mimeType(image)};base64,${base64Encode(bytes)}');
      }
    }
    final audioUrl = await _audioUrlForSave();
    if (audioUrl != null) {
      urls.add(audioUrl);
    }
    return urls;
  }

  Future<String?> _audioUrlForSave() async {
    if (_recordingAudio) {
      await _stopAudio();
    }
    final path = _audioPath;
    if (path == null || _audioSeconds <= 0) return null;
    final url = await audioPathToDataUrl(path, _audioMimeForPath(path));
    if (url == null) {
      throw StateError('audio_capture_missing');
    }
    return url;
  }

  String _audioMimeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.opus')) return 'audio/opus';
    return 'audio/mp4';
  }

  int get _writtenCount => _controller.text.trim().runes.length;

  bool get _hasDraftLikeContent {
    return _controller.text.trim().isNotEmpty ||
        _images.isNotEmpty ||
        _audioSeconds > 0 ||
        widget.selectedEmotion != '说不清' ||
        widget.customEmotion.trim().isNotEmpty;
  }

  void _handleDraftInputChanged() {
    if (_suppressDraftSave) return;
    if (mounted) setState(() {});
    _scheduleDraftSave();
  }

  Future<void> _toggleAudio() async {
    if (_isDesktopPlatform()) {
      await _pickAudioFile();
      return;
    }
    if (_recordingAudio) {
      await _stopAudio();
      return;
    }
    await _startAudio();
  }

  Future<void> _pickAudioFile() async {
    if (_audioPath != null) {
      _clearAudio();
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'opus'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;
      if (!mounted) return;
      final fileSize = file.size;
      setState(() {
        _audioPath = file.path!;
        _audioSeconds = fileSize > 0 ? (fileSize / 16000).ceil().clamp(1, 9999) : 1;
        _recordingAudio = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法选择音频文件。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _startAudio() async {
    try {
      final permissionGranted = await _ensureMicrophonePermission();
      if (!permissionGranted) {
        return;
      }
      final path = await nextAudioCapturePath();
      await _attachmentRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 64000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      _audioTimer?.cancel();
      setState(() {
        _recordingAudio = true;
        _audioSeconds = 0;
        _audioPath = path;
      });
      _audioTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _audioSeconds += 1);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂时无法开始录音。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _ensureMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    status = await Permission.microphone.request();
    if (status.isGranted) {
      return await _attachmentRecorder.hasPermission(request: false);
    }

    if (!mounted) return false;
    final permanentlyDenied = status.isPermanentlyDenied || status.isRestricted;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          permanentlyDenied ? '需要在系统设置中开启麦克风权限。' : '需要麦克风权限才能留下声音。',
        ),
        behavior: SnackBarBehavior.floating,
        action: permanentlyDenied
            ? SnackBarAction(
                label: '去设置',
                onPressed: () => unawaited(openAppSettings()),
              )
            : null,
      ),
    );
    return false;
  }

  Future<void> _stopAudio() async {
    _audioTimer?.cancel();
    String? path = _audioPath;
    try {
      path = await _attachmentRecorder.stop() ?? path;
    } catch (_) {
      // If the recorder was already stopped, keep the last known path.
    }
    if (!mounted) return;
    setState(() {
      _recordingAudio = false;
      if (_audioSeconds == 0) _audioSeconds = 1;
      _audioPath = path;
    });
  }

  Future<void> _clearAudio() async {
    _audioTimer?.cancel();
    if (_recordingAudio) {
      try {
        await _attachmentRecorder.cancel();
      } catch (_) {
        // Ignore recorder cleanup errors when clearing the draft.
      }
    }
    if (!mounted) return;
    setState(() {
      _recordingAudio = false;
      _audioSeconds = 0;
      _audioPath = null;
    });
  }

  Future<void> _clearCurrentDraft() async {
    _draftTimer?.cancel();
    _audioTimer?.cancel();
    _suppressDraftSave = true;
    setState(() {
      _controller.clear();
      _images.clear();
      _recordingAudio = false;
      _audioSeconds = 0;
      _audioPath = null;
      _draftSaved = false;
      _restoredDraft = false;
    });
    widget.onEmotionChanged('说不清');
    widget.onCustomEmotionChanged('');
    await _clearDraft();
    if (!mounted) return;
    _suppressDraftSave = false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('草稿已经轻轻清空。'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _mimeType(XFile image) {
    final mime = image.mimeType;
    if (mime != null && mime.startsWith('image/')) return mime;
    final name = image.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _emotionForSave() {
    if (widget.selectedEmotion == '自定义' &&
        widget.customEmotion.trim().isNotEmpty) {
      return widget.customEmotion.trim();
    }
    return widget.selectedEmotion == '自定义' ? '说不清' : widget.selectedEmotion;
  }

  void _scheduleDraftSave() {
    if (_suppressDraftSave) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 420), () {
      if (!mounted || _saving) return;
      unawaited(_saveDraft());
    });
  }

  Future<void> _saveDraft() async {
    final text = _controller.text;
    final hasDraft = text.trim().isNotEmpty ||
        widget.selectedEmotion != '说不清' ||
        widget.customEmotion.trim().isNotEmpty;
    final prefs = await SharedPreferences.getInstance();
    if (!hasDraft) {
      await _clearDraft();
      if (mounted) {
        setState(() {
          _draftSaved = false;
          _restoredDraft = false;
        });
      }
      return;
    }
    await prefs.setString(_draftTextKey, text);
    await prefs.setString(_draftEmotionKey, widget.selectedEmotion);
    await prefs.setString(_draftCustomEmotionKey, widget.customEmotion);
    if (mounted) {
      setState(() {
        if (!_restoredDraft) {
          _draftSaved = true;
        }
      });
    }
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_draftTextKey) ?? '';
    final emotion = prefs.getString(_draftEmotionKey);
    final customEmotion = prefs.getString(_draftCustomEmotionKey) ?? '';
    final hasDraft = text.trim().isNotEmpty ||
        (emotion != null && emotion != '说不清') ||
        customEmotion.trim().isNotEmpty;
    if (!mounted || !hasDraft) return;
    _suppressDraftSave = true;
    try {
      _controller.text = text;
      if (emotion != null && emotion.isNotEmpty) {
        widget.onEmotionChanged(emotion);
      }
      if (customEmotion.isNotEmpty) {
        widget.onCustomEmotionChanged(customEmotion);
      }
      setState(() {
        _restoredDraft = true;
        _draftSaved = false;
      });
    } finally {
      _suppressDraftSave = false;
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftTextKey);
    await prefs.remove(_draftEmotionKey);
    await prefs.remove(_draftCustomEmotionKey);
  }
}

class _ComposerMetaRow extends StatelessWidget {
  const _ComposerMetaRow({
    required this.writtenCount,
    required this.hasDraft,
    required this.draftSaved,
    required this.restoredDraft,
    required this.onClearDraft,
  });

  final int writtenCount;
  final bool hasDraft;
  final bool draftSaved;
  final bool restoredDraft;
  final VoidCallback? onClearDraft;

  @override
  Widget build(BuildContext context) {
    final statusSuffix = draftSaved
        ? ' · 草稿已存'
        : restoredDraft
            ? ' · 上次的光已找回'
            : '';
    final status = '已写 $writtenCount 字$statusSuffix';
    return Row(children: [
      Icon(
        writtenCount == 0 ? Icons.edit_note_rounded : Icons.auto_awesome,
        size: 15,
        color: AppColors.teaGreen,
      ),
      const SizedBox(width: 5),
      Expanded(child: Text(status, style: AppText.caption)),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: hasDraft
            ? TextButton.icon(
                key: const ValueKey('clear-capture-draft'),
                onPressed: onClearDraft,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.inkMuted,
                ),
                icon: const Icon(Icons.cleaning_services_outlined, size: 14),
                label: const Text('清空草稿'),
              )
            : const SizedBox.shrink(),
      ),
    ]);
  }
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({
    required this.image,
    required this.width,
    required this.height,
  });

  final XFile image;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: image.readAsBytes(),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return Container(
            width: width,
            height: height,
            color: AppColors.paper,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class _AttachmentBar extends StatelessWidget {
  const _AttachmentBar({
    required this.imageCount,
    required this.hasAudioCue,
    required this.recordingAudio,
    required this.saving,
    required this.onPickImages,
    required this.onToggleAudio,
  });

  final int imageCount;
  final bool hasAudioCue;
  final bool recordingAudio;
  final bool saving;
  final VoidCallback onPickImages;
  final VoidCallback onToggleAudio;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _AttachmentButton(
        icon: Icons.add_photo_alternate_outlined,
        label: imageCount == 0 ? '图片' : '$imageCount 张图片',
        active: imageCount > 0,
        enabled: !saving,
        onTap: onPickImages,
      ),
      const SizedBox(width: 12),
      _AttachmentButton(
        icon: recordingAudio ? Icons.stop_rounded : Icons.graphic_eq_rounded,
        label: recordingAudio
            ? '停止'
            : hasAudioCue
                ? '声音已贴近'
                : _isDesktopPlatform()
                    ? '选择音频'
                    : '音频',
        active: hasAudioCue || recordingAudio,
        enabled: !saving,
        onTap: onToggleAudio,
      ),
    ]);
  }
}

class _AttachmentButton extends StatelessWidget {
  const _AttachmentButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: active ? AppColors.white : AppColors.teaGreen,
          backgroundColor: active
              ? AppColors.teaGreen
              : AppColors.white.withValues(alpha: .6),
          side: BorderSide(
            color: active ? AppColors.teaGreen : AppColors.line,
          ),
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _AudioCuePreview extends StatelessWidget {
  const _AudioCuePreview({
    required this.seconds,
    required this.recording,
    required this.onRemove,
    this.onStop,
  });

  final int seconds;
  final bool recording;
  final VoidCallback onRemove;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.teaGreen.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.teaGreen.withValues(alpha: .24)),
      ),
      child: Row(children: [
        _AudioPulse(recording: recording),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            recording
                ? '正在贴近这一刻的声音 · ${_formatDuration(seconds)}'
                : '贴近这一刻的声音 · ${_formatDuration(seconds)}',
            style: AppText.bodyMuted,
          ),
        ),
        if (onStop != null)
          TextButton(
            onPressed: onStop,
            child: const Text('停下'),
          ),
        IconButton(
          tooltip: '移除音频',
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      ]),
    );
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _AudioPulse extends StatelessWidget {
  const _AudioPulse({required this.recording});

  final bool recording;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(painter: _AudioPulsePainter(recording)),
    );
  }
}

class _AudioPulsePainter extends CustomPainter {
  const _AudioPulsePainter(this.recording);

  final bool recording;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final paint = Paint()
      ..color = AppColors.teaGreen
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final bars = recording
        ? [8.0, 16.0, 12.0, 20.0, 10.0]
        : [8.0, 13.0, 18.0, 13.0, 8.0];
    for (var i = 0; i < bars.length; i++) {
      final x = 5.0 + i * 4.5;
      final h = bars[i];
      canvas.drawLine(
        Offset(x, centerY - h / 2),
        Offset(x, centerY + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AudioPulsePainter oldDelegate) {
    return oldDelegate.recording != recording;
  }
}
