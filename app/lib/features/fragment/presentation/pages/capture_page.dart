// PAGE_SIZE_EXEMPT: migration in progress; media capture platform code will be separated from the composer view.
import 'dart:io' show File, Platform;
import 'dart:ui' as ui;

import 'dart:math';
import 'dart:convert';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:xiguang/app/app_state.dart';
import '../../../emotion/application/audio_library_controller.dart';
import '../../../emotion/application/emotions_controller.dart';
import '../../../emotion/domain/audio_track.dart';
import '../../../emotion/domain/user_emotion.dart';
import '../../application/capture_controller.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/composites/emotion_picker.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../widgets/vinyl_widgets.dart';
import 'audio_capture_file_stub.dart'
    if (dart.library.io) 'audio_capture_file_io.dart';
import 'image_attachment_picker.dart';

final bool _isDesktopPlatform =
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

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

class _CapturePageBodyState extends ConsumerState<_CapturePageBody>
    with WidgetsBindingObserver {
  String _emotion = '';
  final _composerKey = GlobalKey<_QuickRecordComposerState>();
  final _captureActionKey = GlobalKey();
  final _preparingMedia = ValueNotifier(false);
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 页面挂载时键盘可能已弹出（如从详情页返回），首帧回调校正初值
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final visible = View.of(context).viewInsets.bottom > 0;
      if (visible != _keyboardVisible) {
        setState(() => _keyboardVisible = visible);
      }
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final visible = View.of(context).viewInsets.bottom > 0;
    if (visible != _keyboardVisible) {
      setState(() => _keyboardVisible = visible);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _preparingMedia.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 键盘检测：本页位于 _AppShell 的 Scaffold(resizeToAvoidBottomInset:true)
    // body 内，Scaffold 消费 viewInsets 后 body 子树的 MediaQuery 不再随键盘
    // 变化、不会触发本 widget 重建。故用 WidgetsBindingObserver.didChangeMetrics
    // 监听 metrics 变化，在回调里读 View.of 的原始 viewInsets 并 setState。
    final keyboardVisible = _keyboardVisible;
    final viewport = MediaQuery.sizeOf(context);
    final compact = viewport.width < 430;
    final moodColor = AppColors.emotionColor(_effectiveEmotion);
    final vinylAudioTrack = _vinylAudioForEmotion(
      _effectiveEmotion,
      ref.watch(emotionsProvider).valueOrNull ?? const [],
      ref.watch(audioTracksProvider).valueOrNull ?? const [],
    );
    final isActive = ref.watch(activeTabIndexProvider) == 0;
    final captureState = ref.watch(captureControllerProvider);
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
    final horizontalPadding =
        MediaQuery.sizeOf(context).width > 520 ? AppSpacing.lg : AppSpacing.md;
    return Stack(
      fit: StackFit.expand,
      children: [
        XiguangPage(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.md,
            horizontalPadding,
            AppSpacing.captureComposerClearance + AppSpacing.xxl,
          ),
          backgroundLayer: _MoodBackground(moodColor: moodColor),
          child: TickerMode(
            enabled: isActive,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PageHeader(
                  label: 'GAP OF LIGHT',
                  title: '隙',
                  subtitle: '不用解释，也不用整理。先把这一束光轻轻放下。',
                  compact: compact,
                ),
                SizedBox(height: compact ? AppSpacing.sm : AppSpacing.s10),
                _BreathingLightBanner(
                  moodColor: moodColor,
                  audioTrack: vinylAudioTrack,
                ),
                SizedBox(height: compact ? AppSpacing.s9 : AppSpacing.s12),
                _QuickRecordComposer(
                  key: _composerKey,
                  selectedEmotion: _emotion,
                  onEmotionChanged: (emotion) =>
                      setState(() => _emotion = emotion),
                  onPreparingChanged: (preparing) =>
                      _preparingMedia.value = preparing,
                  keyboardVisible: keyboardVisible,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: horizontalPadding,
          right: horizontalPadding,
          bottom: keyboardVisible
              ? AppSpacing.sm + bottomSafeArea
              : AppSpacing.routeOverlayClearance + bottomSafeArea,
          child: TickerMode(
            enabled: isActive,
            child: ValueListenableBuilder<bool>(
              valueListenable: _preparingMedia,
              builder: (context, preparing, _) {
                final busy = preparing || captureState.isSaving;
                return _FloatingCaptureAction(
                  key: _captureActionKey,
                  busy: busy,
                  compact: compact,
                  onPressed:
                      busy ? null : () => _composerKey.currentState?._save(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String get _effectiveEmotion => _emotion;
}

/// 根据心情名查找绑定的音频；未绑定或未找到时回退到内置"舒缓"。
AudioTrack? _vinylAudioForEmotion(
  String emotion,
  List<UserEmotion> emotions,
  List<AudioTrack> tracks,
) {
  AudioTrack? fallback;
  for (final t in tracks) {
    if (t.key == 'soothing') {
      fallback = t;
      break;
    }
  }
  for (final e in emotions) {
    if (e.name == emotion && e.soundKey != null) {
      for (final t in tracks) {
        if (t.key == e.soundKey) return t;
      }
    }
  }
  return fallback;
}

class _MoodBackground extends StatelessWidget {
  const _MoodBackground({required this.moodColor});

  final Color moodColor;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return IgnorePointer(
      child: CustomPaint(
        painter: _MoodBackgroundPainter(
          moodColor: moodColor,
          topColor: theme.isNight
              ? theme.surfaceHigh.withValues(alpha: .34)
              : moodColor.withValues(alpha: .14),
          middleColor: theme.isNight
              ? moodColor.withValues(alpha: .13)
              : AppColors.white.withValues(alpha: .10),
          bottomColor: theme.isNight
              ? Colors.transparent
              : AppColors.emotionHappy.withValues(alpha: .07),
          lineOpacity: theme.isNight ? .17 : .11,
        ),
      ),
    );
  }
}

class _MoodBackgroundPainter extends CustomPainter {
  const _MoodBackgroundPainter({
    required this.moodColor,
    required this.topColor,
    required this.middleColor,
    required this.bottomColor,
    required this.lineOpacity,
  });

  final Color moodColor;
  final Color topColor;
  final Color middleColor;
  final Color bottomColor;
  final double lineOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, middleColor, bottomColor],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final linePaint = Paint()
      ..color = moodColor.withValues(alpha: lineOpacity)
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
        oldDelegate.topColor != topColor ||
        oldDelegate.middleColor != middleColor ||
        oldDelegate.bottomColor != bottomColor ||
        oldDelegate.lineOpacity != lineOpacity;
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.compact,
  });

  final String label;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.eyebrow.copyWith(color: theme.accent)),
              const SizedBox(height: AppSpacing.xs),
              Text(title,
                  style: AppText.hero.copyWith(color: theme.foreground)),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s3),
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyMuted.copyWith(color: theme.foregroundMuted),
              ),
            ),
          ),
        ],
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppText.eyebrow.copyWith(color: theme.accent)),
      const SizedBox(height: AppSpacing.xs),
      Text(title, style: AppText.hero.copyWith(color: theme.foreground)),
      const SizedBox(height: AppSpacing.xs),
      Text(subtitle, style: AppText.body.copyWith(color: theme.foreground)),
    ]);
  }
}

class _BreathingLightBanner extends StatelessWidget {
  const _BreathingLightBanner({
    required this.moodColor,
    required this.audioTrack,
  });

  final Color moodColor;
  final AudioTrack? audioTrack;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    final theme = NightTheme.of(context);
    return Container(
      height: compact ? 96 : 176,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.isNight
              ? [
                  theme.surfaceHigh,
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
          Positioned.fill(child: CalmWavePainterWidget(color: moodColor)),
          Positioned(
              left: 18,
              right: compact ? 106 : 154,
              top: compact ? 13 : 24,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '留下一束光',
                      style: AppText.inverseTitle,
                    ),
                    SizedBox(height: compact ? AppSpacing.xs : AppSpacing.s6),
                    Text(
                      theme.isNight ? '夜间轻开：慢一点放下。' : '沿着今天的节律，轻轻落下。',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.inverseBody,
                    ),
                  ])),
          Positioned(
            right: compact ? 14 : 26,
            top: compact ? 8 : 24,
            child: VinylLightSource(
              size: compact ? 78 : 112,
              moodColor: moodColor,
              audioTrack: audioTrack,
            ),
          ),
          Positioned.fill(
            child: AnimatedMusicTrail(
              compact: compact,
              color: moodColor,
            ),
          ),
        ]),
      ),
    );
  }
}

/// 始终停在四项导航上方的捕光操作条。
///
/// 它属于页面层而非输入卡片的滚动内容，所以键盘抬起页面时，
/// 按钮和底部导航会保持同一节奏上移。
class _FloatingCaptureAction extends StatelessWidget {
  const _FloatingCaptureAction({
    super.key,
    required this.busy,
    required this.compact,
    required this.onPressed,
  });

  final bool busy;
  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.microMovement,
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: theme.isNight ? .9 : .94),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.border.withValues(alpha: .72)),
        boxShadow: [
          BoxShadow(
            color: theme.foreground.withValues(alpha: theme.isNight ? .2 : .1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: XiguangButton(
        label: busy ? '落下中' : '捕光',
        onPressed: onPressed,
        leading: const Icon(Icons.wb_sunny_outlined, size: 18),
        loading: busy,
        height: compact ? 44 : 48,
      ),
    );
  }
}

class _QuickRecordComposer extends ConsumerStatefulWidget {
  const _QuickRecordComposer({
    super.key,
    required this.selectedEmotion,
    required this.onEmotionChanged,
    required this.onPreparingChanged,
    required this.keyboardVisible,
  });

  final String selectedEmotion;
  final ValueChanged<String> onEmotionChanged;
  final ValueChanged<bool> onPreparingChanged;
  final bool keyboardVisible;

  @override
  ConsumerState<_QuickRecordComposer> createState() =>
      _QuickRecordComposerState();
}

class _QuickRecordComposerState extends ConsumerState<_QuickRecordComposer> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  AudioRecorder? _attachmentRecorder;
  final List<XFile> _images = [];
  Timer? _audioTimer;
  bool _recordingAudio = false;
  bool _audioPaused = false;
  final ValueNotifier<int> _audioSeconds = ValueNotifier(0);
  String? _audioPath;
  bool _preparingMedia = false;

  @override
  void dispose() {
    _audioTimer?.cancel();
    _audioSeconds.dispose();
    final recorder = _attachmentRecorder;
    if (recorder != null) unawaited(recorder.dispose());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    final theme = NightTheme.of(context);
    final captureState = ref.watch(captureControllerProvider);
    final busy = _preparingMedia || captureState.isSaving;
    return XiguangCard(
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.s14 : AppSpacing.s18,
        compact ? AppSpacing.s14 : AppSpacing.s18,
        compact ? AppSpacing.s14 : AppSpacing.s18,
        compact ? AppSpacing.s14 : AppSpacing.s18,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '把这一瞬间放在这里',
          style: AppText.titleSmall.copyWith(color: theme.foreground),
        ),
        SizedBox(height: compact ? AppSpacing.s9 : AppSpacing.s12),
        // 文字输入单独成区；媒体操作不再与输入框共用边框，避免录音状态撑高输入框。
        AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.microMovement,
          decoration: BoxDecoration(
              color: theme.surfaceHigh.withValues(
                alpha: theme.isNight ? .72 : .78,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: theme.border.withValues(alpha: .86),
              )),
          child: TextField(
            key: const ValueKey('capture-content'),
            controller: _controller,
            minLines: compact ? 3 : 5,
            maxLines:
                widget.keyboardVisible ? (compact ? 3 : 5) : (compact ? 6 : 8),
            scrollPadding: const EdgeInsets.only(
              bottom: AppSpacing.captureComposerClearance,
            ),
            style: AppText.body.copyWith(color: theme.foreground),
            decoration: InputDecoration(
              hintText: '可以只留一句，也可以慢慢写完。',
              hintStyle:
                  AppText.placeholder.copyWith(color: theme.foregroundMuted),
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(
                AppSpacing.s14,
                compact ? AppSpacing.s10 : AppSpacing.s13,
                AppSpacing.s14,
                compact ? AppSpacing.s10 : AppSpacing.s13,
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.normal,
          curve: AppMotion.microMovement,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: AppMotion.normal,
            switchInCurve: AppMotion.easeOut,
            switchOutCurve: AppMotion.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: .94, end: 1).animate(animation),
                alignment: Alignment.centerLeft,
                child: child,
              ),
            ),
            child: _images.isEmpty
                ? const SizedBox.shrink(key: ValueKey('empty-image-strip'))
                : Padding(
                    key: ValueKey('image-strip-${_images.length}'),
                    padding: const EdgeInsets.only(top: AppSpacing.s6),
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.s6),
                        itemBuilder: (context, index) => _InlineImageThumb(
                          key: ValueKey(_images[index].path),
                          image: _images[index],
                          onRemove: () =>
                              setState(() => _images.removeAt(index)),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        SizedBox(height: compact ? AppSpacing.s6 : AppSpacing.sm),
        Row(
          children: [
            _AttachmentAction(
              icon: Icons.image_outlined,
              label: _images.isEmpty ? '图片' : '图片 ${_images.length}',
              active: _images.isNotEmpty,
              onTap: busy ? null : _pickImages,
            ),
            const SizedBox(width: AppSpacing.s6),
            _AttachmentAction(
              icon: _audioPaused
                  ? Icons.play_arrow_rounded
                  : _hasAudioCue
                      ? Icons.graphic_eq_rounded
                      : Icons.mic_none_rounded,
              label: _audioActionLabel,
              time: _audioTimeLabel,
              active: _hasAudioCue || _recordingAudio || _audioPaused,
              recording: _recordingAudio,
              showRemove: _hasAudioCue,
              onTap: busy ? null : _handleAudioAction,
              onRemove: busy ? null : _cancelAudio,
            ),
            const Spacer(),
            _ComposerMetaRow(writtenCount: _writtenCount),
          ],
        ),
        SizedBox(height: compact ? AppSpacing.sm : AppSpacing.s12),
        EmotionPicker(
            selected: widget.selectedEmotion,
            onSelected: (e) => widget.onEmotionChanged(e),
            dense: compact),
      ]),
    );
  }

  bool get _hasAudioCue => _audioSeconds.value > 0 || _audioPath != null;

  String get _audioActionLabel {
    if (_recordingAudio) return '暂停';
    if (_audioPaused) return '继续';
    return '声音';
  }

  String get _audioTimeLabel {
    if (_audioSeconds.value > 0) return _formatAudioTime(_audioSeconds.value);
    return '';
  }

  String _formatAudioTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  Future<void> _handleAudioAction() async {
    if (_isDesktopPlatform) {
      await _pickAudioFile();
      return;
    }
    if (_recordingAudio) {
      await _pauseAudio();
    } else if (_audioPaused) {
      await _resumeAudio();
    } else {
      await _startAudio();
    }
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
      showOverlaySnackBar(
        context,
        const SnackBar(
          content: Text('暂时无法打开图片选择。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_preparingMedia || ref.read(captureControllerProvider).isSaving) {
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) {
      showOverlaySnackBar(
        context,
        const SnackBar(
            content: Text('至少留下一句话。'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _preparingMedia = true);
    widget.onPreparingChanged(true);
    try {
      final mediaUrls = await _mediaUrlsForSave();
      if (!mounted) return;
      await ref.read(captureControllerProvider.notifier).capture(
            text: text,
            emotion: _emotionForSave(),
            tags: const [],
            mediaUrls: mediaUrls,
          );
    } catch (_) {
      if (!mounted) return;
      showOverlaySnackBar(
        context,
        const SnackBar(
            content: Text('暂时无法保存这束光，请稍后再试。'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    } finally {
      if (mounted) {
        setState(() => _preparingMedia = false);
        widget.onPreparingChanged(false);
      }
    }
    if (!mounted) return;
    _audioTimer?.cancel();
    setState(() {
      _recordingAudio = false;
      _audioPaused = false;
      _audioPath = null;
      _controller.clear();
      _images.clear();
    });
    _audioSeconds.value = 0;
    showOverlaySnackBar(
      context,
      const SnackBar(
          content: Text('这束光已经轻轻放好了。'), behavior: SnackBarBehavior.floating),
    );
  }

  static const _maxInlineImageBytes =
      2 * 1024 * 1024; // 2MB per image for inline base64

  Future<List<String>> _mediaUrlsForSave() async {
    final urls = <String>[];
    if (!kIsWeb) {
      urls.addAll(_images.map((image) => image.path));
    } else {
      for (final image in _images) {
        final bytes = await image.readAsBytes();
        if (bytes.length > _maxInlineImageBytes) {
          if (mounted) {
            showOverlaySnackBar(
              context,
              SnackBar(
                content: Text(
                    '图片过大 (${(bytes.length / 1024 / 1024).toStringAsFixed(1)}MB)，请使用小于2MB的图片。'),
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
    if (_recordingAudio || _audioPaused) {
      await _stopAudio();
    }
    final path = _audioPath;
    if (path == null || _audioSeconds.value <= 0) return null;
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

  Future<void> _pickAudioFile() async {
    if (_audioPath != null) {
      _cancelAudio();
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
        _recordingAudio = false;
      });
      _audioSeconds.value =
          fileSize > 0 ? (fileSize / 16000).ceil().clamp(1, 9999) : 1;
    } catch (_) {
      if (!mounted) return;
      showOverlaySnackBar(
        context,
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
      // 先切到录音态并启动计时器，让 UI 立即响应；
      // recorder 硬件初始化较慢，放后面异步执行，失败则回退。
      _audioTimer?.cancel();
      setState(() {
        _recordingAudio = true;
        _audioPaused = false;
        _audioPath = path;
      });
      _audioSeconds.value = 0;
      _audioTimer = Timer.periodic(AppTiming.audioMeterTick, (_) {
        if (!mounted) return;
        setState(() {
          _audioSeconds.value += 1;
        });
      });
      await _recorder.start(
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
    } catch (_) {
      // recorder 启动失败：回退到空闲态
      _audioTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _recordingAudio = false;
        _audioPaused = false;
        _audioPath = null;
      });
      _audioSeconds.value = 0;
      showOverlaySnackBar(
        context,
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
      return await _recorder.hasPermission(request: false);
    }

    if (!mounted) return false;
    final permanentlyDenied = status.isPermanentlyDenied || status.isRestricted;
    showOverlaySnackBar(
      context,
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
      path = await _attachmentRecorder?.stop() ?? path;
    } catch (_) {
      // If the recorder was already stopped, keep the last known path.
    }
    if (!mounted) return;
    setState(() {
      _recordingAudio = false;
      _audioPaused = false;
      _audioPath = path;
    });
    if (_audioSeconds.value == 0) _audioSeconds.value = 1;
  }

  Future<void> _pauseAudio() async {
    _audioTimer?.cancel();
    try {
      await _attachmentRecorder?.pause();
    } catch (_) {
      // Ignore recorder pause errors.
    }
    if (!mounted) return;
    setState(() {
      _recordingAudio = false;
      _audioPaused = true;
    });
  }

  Future<void> _resumeAudio() async {
    try {
      await _attachmentRecorder?.resume();
    } catch (_) {
      // If resume fails, fall back to starting a new recording.
      return _startAudio();
    }
    _audioTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _recordingAudio = true;
      _audioPaused = false;
    });
    _audioTimer = Timer.periodic(AppTiming.audioMeterTick, (_) {
      if (!mounted) return;
      setState(() {
        _audioSeconds.value += 1;
      });
    });
  }

  Future<void> _cancelAudio() async {
    _audioTimer?.cancel();
    try {
      await _attachmentRecorder?.cancel();
    } catch (_) {
      // Ignore recorder cleanup errors.
    }
    if (!mounted) return;
    setState(() {
      _recordingAudio = false;
      _audioPaused = false;
      _audioPath = null;
    });
    _audioSeconds.value = 0;
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

  String _emotionForSave() => widget.selectedEmotion;

  AudioRecorder get _recorder => _attachmentRecorder ??= AudioRecorder();
}

class _ComposerMetaRow extends StatelessWidget {
  const _ComposerMetaRow({
    required this.writtenCount,
  });

  final int writtenCount;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
        writtenCount == 0 ? Icons.edit_note_rounded : Icons.auto_awesome,
        size: 15,
        color: theme.accent,
      ),
      const SizedBox(width: AppSpacing.s5),
      Text(
        '$writtenCount 字',
        style: AppText.caption.copyWith(color: theme.foregroundMuted),
      ),
    ]);
  }
}

class _SelectedImagePreview extends StatefulWidget {
  const _SelectedImagePreview({
    required this.image,
    required this.width,
    required this.height,
  });

  final XFile image;
  final double width;
  final double height;

  @override
  State<_SelectedImagePreview> createState() => _SelectedImagePreviewState();
}

class _SelectedImagePreviewState extends State<_SelectedImagePreview> {
  Uint8List? _cachedBytes;

  @override
  void initState() {
    super.initState();
    _loadBytes();
  }

  Future<void> _loadBytes() async {
    final rawBytes = await widget.image.readAsBytes();
    if (!mounted) return;
    // 大图降采样：超过 2MB 的图片压缩后再显示，避免内存暴涨
    Uint8List bytes = rawBytes;
    if (bytes.length > 2 * 1024 * 1024) {
      try {
        final codec = await ui.instantiateImageCodec(bytes,
            targetWidth: 400, targetHeight: 400);
        final frame = await codec.getNextFrame();
        final data =
            await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (data != null) bytes = data.buffer.asUint8List();
      } catch (_) {
        // 降采样失败则使用原图
      }
    }
    if (mounted) {
      setState(() => _cachedBytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _cachedBytes;
    if (bytes == null) {
      return Container(
        width: widget.width,
        height: widget.height,
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
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
    );
  }
}

/// 输入框内左下角的内联图片缩略图（32x32 + 删除按钮）
class _InlineImageThumb extends StatelessWidget {
  const _InlineImageThumb({
    super.key,
    required this.image,
    required this.onRemove,
  });

  final XFile image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.file(
          File(image.path),
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
      Positioned(
        right: -2,
        top: -2,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s2),
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: .72),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded,
                size: 12, color: AppColors.white),
          ),
        ),
      ),
    ]);
  }
}

/// 输入区下方的轻量媒体操作。
///
/// 按下时先有很轻的收缩回应；附件完成后颜色、图标和宽度连续过渡。
/// 录音态用低幅声波代替闪烁红点，保留灵动感但不抢内容。
class _AttachmentAction extends StatefulWidget {
  const _AttachmentAction({
    required this.icon,
    required this.label,
    this.time = '',
    required this.active,
    required this.onTap,
    this.recording = false,
    this.showRemove = false,
    this.onRemove,
  });

  final IconData icon;
  final String label;
  final String time;
  final bool active;
  final VoidCallback? onTap;
  final bool recording;
  final bool showRemove;
  final VoidCallback? onRemove;

  @override
  State<_AttachmentAction> createState() => _AttachmentActionState();
}

class _AttachmentActionState extends State<_AttachmentAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final color = widget.recording
        ? theme.danger
        : widget.active
            ? theme.accent
            : theme.foregroundMuted;
    final displayText = widget.time.isEmpty
        ? widget.label
        : '${widget.label} ${widget.time}';
    return Semantics(
      button: true,
      label: displayText,
      child: AnimatedScale(
        scale: _pressed ? .96 : 1,
        duration: AppMotion.quick,
        curve: AppMotion.easeOut,
        child: AnimatedSize(
          duration: AppMotion.normal,
          curve: AppMotion.microMovement,
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.microMovement,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
            decoration: BoxDecoration(
              color: widget.active
                  ? color.withValues(alpha: widget.recording ? .16 : .12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: widget.active
                    ? color.withValues(alpha: widget.recording ? .52 : .42)
                    : theme.border.withValues(alpha: .72),
              ),
              boxShadow: widget.recording
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: .12),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: widget.onTap,
                  onHighlightChanged: widget.onTap == null
                      ? null
                      : (pressed) =>
                          setState(() => _pressed = pressed),
                  borderRadius: BorderRadius.horizontal(
                      left: const Radius.circular(AppRadius.pill)),
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: widget.showRemove ? AppSpacing.s5 : 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: AppMotion.normal,
                          switchInCurve: AppMotion.easeOut,
                          switchOutCurve: AppMotion.easeIn,
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(
                                  scale: animation, child: child),
                          child: widget.recording
                              ? _RecordingWaveGlyph(
                                  key: const ValueKey('recording-wave'),
                                  color: color,
                                )
                              : Icon(
                                  widget.icon,
                                  key: ValueKey(widget.icon),
                                  size: 16,
                                  color: color,
                                ),
                        ),
                        const SizedBox(width: AppSpacing.s5),
                        AnimatedSwitcher(
                          duration: AppMotion.normal,
                          switchInCurve: AppMotion.easeOut,
                          switchOutCurve: AppMotion.easeIn,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                  opacity: animation, child: child),
                          child: Text(
                            widget.label,
                            key: ValueKey(widget.label),
                            style: AppText.captionStrong
                                .copyWith(color: color),
                          ),
                        ),
                        if (widget.time.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.xs),
                          SizedBox(
                            width: 30,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.time,
                                style: AppText.captionStrong.copyWith(
                                  color: color,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.showRemove)
                  GestureDetector(
                    onTap: widget.onRemove,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.s2),
                      child: Icon(Icons.close_rounded,
                          size: 13, color: color),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingWaveGlyph extends StatefulWidget {
  const _RecordingWaveGlyph({super.key, required this.color});

  final Color color;

  @override
  State<_RecordingWaveGlyph> createState() => _RecordingWaveGlyphState();
}

class _RecordingWaveGlyphState extends State<_RecordingWaveGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.ripple,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: const Size.square(16),
          painter: _RecordingWavePainter(
            progress: _controller.value,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _RecordingWavePainter extends CustomPainter {
  const _RecordingWavePainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const bars = 4;
    for (var i = 0; i < bars; i++) {
      final phase = progress * pi * 2 + i * .9;
      final height = 4 + (sin(phase).abs() * 7);
      final x = 2.5 + i * 3.6;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RecordingWavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
