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

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/composites/emotion_picker.dart';
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

class _CapturePageBodyState extends ConsumerState<_CapturePageBody> {
  String _emotion = '说不清';

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
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
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.s10),
            _BreathingLightBanner(
              moodColor: moodColor,
              nightMode: nightMode,
              audioAsset: vinylAudioAsset,
            ),
            SizedBox(height: compact ? AppSpacing.s9 : AppSpacing.s12),
            _QuickRecordComposer(
              selectedEmotion: _emotion,
              onEmotionChanged: (emotion) => setState(() => _emotion = emotion),
              nightMode: nightMode,
            ),
          ],
        ),
      ),
    );
  }

  String get _effectiveEmotion => _emotion;
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
      final hp = constraints.maxWidth > 520 ? 24.0 : 16.0;
      return Stack(children: [
        // C2: Background now provided by _AppShell in router.dart
        Positioned.fill(
          child: _MoodBackground(moodColor: moodColor, nightMode: nightMode),
        ),
        SafeArea(
          child: AnimatedSwitcher(
            duration: AppMotion.normal,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hp, AppSpacing.md, hp, 126),
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
                AppColors.nightSurfaceHigh.withValues(alpha: .34),
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
      const SizedBox(height: AppSpacing.xs),
      Text(title, style: AppText.onNight(AppText.hero, nightMode)),
      const SizedBox(height: AppSpacing.xs),
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
      height: compact ? 112 : 176,
      decoration: softDecoration(AppColors.ink).copyWith(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: nightMode
              ? [
                  AppColors.nightSurfaceHigh,
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
              top: compact ? 16 : 24,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '留下一束光',
                      style: AppText.inverseTitle,
                    ),
                    SizedBox(height: compact ? AppSpacing.xs : AppSpacing.s6),
                    Text(
                      nightMode ? '夜间轻开：慢一点放下。' : '沿着今天的节律，轻轻落下。',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.inverseBody,
                    ),
                  ])),
          Positioned(
            right: compact ? 14 : 26,
            top: compact ? 14 : 24,
            child: VinylLightSource(
              size: compact ? 82 : 112,
              moodColor: moodColor,
              nightMode: nightMode,
              audioAsset: audioAsset,
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

class _QuickRecordComposer extends ConsumerStatefulWidget {
  const _QuickRecordComposer({
    required this.selectedEmotion,
    required this.onEmotionChanged,
    required this.nightMode,
  });

  final String selectedEmotion;
  final ValueChanged<String> onEmotionChanged;
  final bool nightMode;

  @override
  ConsumerState<_QuickRecordComposer> createState() =>
      _QuickRecordComposerState();
}

class _QuickRecordComposerState extends ConsumerState<_QuickRecordComposer> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final _attachmentRecorder = AudioRecorder();
  final List<XFile> _images = [];
  Timer? _audioTimer;
  bool _recordingAudio = false;
  final ValueNotifier<int> _audioSeconds = ValueNotifier(0);
  String? _audioPath;
  bool _saving = false;

  @override
  void dispose() {
    _audioTimer?.cancel();
    _audioSeconds.dispose();
    unawaited(_attachmentRecorder.dispose());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    final nw = widget.nightMode;
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.s14 : AppSpacing.s18,
        compact ? AppSpacing.s14 : AppSpacing.s18,
        compact ? AppSpacing.s14 : AppSpacing.s18,
        compact ? AppSpacing.s14 : AppSpacing.s18,
      ),
      decoration: softDecoration(AppColors.white, nightMode: nw),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('把这一瞬间放在这里', style: AppText.onNight(AppText.titleMedium, nw)),
        SizedBox(height: compact ? AppSpacing.s9 : AppSpacing.s12),
        // 输入框 + 附件行（同一 Container 内，视觉上附件紧贴输入框底部）
        Container(
          decoration: BoxDecoration(
              color: nw
                  ? AppColors.white.withValues(alpha: .10)
                  : AppColors.paper.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: nw
                    ? AppColors.white.withValues(alpha: .16)
                    : AppColors.line.withValues(alpha: .86),
              )),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('capture-content'),
                controller: _controller,
                minLines: compact ? 3 : 5,
                maxLines: 8,
                style: AppText.onNight(AppText.body, nw).copyWith(
                  color: nw ? AppColors.white : null,
                ),
                decoration: InputDecoration(
                  hintText: '可以只留一句，也可以慢慢写完。',
                  hintStyle: AppText.onNight(AppText.placeholder, nw),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(
                      AppSpacing.s14, AppSpacing.s13, AppSpacing.s14, AppSpacing.s13),
                ),
              ),
              // 附件行：左缩略图 + 右添加按钮
              if (_images.isNotEmpty || _hasAudioCue)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s10, 0, AppSpacing.s6, AppSpacing.s6),
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length + (_hasAudioCue ? 1 : 0),
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.s6),
                      itemBuilder: (context, index) {
                        if (index < _images.length) {
                          final image = _images[index];
                          return _InlineImageThumb(
                            image: image,
                            nightMode: nw,
                            onRemove: () =>
                                setState(() => _images.removeAt(index)),
                          );
                        }
                        return _InlineAudioChip(
                          seconds: _audioSeconds.value,
                          recording: _recordingAudio,
                          nightMode: nw,
                          onTap: _recordingAudio
                              ? () => unawaited(_stopAudio())
                              : () => unawaited(_clearAudio()),
                        );
                      },
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s10, 0, AppSpacing.s10, AppSpacing.sm),
                child: Row(children: [
                  _MiniAttachButton(
                    icon: Icons.add_photo_alternate_outlined,
                    active: _images.isNotEmpty,
                    nightMode: nw,
                    onTap: _saving ? null : _pickImages,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _MiniAttachButton(
                    icon: _recordingAudio
                        ? Icons.stop_rounded
                        : Icons.mic_none_rounded,
                    active: _hasAudioCue || _recordingAudio,
                    nightMode: nw,
                    onTap: _saving ? null : _toggleAudio,
                  ),
                ]),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? AppSpacing.s6 : AppSpacing.sm),
        _ComposerMetaRow(
          writtenCount: _writtenCount,
        ),
        SizedBox(height: compact ? AppSpacing.sm : AppSpacing.s12),
        EmotionPicker(
            selected: widget.selectedEmotion,
            onSelected: (e) => widget.onEmotionChanged(e),
            dense: compact,
            nightMode: widget.nightMode),
        SizedBox(height: compact ? AppSpacing.s10 : AppSpacing.s14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: nw
                    ? AppColors.teaGreen.withValues(alpha: .72)
                    : AppColors.ink,
                foregroundColor: AppColors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md))),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.wb_sunny_outlined, size: 18),
            label: Text(_saving ? '落下中' : '捕光'),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
      ]),
    );
  }

  bool get _hasAudioCue => _audioSeconds.value > 0 || _audioPath != null;

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
    final text = _controller.text.trim();
    if (text.isEmpty) {
      showOverlaySnackBar(
        context,
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
      showOverlaySnackBar(
        context,
        const SnackBar(
            content: Text('暂时无法保存这束光，请稍后再试。'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (!mounted) return;
    _audioTimer?.cancel();
    setState(() {
      _saving = false;
      _recordingAudio = false;
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
    if (_recordingAudio) {
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

  Future<void> _toggleAudio() async {
    if (_isDesktopPlatform) {
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
        _audioPath = path;
      });
      _audioSeconds.value = 0;
      _audioTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _audioSeconds.value += 1;
        });
      });
    } catch (_) {
      if (!mounted) return;
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
      return await _attachmentRecorder.hasPermission(request: false);
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
      path = await _attachmentRecorder.stop() ?? path;
    } catch (_) {
      // If the recorder was already stopped, keep the last known path.
    }
    if (!mounted) return;
    setState(() {
      _recordingAudio = false;
      _audioPath = path;
    });
    if (_audioSeconds.value == 0) _audioSeconds.value = 1;
  }

  Future<void> _clearAudio() async {
    _audioTimer?.cancel();
    if (_recordingAudio) {
      try {
        await _attachmentRecorder.cancel();
      } catch (_) {
        // Ignore recorder cleanup errors.
      }
    }
    if (!mounted) return;
    setState(() {
      _recordingAudio = false;
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
}

class _ComposerMetaRow extends StatelessWidget {
  const _ComposerMetaRow({
    required this.writtenCount,
  });

  final int writtenCount;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(
        writtenCount == 0 ? Icons.edit_note_rounded : Icons.auto_awesome,
        size: 15,
        color: AppColors.teaGreen,
      ),
      const SizedBox(width: AppSpacing.s5),
      Expanded(
        child: Text('已写 $writtenCount 字', style: AppText.caption),
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
    required this.image,
    required this.nightMode,
    required this.onRemove,
  });

  final XFile image;
  final bool nightMode;
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
            padding: const EdgeInsets.all(2),
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

/// 输入框内左下角的内联音频指示 chip（图标 + 时长 + 停止/删除）
class _InlineAudioChip extends StatelessWidget {
  const _InlineAudioChip({
    required this.seconds,
    required this.recording,
    required this.nightMode,
    required this.onTap,
  });

  final int seconds;
  final bool recording;
  final bool nightMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = nightMode ? AppText.nightAccent : AppColors.teaGreen;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
      decoration: BoxDecoration(
        color: AppColors.teaGreen.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
            recording
                ? Icons.fiber_manual_record_rounded
                : Icons.graphic_eq_rounded,
            size: 14,
            color: accent),
        const SizedBox(width: 4),
        Text('${seconds}s', style: AppText.caption.copyWith(color: accent)),
        const SizedBox(width: 4),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Icon(
              recording ? Icons.stop_rounded : Icons.close_rounded,
              size: 14,
              color: AppColors.inkMuted),
        ),
      ]),
    );
  }
}

/// 输入框内右下角的小添加按钮（图片 / 录音）
class _MiniAttachButton extends StatelessWidget {
  const _MiniAttachButton({
    required this.icon,
    required this.active,
    required this.nightMode,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final bool nightMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (nightMode ? AppText.nightAccent : AppColors.teaGreen)
        : (nightMode ? AppText.nightInkMuted : AppColors.inkMuted);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: active
              ? AppColors.teaGreen.withValues(alpha: .16)
              : (nightMode
                  ? AppColors.white.withValues(alpha: .06)
                  : AppColors.white.withValues(alpha: .5)),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

