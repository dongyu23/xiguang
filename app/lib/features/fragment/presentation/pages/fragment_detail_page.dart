// PAGE_SIZE_EXEMPT: migration in progress; sections are being moved to widgets and mutations to application controllers.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';

import 'package:xiguang/app/app_state.dart';
import '../../../emotion/application/emotions_controller.dart';
import '../../../relation/presentation/providers/relation_providers.dart';
import '../../application/fragment_detail_controller.dart';
import '../providers/fragment_providers.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../domain/fragment.dart';
import '../../../../ui/composites/image_grid.dart';
import '../../../../ui/composites/emotion_picker.dart';
import '../../../../ui/composites/media_image.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../../../ui/primitives/night_background.dart';
import '../../../../ui/spaces/space_canvas.dart';
import 'image_attachment_picker.dart';

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
  String _emotion = '说不清';
  int? _loadedFragmentId;
  bool _pickingImage = false;
  bool _pickingAudio = false;

  @override
  void dispose() {
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _acceptPolish(Fragment fragment, String newText) async {
    try {
      // H5: Use centralized updateText
      await ref.read(fragmentDetailControllerProvider.notifier).save(
            fragment: fragment,
            text: newText,
            emotion: fragment.emotion,
            tags: fragment.tags,
          );
      _contentController.text = newText;
      if (!mounted) return;
      ref.read(fragmentDetailControllerProvider.notifier).resetPolish();
      showOverlaySnackBar(
        context,
        SnackBar(content: const Text('润色已保存。'), duration: AppMotion.snackbar),
      );
    } catch (_) {
      if (mounted) {
        showOverlaySnackBar(
          context,
          const SnackBar(content: Text('保存失败，请稍后再试。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fragmentID = int.tryParse(widget.id) ?? 0;
    // 只 watch 目标光片，列表中其他光片变化不触发此页重建
    final fragmentAsync = ref.watch(fragmentsProvider.select((asyncValue) {
      return asyncValue.whenData(
          (items) => items.where((item) => item.id == fragmentID).firstOrNull);
    }));
    final polishEnabled = ref.watch(aiPolishEnabledProvider);
    final detailState = ref.watch(fragmentDetailControllerProvider);

    return Stack(children: [
      const Positioned.fill(child: NightBackgroundPlaceholder()),
      const Positioned.fill(child: AtmosphereBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: fragmentAsync.when(
            data: (fragment) {
              if (fragment == null) {
                return _MissingLightState(
                  onBack: () => context.pop(),
                );
              }
              _syncEditors(fragment);
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.s22,
                    AppSpacing.sm,
                    AppSpacing.s22,
                    AppSpacing.pageBottomNav +
                        MediaQuery.paddingOf(context).bottom),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailHeader(
                          onBack: () => context.pop(),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        _LightEditCard(
                          fragment: fragment,
                          contentController: _contentController,
                          tagController: _tagController,
                          emotion: _emotion,
                          onEmotionChanged: (value) =>
                              setState(() => _emotion = value),
                        ),
                        if (detailState.polishStatus !=
                            FragmentPolishStatus.idle)
                          _PolishResultCard(
                            state: detailState.polishStatus,
                            polishedText: detailState.polishedText,
                            message: detailState.polishMessage,
                            onAccept: detailState.polishStatus ==
                                        FragmentPolishStatus.done &&
                                    detailState.polishedText.isNotEmpty
                                ? () => _acceptPolish(
                                    fragment, detailState.polishedText)
                                : null,
                            onRetry: detailState.polishStatus ==
                                    FragmentPolishStatus.error
                                ? () => ref
                                    .read(fragmentDetailControllerProvider
                                        .notifier)
                                    .polish(
                                        contentText: fragment.contentText,
                                        emotion: fragment.emotion)
                                : null,
                            onDiscard: () => ref
                                .read(fragmentDetailControllerProvider.notifier)
                                .resetPolish(),
                          ),
                        const SizedBox(height: AppSpacing.s14),
                        _MediaPanel(
                          urls: fragment.mediaUrls,
                          picking: _pickingImage,
                          pickingAudio: _pickingAudio,
                          onPickImages: () => _pickImages(fragment),
                          onPickAudio: () => _pickAudio(fragment),
                        ),
                        const SizedBox(height: AppSpacing.s14),
                        _WeaveConnectionCard(
                          fragmentId: fragment.id,
                          onWeave: () async {
                            final saved =
                                await _save(fragment, showSuccess: false);
                            if (saved && context.mounted) {
                              context.push('/weave/${fragment.id}');
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.s18),
                        _ActionDock(
                          saving: detailState.isSaving,
                          polishEnabled: polishEnabled &&
                              _contentController.text.trim().isNotEmpty &&
                              detailState.polishStatus ==
                                  FragmentPolishStatus.idle,
                          onSave: () => _save(fragment),
                          onPolish: () => ref
                              .read(fragmentDetailControllerProvider.notifier)
                              .polish(
                                  contentText: _contentController.text,
                                  emotion: _emotion),
                          onDelete: () => _confirmDelete(fragment),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(
              child: Text('暂时无法打开这束光，请稍后再试。', style: AppText.body),
            ),
          ),
        ),
      ),
    ]);
  }

  void _syncEditors(Fragment fragment) {
    if (_loadedFragmentId == fragment.id) return;
    _loadedFragmentId = fragment.id;
    _contentController.text = fragment.contentText;
    _tagController.text = fragment.tags.join(' ');
    _emotion = fragment.emotion;
  }

  Future<bool> _save(
    Fragment fragment, {
    bool showSuccess = true,
  }) async {
    if (ref.read(fragmentDetailControllerProvider).isSaving) return false;
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      showOverlaySnackBar(
        context,
        const SnackBar(
          content: Text('至少留下一句话。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    try {
      // H5: Use centralized updateText to avoid cascade invalidation
      await ref.read(fragmentDetailControllerProvider.notifier).save(
            fragment: fragment,
            text: text,
            emotion: _emotion,
            tags: _parseTags(_tagController.text),
          );
      if (!mounted) return false;
      setState(() {
        _loadedFragmentId = null;
      });
      if (showSuccess) {
        showOverlaySnackBar(
          context,
          const SnackBar(
            content: Text('这束光已经重新放好。'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (_) {
      if (!mounted) return false;
      showOverlaySnackBar(
        context,
        const SnackBar(
          content: Text('暂时无法保存修改，请稍后再试。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  Future<void> _confirmDelete(Fragment fragment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = NightTheme.of(context);
        return AlertDialog(
          backgroundColor: theme.surfaceHigh,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          title: Text(
            '删除这束光？',
            style: AppText.titleMedium.copyWith(color: theme.foreground),
          ),
          content: Text('删除后无法恢复，也会从线和小岛里消失。',
              style: AppText.body.copyWith(color: theme.foreground)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sunsetCoral,
                foregroundColor: AppColors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _delete(fragment);
  }

  Future<void> _delete(Fragment fragment) async {
    // H5: Use centralized deleteMany for proper invalidation
    await ref.read(fragmentDetailControllerProvider.notifier).delete(fragment);
    if (mounted) context.pop();
  }

  Future<void> _pickImages(Fragment fragment) async {
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
      // H5: Use centralized updateText
      await ref.read(fragmentDetailControllerProvider.notifier).save(
            fragment: fragment,
            text: _contentController.text.trim().isEmpty
                ? fragment.contentText
                : _contentController.text.trim(),
            emotion: _emotion,
            tags: _parseTags(_tagController.text),
            mediaUrls: merged,
          );
      if (!mounted) return;
      setState(() {
        _pickingImage = false;
        _loadedFragmentId = null;
      });
      showOverlaySnackBar(
        context,
        const SnackBar(
          content: Text('画面已经附着到这束光。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pickingImage = false);
      showOverlaySnackBar(
        context,
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

  Future<void> _pickAudio(Fragment fragment) async {
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
      // H5: Use centralized updateText
      await ref.read(fragmentDetailControllerProvider.notifier).save(
            fragment: fragment,
            text: _contentController.text.trim().isEmpty
                ? fragment.contentText
                : _contentController.text.trim(),
            emotion: _emotion,
            tags: _parseTags(_tagController.text),
            mediaUrls: merged,
          );
      if (!mounted) return;
      setState(() {
        _pickingAudio = false;
        _loadedFragmentId = null;
      });
      showOverlaySnackBar(
        context,
        const SnackBar(
          content: Text('录音文件已经附着到这束光。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pickingAudio = false);
      showOverlaySnackBar(
        context,
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

  static final _tagSplitter = RegExp(r'[\s,，#]+');

  List<String> _parseTags(String value) {
    return value
        .split(_tagSplitter)
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
  const _DetailHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(children: [
      PageBackButton(
        onTap: onBack,
      ),
      const SizedBox(width: AppSpacing.s12),
      Expanded(
        child: Text(
          '光片详情',
          textAlign: TextAlign.center,
          style: AppText.titleLarge.copyWith(color: theme.foreground),
        ),
      ),
      const SizedBox(width: AppSpacing.s12),
      const SizedBox(width: 42, height: 42),
    ]);
  }
}

class _LightEditCard extends ConsumerWidget {
  const _LightEditCard({
    required this.fragment,
    required this.contentController,
    required this.tagController,
    required this.emotion,
    required this.onEmotionChanged,
  });

  final Fragment fragment;
  final TextEditingController contentController;
  final TextEditingController tagController;
  final String emotion;
  final ValueChanged<String> onEmotionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = NightTheme.of(context);
    final emotions = ref.watch(emotionsProvider);
    final emotionColor = emotions.maybeWhen(
      data: (items) =>
          items.where((item) => item.name == emotion).firstOrNull?.color ??
          AppColors.emotionColor(emotion),
      orElse: () => AppColors.emotionColor(emotion),
    );
    return XiguangCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s18, AppSpacing.md, AppSpacing.s18, AppSpacing.s18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AnimatedContainer(
            duration: AppMotion.fast,
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: emotionColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: emotionColor.withValues(alpha: .36),
                  blurRadius: 9,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('留下的片刻',
              style: AppText.eyebrow.copyWith(color: theme.foregroundMuted)),
          const Spacer(),
          Text('${fragment.dateLabel}  ${fragment.time}',
              style: AppText.caption.copyWith(color: theme.foregroundMuted)),
        ]),
        const SizedBox(height: AppSpacing.s14),
        TextField(
          controller: contentController,
          minLines: 4,
          maxLines: 10,
          style: AppText.body.copyWith(
            color: theme.foreground,
            fontSize: 16,
            height: 1.72,
          ),
          decoration: InputDecoration(
            hintText: '把这一刻轻轻放在这里…',
            hintStyle:
                AppText.placeholder.copyWith(color: theme.foregroundMuted),
            filled: true,
            fillColor:
                emotionColor.withValues(alpha: theme.isNight ? .08 : .06),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s14, vertical: AppSpacing.s14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide:
                  BorderSide(color: emotionColor.withValues(alpha: .18)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide:
                  BorderSide(color: emotionColor.withValues(alpha: .18)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: emotionColor.withValues(alpha: .7)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        Align(
          alignment: Alignment.centerRight,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: contentController,
            builder: (context, value, _) {
              final count = value.text.trim().runes.length;
              return Text(
                '$count 字',
                style: AppText.caption.copyWith(color: theme.foregroundMuted),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Divider(height: 1, color: theme.border.withValues(alpha: .65)),
        const SizedBox(height: AppSpacing.s14),
        EmotionPicker(
          selected: emotion,
          onSelected: onEmotionChanged,
          dense: true,
        ),
        const SizedBox(height: AppSpacing.s7),
        Text(
          '可以选自己收录的心绪，也可以从“更多”里添一个新词。',
          style: AppText.caption.copyWith(color: theme.foregroundMuted),
        ),
        const SizedBox(height: AppSpacing.s14),
        Row(children: [
          Text('给光命名',
              style: AppText.titleSmall.copyWith(color: theme.foreground)),
          const SizedBox(width: AppSpacing.s6),
          Text('可选',
              style: AppText.caption.copyWith(color: theme.foregroundMuted)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: tagController,
          style: AppText.body.copyWith(color: theme.foreground),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.sell_outlined, size: 18),
            hintText: '例如：雨夜  窗边  回家的路',
            hintStyle:
                AppText.placeholder.copyWith(color: theme.foregroundMuted),
            filled: true,
            fillColor: theme.surfaceHigh.withValues(alpha: .48),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 42, minHeight: 42),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ]),
    );
  }
}

class _MediaPanel extends StatelessWidget {
  const _MediaPanel({
    required this.urls,
    required this.picking,
    required this.pickingAudio,
    required this.onPickImages,
    required this.onPickAudio,
  });

  final List<String> urls;
  final bool picking;
  final bool pickingAudio;
  final VoidCallback onPickImages;
  final VoidCallback onPickAudio;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final visualUrls = urls.where((url) => !_isAudioMedia(url)).toList();
    final audioUrls = urls.where(_isAudioMedia).toList();
    final hasVisuals = visualUrls.isNotEmpty;
    final hasAudio = audioUrls.isNotEmpty;
    return XiguangCard(
      padding: const EdgeInsets.all(AppSpacing.s18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.auto_awesome_mosaic_outlined,
                size: 18, color: theme.accent),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('画面与声音',
                    style:
                        AppText.titleSmall.copyWith(color: theme.foreground)),
                const SizedBox(height: AppSpacing.s2),
                Text('有就留下，没有也没关系。',
                    style:
                        AppText.caption.copyWith(color: theme.foregroundMuted)),
              ],
            ),
          ),
        ]),
        if (hasVisuals) ...[
          const SizedBox(height: AppSpacing.s14),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: ImageGrid(
              urls: visualUrls,
              onImageTap: (url) => _showImagePreview(context, url),
            ),
          ),
        ],
        if (hasAudio) ...[
          const SizedBox(height: AppSpacing.s12),
          ...audioUrls.map(
            (url) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AudioAttachmentTile(url: url),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s12),
        Row(children: [
          Expanded(
            child: _AttachmentAction(
              icon: Icons.add_photo_alternate_outlined,
              label: hasVisuals ? '再添画面' : '添一幅画面',
              loading: picking,
              onTap: onPickImages,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _AttachmentAction(
              icon: Icons.graphic_eq_rounded,
              label: hasAudio ? '再添声音' : '添一段声音',
              loading: pickingAudio,
              onTap: onPickAudio,
            ),
          ),
        ]),
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

class _AttachmentAction extends StatelessWidget {
  const _AttachmentAction({
    required this.icon,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return OutlinedButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 17),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: theme.accent,
        side: BorderSide(color: theme.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}

class _AudioAttachmentTile extends StatefulWidget {
  const _AudioAttachmentTile({required this.url});

  final String url;

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
      showOverlaySnackBar(
        context,
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
    final theme = NightTheme.of(context);
    final legacy = _isLegacyAudioCue(widget.url);
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s12, AppSpacing.s10, AppSpacing.s12, AppSpacing.s10),
      decoration: BoxDecoration(
        color: theme.surfaceHigh.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.border,
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
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            legacy ? '旧声音记录 · 无法回放' : '这一刻的声音',
            style: AppText.bodyMuted.copyWith(color: theme.foregroundMuted),
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s14,
                AppSpacing.xxl + AppSpacing.s10,
                AppSpacing.s14,
                AppSpacing.s22,
              ),
              child: Center(
                child: Hero(
                  tag: 'fragment-media-$url',
                  child: InteractiveViewer(
                    minScale: .8,
                    maxScale: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
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
              backgroundColor: AppColors.white.withValues(alpha: .18),
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ]),
    );
  }
}

class _WeaveConnectionCard extends ConsumerWidget {
  const _WeaveConnectionCard({
    required this.fragmentId,
    required this.onWeave,
  });

  final int fragmentId;
  final VoidCallback onWeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = NightTheme.of(context);
    final relations = ref.watch(fragmentRelationsProvider(fragmentId));
    final count = relations.asData?.value.length;

    return XiguangCard(
      padding: const EdgeInsets.all(AppSpacing.s18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _ConnectionGlyph(color: theme.accent),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('和旧光发生联系',
                    style:
                        AppText.titleSmall.copyWith(color: theme.foreground)),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  count == null
                      ? '正在看看这束光连向哪里…'
                      : count == 0
                          ? '它还安静地待在这里。'
                          : '已经织好 $count 条线。',
                  style: AppText.caption.copyWith(color: theme.foregroundMuted),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.s14),
        Text(
          '织线，就是从过去选一束光，再说说它们为什么相连。以后回看时，这段联系也会被一起看见。',
          style: AppText.bodyMuted.copyWith(
            color: theme.foregroundMuted,
            height: 1.62,
          ),
        ),
        const SizedBox(height: AppSpacing.s14),
        XiguangButton(
          label: count != null && count > 0 ? '继续寻找旧光' : '选择旧光并织线',
          onPressed: onWeave,
          variant: XiguangButtonVariant.secondary,
          leading: const Icon(Icons.call_made_rounded, size: 18),
          height: 46,
        ),
      ]),
    );
  }
}

class _ConnectionGlyph extends StatelessWidget {
  const _ConnectionGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 34,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: 38,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: .22),
                color.withValues(alpha: .86),
                color.withValues(alpha: .22),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _ConnectionPoint(color: color, size: 13),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _ConnectionPoint(color: color, size: 9),
        ),
      ]),
    );
  }
}

class _ConnectionPoint extends StatelessWidget {
  const _ConnectionPoint({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _ActionDock extends StatelessWidget {
  const _ActionDock({
    required this.saving,
    required this.polishEnabled,
    required this.onSave,
    required this.onPolish,
    required this.onDelete,
  });

  final bool saving;
  final bool polishEnabled;
  final VoidCallback onSave;
  final VoidCallback onPolish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Column(children: [
      // 主操作：保存
      XiguangButton(
        label: '保存',
        onPressed: saving ? null : onSave,
        leading: const Icon(Icons.check_rounded, size: 20),
        loading: saving,
      ),
      const SizedBox(height: AppSpacing.s10),
      // 次级操作：柔光润色与危险操作
      Row(children: [
        if (polishEnabled) ...[
          Expanded(child: _PolishButton(onTap: onPolish)),
          const SizedBox(width: AppSpacing.s10),
        ],
        if (!polishEnabled) const Spacer(),
        PopupMenuButton<String>(
          tooltip: '更多操作',
          icon: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(color: theme.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.more_horiz_rounded,
                size: 20, color: theme.foregroundMuted),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          onSelected: (value) {
            switch (value) {
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.sunsetCoral),
                const SizedBox(width: AppSpacing.s10),
                Text('删除这束光',
                    style: AppText.body.copyWith(color: AppColors.sunsetCoral)),
              ]),
            ),
          ],
        ),
      ]),
    ]);
  }
}

class _MissingLightState extends StatelessWidget {
  const _MissingLightState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return XiguangEmptyState(
      title: '没有找到这束光',
      description: '这束光可能已经被轻轻收起。',
      icon: Icons.blur_off_rounded,
      action: XiguangButton(
        label: '返回',
        onPressed: onBack,
        leading: const Icon(Icons.arrow_back_rounded),
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
      duration: AppMotion.breath,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 动画受 TickerMode 控制 — 父级关闭 TickerMode 时自动暂停
    return AnimatedBuilder(
      animation: _breathe,
      builder: (_, __) {
        final alpha = 0.14 + _breathe.value * 0.08;
        return FilledButton.icon(
          onPressed: widget.onTap,
          icon: const Icon(Icons.auto_awesome_outlined, size: 18),
          label: const Text('润色', maxLines: 1),
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

  final FragmentPolishStatus state;
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
      duration: AppMotion.shimmer,
    );
    _updateShimmer();
  }

  @override
  void didUpdateWidget(covariant _PolishResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _updateShimmer();
  }

  void _updateShimmer() {
    if (widget.state == FragmentPolishStatus.loading) {
      if (!_shimmer.isAnimating) _shimmer.repeat();
    } else {
      _shimmer.stop();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s14),
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (_, __) {
          return XiguangCard(
            variant: XiguangCardVariant.outlined,
            padding: const EdgeInsets.all(AppSpacing.s18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  const Icon(Icons.auto_awesome_outlined,
                      size: 16, color: AppColors.lilac),
                  const SizedBox(width: AppSpacing.s6),
                  Text(
                    _headerText,
                    style: AppText.eyebrow.copyWith(color: AppColors.lilac),
                  ),
                  const Spacer(),
                  if (widget.onDiscard != null)
                    InkWell(
                      onTap: widget.onDiscard,
                      child: Icon(Icons.close_rounded,
                          size: 18, color: theme.foregroundMuted),
                    ),
                ]),
                const SizedBox(height: AppSpacing.s12),

                // Content area
                if (widget.state == FragmentPolishStatus.loading)
                  _ShimmerBlock(shimmer: _shimmer.value)
                else if (widget.state == FragmentPolishStatus.error)
                  Text(widget.message,
                      style: AppText.body.copyWith(color: theme.foreground))
                else if (widget.state == FragmentPolishStatus.done)
                  _buildDone(theme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDone(NightTheme theme) {
    if (widget.polishedText.isEmpty) {
      return Text(widget.message.isNotEmpty ? widget.message : '它已经足够好了。',
          style: AppText.body.copyWith(color: theme.foreground));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Polished text
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s14),
        decoration: BoxDecoration(
          color: AppColors.lilac.withValues(
            alpha: theme.isNight ? .12 : .06,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          widget.polishedText,
          style: AppText.body.copyWith(color: theme.foreground),
        ),
      ),
      if (widget.message.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(widget.message,
            style: AppText.caption.copyWith(color: theme.accent)),
      ],
      const SizedBox(height: AppSpacing.s14),
      // Actions
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onDiscard,
            child: const Text('保留原文'),
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child: FilledButton.icon(
            onPressed: widget.onAccept,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('采纳润色'),
          ),
        ),
      ]),
    ]);
  }

  String get _headerText {
    return switch (widget.state) {
      FragmentPolishStatus.loading => '正在润色...',
      FragmentPolishStatus.done => '润色完成',
      FragmentPolishStatus.error => '润色失败',
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
    final theme = NightTheme.of(context);
    final baseAlpha =
        theme.isNight ? (0.08 + shimmer * 0.08) : (0.06 + shimmer * 0.06);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _shimmerBar(260, baseAlpha),
      const SizedBox(height: AppSpacing.s10),
      _shimmerBar(180, baseAlpha * .8),
      const SizedBox(height: AppSpacing.s10),
      _shimmerBar(220, baseAlpha * .6),
      const SizedBox(height: AppSpacing.s14),
      Text('星图管理员正在帮你轻轻润色这束光...',
          style: AppText.caption.copyWith(color: theme.foregroundMuted)),
    ]);
  }

  Widget _shimmerBar(double width, double alpha) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: AppColors.lilac.withValues(alpha: alpha.clamp(0.03, 1)),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
    );
  }
}

/// fragment 详情底部的"保留原文 / 采纳润色"操作行用标准 FilledButton + OutlinedButton；
/// 之前此处自定义过一个同名 GlowButton（与 lib/ui/primitives/glow_button.dart 重名），
/// 现已删除以遵守 §9.2 "按钮四选一，不要发明新按钮" 铁律。
