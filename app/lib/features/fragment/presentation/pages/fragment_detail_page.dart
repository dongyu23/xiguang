import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../data/fragment_repository.dart';
import '../../../ai/data/ai_api.dart';
import '../../../../ui/composites/image_grid.dart';
import '../../../../ui/composites/media_image.dart';
import '../../../../ui/composites/tag_chip.dart';
import '../../../../ui/spaces/space_canvas.dart';
import 'image_attachment_picker.dart';

/// 润色状态机
enum _PolishState { idle, loading, done, error }

class FragmentDetailPage extends ConsumerStatefulWidget {
  const FragmentDetailPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<FragmentDetailPage> createState() => _FragmentDetailPageState();
}

class _FragmentDetailPageState extends ConsumerState<FragmentDetailPage> {
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  final _imagePicker = ImagePicker();
  _PolishState _polishState = _PolishState.idle;
  String _polishedText = '';
  String _polishMessage = '';
  String _emotion = '说不清';
  int? _loadedFragmentId;
  bool _saving = false;
  bool _pickingImage = false;
  bool _pickingAudio = false;

  @override
  void dispose() {
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _polish(String contentText, String emotion) async {
    if (_polishState == _PolishState.loading) return;
    setState(() {
      _polishState = _PolishState.loading;
      _polishedText = '';
      _polishMessage = '';
    });

    try {
      final api = AIApi(ref.read(apiClientProvider));
      final result = await api.polishFragment(contentText, emotion);
      if (!mounted) return;
      final status = result['status'] as String? ?? '';
      if (status == 'error') {
        setState(() {
          _polishState = _PolishState.error;
          _polishMessage = result['message'] as String? ?? '星图管理员一时失神，请稍后再试。';
        });
        return;
      }
      setState(() {
        _polishState = _PolishState.done;
        _polishedText = result['polished_text'] as String? ?? '';
        _polishMessage = result['message'] as String? ?? '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _polishState = _PolishState.error;
        _polishMessage = '星图管理员一时失神，请稍后再试。';
      });
    }
  }

  void _resetPolish() {
    setState(() {
      _polishState = _PolishState.idle;
      _polishedText = '';
      _polishMessage = '';
    });
  }

  Future<void> _acceptPolish(
      LightFragmentModel fragment, String newText) async {
    try {
      await ref.read(fragmentRepositoryProvider).updateFragmentText(
            fragment.id,
            newText,
            emotion: fragment.emotion,
            tags: fragment.tags,
          );
      _contentController.text = newText;
      await ref.read(fragmentsProvider.notifier).refresh();
      ref.invalidate(localTimelineGroupsProvider);
      if (!mounted) return;
      setState(() => _polishState = _PolishState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('润色已保存。'), duration: Duration(seconds: 2)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请稍后再试。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fragmentID = int.tryParse(widget.id) ?? 0;
    final fragments = ref.watch(fragmentsProvider);
    final polishEnabled = ref.watch(aiPolishEnabledProvider);
    final nightMode = ref.watch(nightModeProvider);

    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: fragments.when(
            data: (items) {
              final fragment =
                  items.where((item) => item.id == fragmentID).firstOrNull;
              if (fragment == null) {
                return _MissingLightState(
                  nightMode: nightMode,
                  onBack: () => context.pop(),
                );
              }
              _syncEditors(fragment);
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 104),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailHeader(
                          nightMode: nightMode,
                          onBack: () => context.pop(),
                        ),
                        const SizedBox(height: 18),
                        _LightEditCard(
                          fragment: fragment,
                          contentController: _contentController,
                          tagController: _tagController,
                          emotion: _emotion,
                          nightMode: nightMode,
                          onEmotionChanged: (value) =>
                              setState(() => _emotion = value),
                        ),
                        const SizedBox(height: 14),
                        _MediaPanel(
                          urls: fragment.mediaUrls,
                          nightMode: nightMode,
                          picking: _pickingImage,
                          pickingAudio: _pickingAudio,
                          onPickImages: () => _pickImages(fragment),
                          onPickAudio: () => _pickAudio(fragment),
                        ),
                        if (_polishState == _PolishState.loading ||
                            _polishState == _PolishState.done ||
                            _polishState == _PolishState.error)
                          _PolishResultCard(
                            state: _polishState,
                            polishedText: _polishedText,
                            message: _polishMessage,
                            onAccept: _polishState == _PolishState.done &&
                                    _polishedText.isNotEmpty
                                ? () => _acceptPolish(fragment, _polishedText)
                                : null,
                            onRetry: _polishState == _PolishState.error
                                ? () => _polish(
                                    fragment.contentText, fragment.emotion)
                                : null,
                            onDiscard: _resetPolish,
                          ),
                        const SizedBox(height: 14),
                        _WeavePanel(
                          nightMode: nightMode,
                          onTap: () => context.push('/weave/${fragment.id}'),
                        ),
                        const SizedBox(height: 14),
                        _ActionDock(
                          saving: _saving,
                          polishEnabled: polishEnabled &&
                              _contentController.text.trim().isNotEmpty &&
                              _polishState == _PolishState.idle,
                          nightMode: nightMode,
                          onSave: () => _save(fragment),
                          onPolish: () => _polish(
                            _contentController.text,
                            _emotion,
                          ),
                          onDelete: () => _delete(fragment),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('暂时无法打开这束光：$error', style: AppText.body)),
          ),
        ),
      ),
    ]);
  }

  void _syncEditors(LightFragmentModel fragment) {
    if (_loadedFragmentId == fragment.id) return;
    _loadedFragmentId = fragment.id;
    _contentController.text = fragment.contentText;
    _tagController.text = fragment.tags.join(' ');
    _emotion = fragment.emotion;
  }

  Future<void> _save(LightFragmentModel fragment) async {
    if (_saving) return;
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('至少留下一句话。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(fragmentRepositoryProvider).updateFragmentText(
            fragment.id,
            text,
            emotion: _emotion,
            tags: _parseTags(_tagController.text),
          );
      await ref.read(fragmentsProvider.notifier).refresh();
      ref.invalidate(localTimelineGroupsProvider);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _loadedFragmentId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('这束光已经重新放好。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂时无法保存修改，请稍后再试。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _delete(LightFragmentModel fragment) async {
    await ref.read(fragmentRepositoryProvider).deleteFragment(fragment.id);
    ref.invalidate(fragmentsProvider);
    ref.invalidate(localTimelineGroupsProvider);
    if (mounted) context.pop();
  }

  Future<void> _pickImages(LightFragmentModel fragment) async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final picked = await pickImageAttachments(
        context: context,
        picker: _imagePicker,
        limit: 6,
      );
      if (picked.isEmpty) {
        if (mounted) setState(() => _pickingImage = false);
        return;
      }
      final newUrls = await _mediaUrlsFromPickedImages(picked);
      final merged = _mergeMediaUrls(fragment.mediaUrls, newUrls);
      await ref.read(fragmentRepositoryProvider).updateFragmentText(
            fragment.id,
            _contentController.text.trim().isEmpty
                ? fragment.contentText
                : _contentController.text.trim(),
            emotion: _emotion,
            tags: _parseTags(_tagController.text),
            mediaUrls: merged,
          );
      await ref.read(fragmentsProvider.notifier).refresh();
      ref.invalidate(localTimelineGroupsProvider);
      if (!mounted) return;
      setState(() {
        _pickingImage = false;
        _loadedFragmentId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('画面已经附着到这束光。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pickingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂时无法补充图片，请稍后再试。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<List<String>> _mediaUrlsFromPickedImages(List<XFile> images) async {
    if (!kIsWeb) return images.map((image) => image.path).toList();
    final urls = <String>[];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      urls.add('data:${_mimeType(image)};base64,${base64Encode(bytes)}');
    }
    return urls;
  }

  Future<void> _pickAudio(LightFragmentModel fragment) async {
    if (_pickingAudio) return;
    setState(() => _pickingAudio = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'opus'],
        allowMultiple: false,
        withData: true,
      );
      final file =
          result == null || result.files.isEmpty ? null : result.files.first;
      if (file == null) {
        if (mounted) setState(() => _pickingAudio = false);
        return;
      }
      final audioUrl = _audioDataUrl(file);
      if (audioUrl == null) {
        throw StateError('audio_file_missing');
      }
      final merged = _mergeAudioUrl(fragment.mediaUrls, audioUrl);
      await ref.read(fragmentRepositoryProvider).updateFragmentText(
            fragment.id,
            _contentController.text.trim().isEmpty
                ? fragment.contentText
                : _contentController.text.trim(),
            emotion: _emotion,
            tags: _parseTags(_tagController.text),
            mediaUrls: merged,
          );
      await ref.read(fragmentsProvider.notifier).refresh();
      ref.invalidate(localTimelineGroupsProvider);
      if (!mounted) return;
      setState(() {
        _pickingAudio = false;
        _loadedFragmentId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('录音文件已经附着到这束光。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pickingAudio = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂时无法补充录音文件，请稍后再试。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String? _audioDataUrl(PlatformFile file) {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    return 'data:${_audioMimeType(file.name)};base64,${base64Encode(bytes)}';
  }

  List<String> _mergeMediaUrls(List<String> current, List<String> additions) {
    final audio = current.where(_isAudioMedia);
    final images = [
      ...current.where((url) => !_isAudioMedia(url)),
      ...additions,
    ];
    return [
      ...images.toSet().take(6),
      ...audio,
    ];
  }

  List<String> _mergeAudioUrl(List<String> current, String addition) {
    final images = current.where((url) => !_isAudioMedia(url));
    final audio = [
      ...current.where(_isAudioMedia),
      addition,
    ];
    return [
      ...images,
      ...audio.toSet().take(3),
    ];
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

  String _audioMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.opus')) return 'audio/opus';
    return 'audio/mp4';
  }

  List<String> _parseTags(String value) {
    return value
        .split(RegExp(r'[\s,，#]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }
}

bool _isAudioMedia(String value) {
  final media = value.trim().toLowerCase();
  if (media.isEmpty) return false;
  if (_isLegacyAudioCue(media)) return true;
  if (media.startsWith('data:audio/')) return true;
  if (media.endsWith('.m4a') ||
      media.endsWith('.mp3') ||
      media.endsWith('.wav') ||
      media.endsWith('.aac') ||
      media.endsWith('.ogg') ||
      media.endsWith('.opus')) {
    return true;
  }
  return false;
}

bool _isLegacyAudioCue(String value) {
  return value.trim().toLowerCase().startsWith('audio-cue://');
}

String _playableAudioSource(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('users/')) return '/media/$trimmed';
  return trimmed;
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.nightMode, required this.onBack});

  final bool nightMode;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Tooltip(
        message: '返回线',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onBack,
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: nightMode
                    ? AppColors.white.withValues(alpha: .10)
                    : AppColors.white.withValues(alpha: .76),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: nightMode
                      ? AppColors.white.withValues(alpha: .12)
                      : AppColors.line,
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: nightMode ? AppText.nightInk : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          '光片详情',
          textAlign: TextAlign.center,
          style: AppText.onNight(AppText.hero, nightMode).copyWith(
            fontSize: 30,
          ),
        ),
      ),
      const SizedBox(width: 12),
      const SizedBox(width: 42, height: 42),
    ]);
  }
}

class _LightEditCard extends StatelessWidget {
  const _LightEditCard({
    required this.fragment,
    required this.contentController,
    required this.tagController,
    required this.emotion,
    required this.nightMode,
    required this.onEmotionChanged,
  });

  final LightFragmentModel fragment;
  final TextEditingController contentController;
  final TextEditingController tagController;
  final String emotion;
  final bool nightMode;
  final ValueChanged<String> onEmotionChanged;

  static const _emotions = ['平静', '开心', '疲惫', '焦虑', '失落', '被击中', '混乱', '说不清'];

  @override
  Widget build(BuildContext context) {
    final cardColor = nightMode ? const Color(0xFF203231) : AppColors.white;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration:
          (nightMode ? _nightDecoration() : softDecoration(cardColor)).copyWith(
        border: Border.all(
          color: AppColors.emotionColor(emotion).withValues(alpha: .32),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(fragment.dateLabel,
              style: AppText.onNight(AppText.eyebrow, nightMode)),
          const Spacer(),
          Text(fragment.time,
              style: AppText.onNight(AppText.caption, nightMode)),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: contentController,
          minLines: 5,
          maxLines: 12,
          style: AppText.onNight(AppText.body, nightMode).copyWith(
            fontSize: 17,
            height: 1.62,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: '写下这束光...',
            hintStyle: AppText.onNight(AppText.placeholder, nightMode),
            filled: true,
            fillColor: nightMode
                ? AppColors.white.withValues(alpha: .06)
                : AppColors.paper.withValues(alpha: .46),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: contentController,
            builder: (context, value, _) {
              final count = value.text.trim().runes.length;
              return Text(
                '$count 字',
                style: AppText.onNight(AppText.caption, nightMode),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _emotions
              .map(
                (item) => TagChip(
                  label: item,
                  filled: item == emotion,
                  nightMode: nightMode,
                  onTap: () => onEmotionChanged(item),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: tagController,
          style: AppText.onNight(AppText.body, nightMode),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.sell_outlined, size: 18),
            hintText: '可选标签，用空格分隔',
            hintStyle: AppText.onNight(AppText.placeholder, nightMode),
            filled: true,
            fillColor: nightMode
                ? AppColors.white.withValues(alpha: .06)
                : AppColors.paper.withValues(alpha: .56),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ]),
    );
  }

  BoxDecoration _nightDecoration() {
    return BoxDecoration(
      color: const Color(0xFF203231).withValues(alpha: .84),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.white.withValues(alpha: .10)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .16),
          blurRadius: 24,
          offset: const Offset(0, 14),
        ),
      ],
    );
  }
}

class _MediaPanel extends StatelessWidget {
  const _MediaPanel({
    required this.urls,
    required this.nightMode,
    required this.picking,
    required this.pickingAudio,
    required this.onPickImages,
    required this.onPickAudio,
  });

  final List<String> urls;
  final bool nightMode;
  final bool picking;
  final bool pickingAudio;
  final VoidCallback onPickImages;
  final VoidCallback onPickAudio;

  @override
  Widget build(BuildContext context) {
    final visualUrls = urls.where((url) => !_isAudioMedia(url)).toList();
    final audioUrls = urls.where(_isAudioMedia).toList();
    final hasVisuals = visualUrls.isNotEmpty;
    final hasAudio = audioUrls.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: nightMode
          ? BoxDecoration(
              color: const Color(0xFF203231).withValues(alpha: .80),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.white.withValues(alpha: .10)),
            )
          : softDecoration(AppColors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.photo_library_outlined,
              size: 18,
              color: nightMode ? AppText.nightAccent : AppColors.teaGreen),
          const SizedBox(width: 8),
          Text('附着的画面', style: AppText.onNight(AppText.titleMedium, nightMode)),
          const Spacer(),
          if (hasVisuals)
            Tooltip(
              message: '补充图片',
              child: IconButton.filledTonal(
                onPressed: picking ? null : onPickImages,
                icon: picking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: nightMode
                      ? AppColors.white.withValues(alpha: .10)
                      : AppColors.teaGreen.withValues(alpha: .13),
                  foregroundColor:
                      nightMode ? AppText.nightAccent : AppColors.teaGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        if (hasVisuals)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ImageGrid(
              urls: visualUrls,
              onImageTap: (url) => _showImagePreview(context, url),
            ),
          )
        else
          _EmptyMediaUpload(
            nightMode: nightMode,
            picking: picking,
            onPickImages: onPickImages,
          ),
        if (hasAudio) ...[
          const SizedBox(height: 14),
          _AudioAttachmentList(
            urls: audioUrls,
            nightMode: nightMode,
            picking: pickingAudio,
            onPickAudio: onPickAudio,
          ),
        ] else ...[
          const SizedBox(height: 14),
          _EmptyAudioUpload(
            nightMode: nightMode,
            picking: pickingAudio,
            onPickAudio: onPickAudio,
          ),
        ],
      ]),
    );
  }

  void _showImagePreview(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .86),
      builder: (context) => _ImagePreviewDialog(url: url),
    );
  }
}

class _AudioAttachmentList extends StatelessWidget {
  const _AudioAttachmentList({
    required this.urls,
    required this.nightMode,
    required this.picking,
    required this.onPickAudio,
  });

  final List<String> urls;
  final bool nightMode;
  final bool picking;
  final VoidCallback onPickAudio;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(
          Icons.graphic_eq_rounded,
          size: 18,
          color: nightMode ? AppText.nightAccent : AppColors.teaGreen,
        ),
        const SizedBox(width: 8),
        Text('附着的声音', style: AppText.onNight(AppText.titleMedium, nightMode)),
        const Spacer(),
        Tooltip(
          message: '补充录音文件',
          child: IconButton.filledTonal(
            onPressed: picking ? null : onPickAudio,
            icon: picking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.audio_file_outlined, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: nightMode
                  ? AppColors.white.withValues(alpha: .10)
                  : AppColors.teaGreen.withValues(alpha: .13),
              foregroundColor:
                  nightMode ? AppText.nightAccent : AppColors.teaGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      ...urls.map(
        (url) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _AudioAttachmentTile(url: url, nightMode: nightMode),
        ),
      ),
    ]);
  }
}

class _EmptyAudioUpload extends StatelessWidget {
  const _EmptyAudioUpload({
    required this.nightMode,
    required this.picking,
    required this.onPickAudio,
  });

  final bool nightMode;
  final bool picking;
  final VoidCallback onPickAudio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 128),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: nightMode
            ? AppColors.white.withValues(alpha: .05)
            : AppColors.paper.withValues(alpha: .44),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: nightMode
              ? AppColors.white.withValues(alpha: .10)
              : AppColors.line.withValues(alpha: .80),
        ),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            Icons.graphic_eq_rounded,
            color: nightMode ? AppText.nightAccent : AppColors.teaGreen,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            '附着的声音',
            style: AppText.onNight(AppText.titleMedium, nightMode),
          ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: 176,
          child: FilledButton.icon(
            onPressed: picking ? null : onPickAudio,
            icon: picking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.audio_file_outlined, size: 19),
            label: Text(picking ? '上传中' : '上传录音'),
            style: FilledButton.styleFrom(
              backgroundColor: nightMode ? AppText.nightAccent : AppColors.ink,
              foregroundColor: nightMode ? AppColors.ink : AppColors.white,
              disabledBackgroundColor: nightMode
                  ? AppColors.white.withValues(alpha: .12)
                  : AppColors.ink.withValues(alpha: .18),
              disabledForegroundColor: nightMode
                  ? AppText.nightInk.withValues(alpha: .62)
                  : AppColors.ink.withValues(alpha: .54),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _AudioAttachmentTile extends StatefulWidget {
  const _AudioAttachmentTile({required this.url, required this.nightMode});

  final String url;
  final bool nightMode;

  @override
  State<_AudioAttachmentTile> createState() => _AudioAttachmentTileState();
}

class _AudioAttachmentTileState extends State<_AudioAttachmentTile> {
  late final AudioPlayer _player;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
  }

  @override
  void didUpdateWidget(covariant _AudioAttachmentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      unawaited(_player.stop());
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isLegacyAudioCue(widget.url)) return;
    try {
      if (_player.playing) {
        await _player.pause();
        return;
      }
      setState(() => _loading = true);
      await _setAudioSource(widget.url);
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂时无法播放这段声音。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setAudioSource(String url) async {
    final value = _playableAudioSource(url);
    if (value.startsWith('/') || value.startsWith('file:')) {
      await _player.setFilePath(value.replaceFirst('file://', ''));
      return;
    }
    await _player.setUrl(value);
  }

  @override
  Widget build(BuildContext context) {
    final legacy = _isLegacyAudioCue(widget.url);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: widget.nightMode
            ? AppColors.white.withValues(alpha: .07)
            : AppColors.paper.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.nightMode
              ? AppColors.white.withValues(alpha: .12)
              : AppColors.line,
        ),
      ),
      child: Row(children: [
        StreamBuilder<bool>(
          stream: _player.playingStream,
          initialData: false,
          builder: (context, snapshot) {
            final playing = snapshot.data ?? false;
            return IconButton.filledTonal(
              tooltip: legacy ? '旧声音记录无法回放' : (playing ? '暂停' : '播放'),
              onPressed: legacy || _loading ? null : _toggle,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 22,
                    ),
            );
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            legacy ? '旧声音记录 · 无法回放' : '这一刻的声音',
            style: AppText.onNight(AppText.bodyMuted, widget.nightMode),
          ),
        ),
      ]),
    );
  }
}

class _EmptyMediaUpload extends StatelessWidget {
  const _EmptyMediaUpload({
    required this.nightMode,
    required this.picking,
    required this.onPickImages,
  });

  final bool nightMode;
  final bool picking;
  final VoidCallback onPickImages;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 152),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: nightMode
            ? AppColors.white.withValues(alpha: .06)
            : AppColors.paper.withValues(alpha: .54),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: nightMode
              ? AppColors.white.withValues(alpha: .12)
              : AppColors.line.withValues(alpha: .86),
        ),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: nightMode
                ? AppText.nightAccent.withValues(alpha: .14)
                : AppColors.teaGreen.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.image_outlined,
            color: nightMode ? AppText.nightAccent : AppColors.teaGreen,
            size: 25,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 160,
          child: FilledButton.icon(
            onPressed: picking ? null : onPickImages,
            icon: picking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_outlined, size: 19),
            label: Text(picking ? '上传中' : '上传图片'),
            style: FilledButton.styleFrom(
              backgroundColor: nightMode ? AppText.nightAccent : AppColors.ink,
              foregroundColor: nightMode ? AppColors.ink : AppColors.white,
              disabledBackgroundColor: nightMode
                  ? AppColors.white.withValues(alpha: .12)
                  : AppColors.ink.withValues(alpha: .18),
              disabledForegroundColor: nightMode
                  ? AppText.nightInk.withValues(alpha: .62)
                  : AppColors.ink.withValues(alpha: .54),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ImagePreviewDialog extends StatelessWidget {
  const _ImagePreviewDialog({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 58, 14, 22),
              child: Center(
                child: Hero(
                  tag: 'fragment-media-$url',
                  child: InteractiveViewer(
                    minScale: .8,
                    maxScale: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: MediaImage(
                        source: url,
                        fit: BoxFit.contain,
                        fallback: Container(
                          color: AppColors.paper,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 10,
          right: 14,
          child: IconButton.filled(
            tooltip: '关闭',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .18),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ]),
    );
  }
}

class _WeavePanel extends StatelessWidget {
  const _WeavePanel({required this.nightMode, required this.onTap});

  final bool nightMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: nightMode
          ? BoxDecoration(
              color: const Color(0xFF203231).withValues(alpha: .80),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.white.withValues(alpha: .10)),
            )
          : softDecoration(AppColors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('织线', style: AppText.onNight(AppText.titleMedium, nightMode)),
        const SizedBox(height: 8),
        Text(
          '可以把这束光和另一束旧光轻轻连起来。',
          style: AppText.onNight(AppText.body, nightMode),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.blur_circular_rounded, size: 19),
            label: const Text('和另一束光织在一起'),
            style: FilledButton.styleFrom(
              backgroundColor: nightMode ? AppText.nightAccent : AppColors.ink,
              foregroundColor: nightMode ? AppColors.ink : AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ActionDock extends StatelessWidget {
  const _ActionDock({
    required this.saving,
    required this.polishEnabled,
    required this.nightMode,
    required this.onSave,
    required this.onPolish,
    required this.onDelete,
  });

  final bool saving;
  final bool polishEnabled;
  final bool nightMode;
  final VoidCallback onSave;
  final VoidCallback onPolish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded, size: 20),
          label: Text(saving ? '正在保存' : '保存修改'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teaGreen,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        if (polishEnabled) ...[
          Expanded(child: _PolishButton(onTap: onPolish)),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: OutlinedButton.icon(
            onPressed: saving ? null : onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('删除这束光'),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  nightMode ? AppColors.sunsetCoral : AppColors.teaGreen,
              side: BorderSide(
                color: nightMode
                    ? AppColors.sunsetCoral.withValues(alpha: .62)
                    : AppColors.inkMuted,
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ]),
    ]);
  }
}

class _MissingLightState extends StatelessWidget {
  const _MissingLightState({required this.nightMode, required this.onBack});

  final bool nightMode;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('没有找到这束光。', style: AppText.onNight(AppText.body, nightMode)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('返回'),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 润色按钮 — 带呼吸动画
// ═══════════════════════════════════════════════════════════

class _PolishButton extends StatefulWidget {
  const _PolishButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PolishButton> createState() => _PolishButtonState();
}

class _PolishButtonState extends State<_PolishButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathe,
      builder: (_, __) {
        final alpha = 0.14 + _breathe.value * 0.08;
        return FilledButton.icon(
          onPressed: widget.onTap,
          icon: const Icon(Icons.auto_awesome_outlined, size: 18),
          label: const Text('AI 润色'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.lilac.withValues(alpha: alpha),
            foregroundColor: AppColors.ink,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 润色结果卡片 — loading / done / error 三种状态
// ═══════════════════════════════════════════════════════════

class _PolishResultCard extends StatefulWidget {
  const _PolishResultCard({
    required this.state,
    required this.polishedText,
    required this.message,
    this.onAccept,
    this.onRetry,
    this.onDiscard,
  });

  final _PolishState state;
  final String polishedText;
  final String message;
  final VoidCallback? onAccept;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  State<_PolishResultCard> createState() => _PolishResultCardState();
}

class _PolishResultCardState extends State<_PolishResultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (_, __) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: softDecoration(AppColors.white).copyWith(
              border: Border.all(
                color: AppColors.lilac.withValues(alpha: .22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  const Icon(Icons.auto_awesome_outlined,
                      size: 16, color: AppColors.lilac),
                  const SizedBox(width: 6),
                  Text(
                    _headerText,
                    style: AppText.eyebrow.copyWith(color: AppColors.lilac),
                  ),
                  const Spacer(),
                  if (widget.onDiscard != null)
                    InkWell(
                      onTap: widget.onDiscard,
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.inkMuted),
                    ),
                ]),
                const SizedBox(height: 12),

                // Content area
                if (widget.state == _PolishState.loading)
                  _ShimmerBlock(shimmer: _shimmer.value)
                else if (widget.state == _PolishState.error)
                  Text(widget.message, style: AppText.body)
                else if (widget.state == _PolishState.done)
                  _buildDone(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDone() {
    if (widget.polishedText.isEmpty) {
      return Text(widget.message.isNotEmpty ? widget.message : '它已经足够好了。',
          style: AppText.body);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Polished text
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.lilac.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(widget.polishedText, style: AppText.body),
      ),
      if (widget.message.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(widget.message,
            style: AppText.caption.copyWith(color: AppColors.teaGreen)),
      ],
      const SizedBox(height: 14),
      // Actions
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onDiscard,
            child: const Text('保留原文'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GlowButton(
            label: '采纳润色',
            icon: Icons.check_rounded,
            onPressed: widget.onAccept,
          ),
        ),
      ]),
    ]);
  }

  String get _headerText {
    return switch (widget.state) {
      _PolishState.loading => '正在润色...',
      _PolishState.done => '润色完成',
      _PolishState.error => '润色失败',
      _ => '',
    };
  }
}

/// 闪烁骨架 — loading 态
class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({required this.shimmer});
  final double shimmer;

  @override
  Widget build(BuildContext context) {
    final baseAlpha = 0.06 + shimmer * 0.06;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _shimmerBar(260, baseAlpha),
      const SizedBox(height: 10),
      _shimmerBar(180, baseAlpha * .8),
      const SizedBox(height: 10),
      _shimmerBar(220, baseAlpha * .6),
      const SizedBox(height: 14),
      Text('星图管理员正在帮你轻轻润色这束光...',
          style: AppText.caption.copyWith(color: AppColors.inkMuted)),
    ]);
  }

  Widget _shimmerBar(double width, double alpha) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: AppColors.lilac.withValues(alpha: alpha.clamp(0.03, 1)),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// GlowButton for the accept action
class GlowButton extends StatelessWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.teaGreen,
        foregroundColor: Colors.white,
      ),
    );
  }
}
