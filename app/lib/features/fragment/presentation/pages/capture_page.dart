import 'dart:math';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../data/fragment_repository.dart';
import 'fragment_detail_page.dart';
import '../../../../ui/composites/emotion_picker.dart';
import '../../../../ui/composites/light_card.dart';
import '../../../../ui/composites/night_mode_button.dart';
import '../../../../ui/spaces/space_canvas.dart';

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
    final fragments = ref.watch(fragmentsProvider);
    final nightMode = ref.watch(nightModeProvider);
    final moodColor = AppColors.emotionColor(_effectiveEmotion);
    return _XiguangPage(
      moodColor: moodColor,
      nightMode: nightMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(
            label: 'GAP OF LIGHT',
            title: '隙',
            subtitle: '不用解释，也不用整理。先把这一束光轻轻放下。',
            nightMode: nightMode,
          ),
          const SizedBox(height: 22),
          _BreathingLightBanner(moodColor: moodColor, nightMode: nightMode),
          const SizedBox(height: 18),
          _QuickRecordComposer(
            selectedEmotion: _emotion,
            customEmotion: _customEmotion,
            onEmotionChanged: (emotion) => setState(() => _emotion = emotion),
            onCustomEmotionChanged: (value) =>
                setState(() => _customEmotion = value),
          ),
          const SizedBox(height: 30),
          _SectionTitle(
            title: '刚刚留下的光',
            action: fragments.when(
                data: (items) => '${items.length} 束光',
                loading: () => '读取中',
                error: (_, __) => '本地光片'),
            onTap: () => ref.read(fragmentsProvider.notifier).refresh(),
          ),
          const SizedBox(height: 16),
          fragments.when(
            data: (items) => Column(
                children: items
                    .take(3)
                    .map((f) => LightFragmentCard(
                          fragment: f.toLightFragment(),
                          compact: true,
                          onTap: () =>
                              Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              builder: (_) => FragmentDetailPage(id: '${f.id}'),
                            ),
                          ),
                        ))
                    .toList()),
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator())),
            error: (error, _) =>
                Text('这束光先留在本地：$error', style: AppText.caption),
          ),
        ],
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
      final hp = constraints.maxWidth > 520 ? 34.0 : 22.0;
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
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: Text(title, style: AppText.onNight(AppText.hero, nightMode)),
        ),
        const NightModeButton(),
      ]),
      const SizedBox(height: 8),
      Text(subtitle, style: AppText.onNight(AppText.body, nightMode)),
    ]);
  }
}

class _BreathingLightBanner extends StatelessWidget {
  const _BreathingLightBanner({
    required this.moodColor,
    required this.nightMode,
  });

  final Color moodColor;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Container(
      height: compact ? 158 : 210,
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
            right: compact ? 18 : 34,
            bottom: compact ? 16 : 24,
            child: _LightTrailNotes(compact: compact),
          ),
          Positioned(
              right: 28,
              top: compact ? 22 : 34,
              child: Container(
                width: compact ? 88 : 112,
                height: compact ? 88 : 112,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white.withValues(alpha: .18),
                    border: Border.all(
                        color: AppColors.white.withValues(alpha: .44),
                        width: 1.2)),
                child: Center(
                    child: Container(
                        width: compact ? 44 : 58,
                        height: compact ? 44 : 58,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.white.withValues(alpha: .7)))),
              )),
          Positioned(
              left: 20,
              right: compact ? 112 : 150,
              bottom: compact ? 14 : 22,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('留下一束光', style: AppText.inverseTitle),
                    const SizedBox(height: 8),
                    Text(
                      nightMode ? '夜间轻开：慢一点放下。' : '沿着今天的节律，轻轻落下。',
                      style: AppText.inverseBody,
                    ),
                  ])),
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

class _LightTrailNotes extends StatelessWidget {
  const _LightTrailNotes({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 120 : 160,
      height: compact ? 42 : 58,
      child: CustomPaint(painter: _LightTrailNotesPainter(compact: compact)),
    );
  }
}

class _LightTrailNotesPainter extends CustomPainter {
  const _LightTrailNotesPainter({required this.compact});

  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final trail = Paint()
      ..color = AppColors.white.withValues(alpha: .34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(4, size.height * .70)
      ..quadraticBezierTo(
        size.width * .38,
        size.height * .92,
        size.width * .72,
        size.height * .60,
      )
      ..quadraticBezierTo(
        size.width * .88,
        size.height * .44,
        size.width - 4,
        size.height * .50,
      );
    canvas.drawPath(path, trail);

    final notePaint = Paint()
      ..color = AppColors.ink.withValues(alpha: .84)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.ink.withValues(alpha: .84)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final notes = [
      Offset(size.width * .18, size.height * .70),
      Offset(size.width * .45, size.height * .63),
      Offset(size.width * .66, size.height * .52),
      Offset(size.width * .84, size.height * .40),
    ];
    for (var i = 0; i < notes.length; i++) {
      final p = notes[i];
      canvas.drawCircle(p, compact ? 3.4 : 4.2, notePaint);
      if (i.isOdd) {
        canvas.drawLine(
          Offset(p.dx + 3, p.dy),
          Offset(p.dx + 3, p.dy - (compact ? 16 : 20)),
          stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LightTrailNotesPainter oldDelegate) {
    return oldDelegate.compact != compact;
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
  static const _draftTagsKey = 'capture_draft_tags';
  static const _draftEmotionKey = 'capture_draft_emotion';
  static const _draftCustomEmotionKey = 'capture_draft_custom_emotion';

  final _controller = TextEditingController();
  final _tagController = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  Timer? _draftTimer;
  Timer? _audioTimer;
  bool _recordingAudio = false;
  int _audioSeconds = 0;
  bool _saving = false;
  bool _restoredDraft = false;
  bool _draftSaved = false;
  bool _suppressDraftSave = false;
  LightFragmentModel? _lastCreated;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleDraftInputChanged);
    _tagController.addListener(_handleDraftInputChanged);
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
    _controller.removeListener(_handleDraftInputChanged);
    _tagController.removeListener(_handleDraftInputChanged);
    _controller.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Container(
      padding: EdgeInsets.fromLTRB(18, compact ? 20 : 22, 18, 18),
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
        const SizedBox(height: 12),
        Container(
          constraints: BoxConstraints(minHeight: compact ? 132 : 150),
          decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line)),
          child: TextField(
            controller: _controller,
            minLines: compact ? 5 : 6,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '今天发生了什么？可以只写一句，也可以什么都不解释。',
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
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
        const SizedBox(height: 14),
        TextField(
          controller: _tagController,
          decoration: InputDecoration(
            hintText: '可选：给光命名，用空格分隔，例如：雨天 通勤 微光',
            prefixIcon: const Icon(Icons.tag_rounded),
            filled: true,
            fillColor: AppColors.white.withValues(alpha: .72),
          ),
        ),
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
            onStop: _recordingAudio ? _stopAudio : null,
            onRemove: _clearAudio,
          ),
        ],
        if (_lastCreated != null) ...[
          const SizedBox(height: 12),
          _FreshLightHint(fragment: _lastCreated!),
        ],
      ]),
    );
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(
        limit: 6,
        maxWidth: 960,
        maxHeight: 960,
        imageQuality: 76,
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
          content: Text('暂时无法打开相册。'),
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
    final tags = _tagController.text
        .split(RegExp(r'[\s,，#]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    setState(() => _saving = true);
    final mediaUrls = await _mediaUrlsForSave();
    if (!mounted) return;
    LightFragmentModel? created;
    try {
      created = await ref.read(fragmentsProvider.notifier).captureWithResult(
            text: text,
            emotion: _emotionForSave(),
            tags: tags,
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
      _lastCreated = created;
      _recordingAudio = false;
      _audioSeconds = 0;
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
      _tagController.clear();
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

  Future<List<String>> _mediaUrlsForSave() async {
    final urls = <String>[];
    if (!kIsWeb) {
      urls.addAll(_images.map((image) => image.path));
    } else {
      for (final image in _images) {
        final bytes = await image.readAsBytes();
        urls.add('data:${_mimeType(image)};base64,${base64Encode(bytes)}');
      }
    }
    if (_audioSeconds > 0) {
      urls.add('audio-cue://voice?duration=$_audioSeconds');
    }
    return urls;
  }

  int get _writtenCount => _controller.text.trim().runes.length;

  bool get _hasDraftLikeContent {
    return _controller.text.trim().isNotEmpty ||
        _tagController.text.trim().isNotEmpty ||
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

  void _toggleAudio() {
    if (_recordingAudio) {
      _stopAudio();
      return;
    }
    setState(() {
      _recordingAudio = true;
      if (_audioSeconds == 0) _audioSeconds = 1;
    });
    _audioTimer?.cancel();
    _audioTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _audioSeconds += 1);
    });
  }

  void _stopAudio() {
    _audioTimer?.cancel();
    setState(() {
      _recordingAudio = false;
      if (_audioSeconds == 0) _audioSeconds = 1;
    });
  }

  void _clearAudio() {
    _audioTimer?.cancel();
    setState(() {
      _recordingAudio = false;
      _audioSeconds = 0;
    });
  }

  Future<void> _clearCurrentDraft() async {
    _draftTimer?.cancel();
    _audioTimer?.cancel();
    _suppressDraftSave = true;
    setState(() {
      _controller.clear();
      _tagController.clear();
      _images.clear();
      _recordingAudio = false;
      _audioSeconds = 0;
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
    final tags = _tagController.text;
    final hasDraft = text.trim().isNotEmpty ||
        tags.trim().isNotEmpty ||
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
    await prefs.setString(_draftTagsKey, tags);
    await prefs.setString(_draftEmotionKey, widget.selectedEmotion);
    await prefs.setString(_draftCustomEmotionKey, widget.customEmotion);
    if (mounted) {
      setState(() {
        _draftSaved = true;
        _restoredDraft = false;
      });
    }
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_draftTextKey) ?? '';
    final tags = prefs.getString(_draftTagsKey) ?? '';
    final emotion = prefs.getString(_draftEmotionKey);
    final customEmotion = prefs.getString(_draftCustomEmotionKey) ?? '';
    final hasDraft = text.trim().isNotEmpty ||
        tags.trim().isNotEmpty ||
        (emotion != null && emotion != '说不清') ||
        customEmotion.trim().isNotEmpty;
    if (!mounted || !hasDraft) return;
    _controller.text = text;
    _tagController.text = tags;
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
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftTextKey);
    await prefs.remove(_draftTagsKey);
    await prefs.remove(_draftEmotionKey);
    await prefs.remove(_draftCustomEmotionKey);
  }
}

class _FreshLightHint extends StatelessWidget {
  const _FreshLightHint({required this.fragment});

  final LightFragmentModel fragment;

  @override
  Widget build(BuildContext context) {
    final color = fragment.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .26)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        _ThreadSeed(color: color),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('刚刚留下的光', style: AppText.caption),
            const SizedBox(height: 3),
            Text('它会先留在这里，慢慢和旧光靠近。', style: AppText.bodyMuted),
          ]),
        ),
      ]),
    );
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
    final status = draftSaved
        ? '草稿已存'
        : restoredDraft
            ? '上次的光已找回'
            : writtenCount == 0
                ? '可以只留一句'
                : '已写 $writtenCount 字';
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

class _ThreadSeed extends StatelessWidget {
  const _ThreadSeed({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 42,
      child: CustomPaint(painter: _ThreadSeedPainter(color)),
    );
  }
}

class _ThreadSeedPainter extends CustomPainter {
  const _ThreadSeedPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(5, size.height * .62)
      ..cubicTo(15, 6, 30, size.height - 5, size.width - 5, 12);
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width * .30, size.height * .42),
      5,
      Paint()..color = color.withValues(alpha: .28),
    );
    canvas.drawCircle(
      Offset(size.width * .72, size.height * .34),
      4,
      Paint()..color = color.withValues(alpha: .62),
    );
  }

  @override
  bool shouldRepaint(covariant _ThreadSeedPainter oldDelegate) {
    return oldDelegate.color != color;
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
      {required this.title, required this.action, required this.onTap});
  final String title, action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(title, style: AppText.titleMedium)),
      TextButton(onPressed: onTap, child: Text(action)),
    ]);
  }
}

extension _LightFragmentAdapter on LightFragmentModel {
  LightFragment toLightFragment() {
    return LightFragment(
      time: time,
      date: dateLabel,
      title: title,
      text: contentText,
      emotion: emotion,
      tags: tags,
      color: color,
      relation: status,
      mediaUrls: mediaUrls,
    );
  }
}
