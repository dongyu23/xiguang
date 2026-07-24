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
import '../../../island/application/island_detail_controller.dart';
import '../../../island/domain/island_repository.dart';
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
import '../../../../ui/composites/emotion_picker.dart';
import '../../../../ui/composites/media_image.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../../../ui/primitives/night_background.dart';
import '../../../../ui/spaces/space_canvas.dart';
import 'image_attachment_picker.dart';

enum _AutoSaveStatus { saved, pending, saving, error }

class FragmentDetailPage extends ConsumerStatefulWidget {
  const FragmentDetailPage({
    super.key,
    required this.id,
    this.islandId,
    this.islandRouteId,
    this.islandName,
    this.islandManual = false,
  });

  final String id;
  final int? islandId;
  final String? islandRouteId;
  final String? islandName;
  final bool islandManual;

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
  Timer? _autoSaveTimer;
  Future<bool>? _activeAutoSave;
  _AutoSaveStatus _autoSaveStatus = _AutoSaveStatus.saved;
  int _editRevision = 0;
  bool _hasPendingChanges = false;
  bool _leaving = false;

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
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
    final polishEnabled = ref.watch(aiEnabledProvider);
    final detailState = ref.watch(fragmentDetailControllerProvider);

    return PopScope(
      canPop: !_hasPendingChanges,
      onPopInvokedWithResult: (didPop, _) {
        final fragment = fragmentAsync.asData?.value;
        if (!didPop && fragment != null) {
          unawaited(_leavePage(fragment));
        }
      },
      child: Stack(children: [
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
                            onBack: () => _leavePage(fragment),
                            onDelete: () => _confirmDelete(fragment),
                            onRemoveFromIsland: widget.islandManual &&
                                    (widget.islandId ?? 0) > 0 &&
                                    widget.islandRouteId?.isNotEmpty == true
                                ? () => _confirmRemoveFromIsland(fragment)
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          _LightEditCard(
                            fragment: fragment,
                            contentController: _contentController,
                            tagController: _tagController,
                            emotion: _emotion,
                            autoSaveStatus: _autoSaveStatus,
                            onContentChanged: (_) =>
                                _scheduleAutoSave(fragment),
                            onTagsChanged: (_) => _scheduleAutoSave(fragment),
                            onRetrySave: () => _flushAutoSave(fragment),
                            onEmotionChanged: (value) {
                              setState(() => _emotion = value);
                              _scheduleAutoSave(fragment);
                            },
                            extensions: _LightExtensionsPanel(
                              urls: fragment.mediaUrls,
                              fragmentId: fragment.id,
                              picking: _pickingImage,
                              pickingAudio: _pickingAudio,
                              onPickImages: () => _pickImages(fragment),
                              onPickAudio: () => _pickAudio(fragment),
                              onWeave: () async {
                                final saved = await _flushAutoSave(fragment);
                                if (saved && context.mounted) {
                                  context.push('/weave/${fragment.id}');
                                }
                              },
                            ),
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
                                  .read(
                                      fragmentDetailControllerProvider.notifier)
                                  .resetPolish(),
                            ),
                          if (polishEnabled &&
                              _contentController.text.trim().isNotEmpty &&
                              detailState.polishStatus ==
                                  FragmentPolishStatus.idle) ...[
                            const SizedBox(height: AppSpacing.s18),
                            Align(
                              alignment: Alignment.centerRight,
                              child: _PolishButton(
                                onTap: () => ref
                                    .read(fragmentDetailControllerProvider
                                        .notifier)
                                    .polish(
                                        contentText: _contentController.text,
                                        emotion: _emotion),
                              ),
                            ),
                          ],
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
      ]),
    );
  }

  void _syncEditors(Fragment fragment) {
    if (_loadedFragmentId == fragment.id) return;
    _loadedFragmentId = fragment.id;
    _contentController.text = fragment.contentText;
    _tagController.text = fragment.tags.join(' ');
    _emotion = fragment.emotion;
  }

  void _scheduleAutoSave(Fragment fragment) {
    _autoSaveTimer?.cancel();
    _editRevision++;
    _hasPendingChanges = true;
    setState(() => _autoSaveStatus = _AutoSaveStatus.pending);
    final revision = _editRevision;
    _autoSaveTimer = Timer(
      AppTiming.editorAutoSaveDebounce,
      () => _startAutoSave(fragment, revision),
    );
  }

  void _startAutoSave(Fragment fragment, int revision) {
    final future = _performAutoSave(fragment, revision);
    _activeAutoSave = future;
    unawaited(future.whenComplete(() {
      if (identical(_activeAutoSave, future)) _activeAutoSave = null;
    }));
  }

  Future<bool> _performAutoSave(Fragment fragment, int revision) async {
    if (revision != _editRevision) return false;
    if (ref.read(fragmentDetailControllerProvider).isSaving) {
      _autoSaveTimer = Timer(
        AppTiming.editorAutoSaveRetry,
        () => _startAutoSave(fragment, revision),
      );
      return false;
    }
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      if (mounted) setState(() => _autoSaveStatus = _AutoSaveStatus.error);
      return false;
    }
    if (mounted) setState(() => _autoSaveStatus = _AutoSaveStatus.saving);
    try {
      // H5: Use centralized updateText to avoid cascade invalidation
      await ref.read(fragmentDetailControllerProvider.notifier).save(
            fragment: fragment,
            text: text,
            emotion: _emotion,
            tags: _parseTags(_tagController.text),
          );
      if (!mounted) return false;
      if (revision == _editRevision) {
        _hasPendingChanges = false;
        setState(() => _autoSaveStatus = _AutoSaveStatus.saved);
      } else {
        _autoSaveTimer = Timer(
          AppTiming.editorAutoSaveDebounce,
          () => _startAutoSave(fragment, _editRevision),
        );
      }
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() => _autoSaveStatus = _AutoSaveStatus.error);
      return false;
    }
  }

  Future<bool> _flushAutoSave(Fragment fragment) async {
    _autoSaveTimer?.cancel();
    final activeSave = _activeAutoSave;
    if (activeSave != null) await activeSave;
    if (!_hasPendingChanges) return true;
    _autoSaveTimer?.cancel();
    return _performAutoSave(fragment, _editRevision);
  }

  Future<void> _leavePage(Fragment fragment) async {
    if (_leaving) return;
    _leaving = true;
    final saved = await _flushAutoSave(fragment);
    if (!mounted) return;
    if (saved) {
      context.pop();
    } else {
      _leaving = false;
      showOverlaySnackBar(
        context,
        const SnackBar(
          content: Text('修改还没有保存，请点一下状态提示重试。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    _autoSaveTimer?.cancel();
    _hasPendingChanges = false;
    await _delete(fragment);
  }

  Future<void> _confirmRemoveFromIsland(Fragment fragment) async {
    final islandRouteId = widget.islandRouteId;
    if (islandRouteId == null || islandRouteId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = NightTheme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.surfaceHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          title: Text(
            '从「${widget.islandName ?? '小岛'}」移除？',
            style: AppText.titleMedium.copyWith(color: theme.foreground),
          ),
          content: Text(
            '这束光本身会保留，只是不再放在这座小岛上。',
            style: AppText.body.copyWith(color: theme.foreground),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('移出小岛'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final saved = await _flushAutoSave(fragment);
    if (!saved || !mounted) return;
    try {
      await ref
          .read(islandDetailProvider(islandRouteId).notifier)
          .removeFragments([fragment.id]);
      if (mounted) context.pop();
    } on IslandNotManualException {
      if (!mounted) return;
      showOverlaySnackBar(
        context,
        const SnackBar(content: Text('自动生长的小岛不能手动移除光片。')),
      );
    } catch (_) {
      if (!mounted) return;
      showOverlaySnackBar(
        context,
        const SnackBar(content: Text('暂时无法移出小岛，请稍后再试。')),
      );
    }
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
  const _DetailHeader({
    required this.onBack,
    required this.onDelete,
    this.onRemoveFromIsland,
  });

  final VoidCallback onBack;
  final VoidCallback onDelete;
  final VoidCallback? onRemoveFromIsland;

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
      const SizedBox(width: AppSpacing.s6),
      if (onRemoveFromIsland != null)
        Semantics(
          button: true,
          label: '从小岛移除',
          child: ExcludeSemantics(
            child: SizedBox.square(
              dimension: 36,
              child: IconButton(
                key: const ValueKey('remove-fragment-from-island-button'),
                tooltip: '从小岛移除',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 36, height: 36),
                visualDensity: VisualDensity.compact,
                onPressed: onRemoveFromIsland,
                icon: Icon(
                  Icons.link_off_rounded,
                  size: 19,
                  color: theme.accent,
                ),
              ),
            ),
          ),
        ),
      Semantics(
        button: true,
        label: '删除这束光',
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: 36,
            child: IconButton(
              tooltip: '删除这束光',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded,
                  size: 19, color: theme.foregroundMuted),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _LightEditCard extends ConsumerWidget {
  const _LightEditCard({
    required this.fragment,
    required this.contentController,
    required this.tagController,
    required this.emotion,
    required this.autoSaveStatus,
    required this.onContentChanged,
    required this.onTagsChanged,
    required this.onRetrySave,
    required this.onEmotionChanged,
    required this.extensions,
  });

  final Fragment fragment;
  final TextEditingController contentController;
  final TextEditingController tagController;
  final String emotion;
  final _AutoSaveStatus autoSaveStatus;
  final ValueChanged<String> onContentChanged;
  final ValueChanged<String> onTagsChanged;
  final VoidCallback onRetrySave;
  final ValueChanged<String> onEmotionChanged;
  final Widget extensions;

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
          onChanged: onContentChanged,
          minLines: 3,
          maxLines: 8,
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
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: contentController,
          builder: (context, value, _) {
            final count = value.text.trim().runes.length;
            return _AutoSaveLine(
              status: autoSaveStatus,
              count: count,
              onRetry: onRetrySave,
            );
          },
        ),
        const SizedBox(height: AppSpacing.s12),
        extensions,
        const SizedBox(height: AppSpacing.s14),
        Divider(height: 1, color: theme.border.withValues(alpha: .65)),
        const SizedBox(height: AppSpacing.s14),
        EmotionPicker(
          selected: emotion,
          onSelected: onEmotionChanged,
          dense: true,
        ),
        const SizedBox(height: AppSpacing.s12),
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
          onChanged: onTagsChanged,
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

class _LightExtensionsPanel extends ConsumerWidget {
  const _LightExtensionsPanel({
    required this.urls,
    required this.fragmentId,
    required this.picking,
    required this.pickingAudio,
    required this.onPickImages,
    required this.onPickAudio,
    required this.onWeave,
  });

  final List<String> urls;
  final int fragmentId;
  final bool picking;
  final bool pickingAudio;
  final VoidCallback onPickImages;
  final VoidCallback onPickAudio;
  final VoidCallback onWeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = NightTheme.of(context);
    final visualUrls = urls.where((url) => !_isAudioMedia(url)).toList();
    final audioUrls = urls.where(_isAudioMedia).toList();
    final relationCount =
        ref.watch(fragmentRelationsProvider(fragmentId)).asData?.value.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: theme.isNight ? .10 : .065),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.accent.withValues(alpha: .18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.blur_on_rounded, size: 17, color: theme.accent),
          const SizedBox(width: AppSpacing.s7),
          Text(
            '这束光的余韵',
            style: AppText.titleSmall.copyWith(color: theme.foreground),
          ),
          const Spacer(),
          if (visualUrls.isNotEmpty || audioUrls.isNotEmpty)
            Text(
              '${visualUrls.length} 幅 · ${audioUrls.length} 段',
              style: AppText.caption.copyWith(color: theme.foregroundMuted),
            ),
        ]),
        if (visualUrls.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s10),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: visualUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s7),
              itemBuilder: (context, index) => _LightImageThumb(
                url: visualUrls[index],
                onTap: () => _showImagePreview(context, visualUrls[index]),
              ),
            ),
          ),
        ],
        if (audioUrls.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s10),
          ...audioUrls.map(
            (url) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s7),
              child: _AudioAttachmentTile(url: url),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s10),
        Row(children: [
          Expanded(
            child: _AttachmentAction(
              icon: Icons.add_photo_alternate_outlined,
              label: visualUrls.isEmpty ? '画面' : '再添',
              loading: picking,
              onTap: onPickImages,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _AttachmentAction(
              icon: Icons.graphic_eq_rounded,
              label: audioUrls.isEmpty ? '声音' : '再录',
              loading: pickingAudio,
              onTap: onPickAudio,
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.s10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onWeave,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s6,
                vertical: AppSpacing.s7,
              ),
              child: Row(children: [
                _ConnectionGlyph(color: theme.accent, compact: true),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('织向旧光',
                          style: AppText.bodyStrong
                              .copyWith(color: theme.foreground)),
                      Text(
                        relationCount == null
                            ? '正在寻找回声…'
                            : relationCount == 0
                                ? '找一束有回声的光'
                                : '已有 $relationCount 条线，继续织线',
                        style: AppText.caption
                            .copyWith(color: theme.foregroundMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: theme.foregroundMuted),
              ]),
            ),
          ),
        ),
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

class _LightImageThumb extends StatelessWidget {
  const _LightImageThumb({required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Semantics(
      button: true,
      label: '查看画面',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            width: 112,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: theme.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: MediaImage(
                source: url,
                fit: BoxFit.cover,
                fallback: Icon(Icons.image_not_supported_outlined,
                    color: theme.foregroundMuted),
              ),
            ),
          ),
        ),
      ),
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
          child: _SoundWaveGlyph(
            color: legacy ? theme.foregroundMuted : theme.accent,
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        Text(
          legacy ? '旧声音' : '声音',
          style: AppText.caption.copyWith(color: theme.foregroundMuted),
        ),
      ]),
    );
  }
}

class _SoundWaveGlyph extends StatelessWidget {
  const _SoundWaveGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    const heights = [8.0, 15.0, 22.0, 12.0, 18.0, 9.0, 16.0, 7.0];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final height in heights)
          Container(
            width: 3,
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .78),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
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

class _ConnectionGlyph extends StatelessWidget {
  const _ConnectionGlyph({required this.color, this.compact = false});

  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 42 : 58,
      height: compact ? 28 : 34,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: compact ? 28 : 38,
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
          child: _ConnectionPoint(color: color, size: compact ? 11 : 13),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _ConnectionPoint(color: color, size: compact ? 8 : 9),
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

class _AutoSaveLine extends StatelessWidget {
  const _AutoSaveLine({
    required this.status,
    required this.count,
    required this.onRetry,
  });

  final _AutoSaveStatus status;
  final int count;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final isError = status == _AutoSaveStatus.error;
    final label = switch (status) {
      _AutoSaveStatus.saved => '已自动保存',
      _AutoSaveStatus.pending => '停笔后自动保存',
      _AutoSaveStatus.saving => '正在保存…',
      _AutoSaveStatus.error => count == 0 ? '至少留下一句话' : '保存失败，点此重试',
    };
    final icon = switch (status) {
      _AutoSaveStatus.saved => Icons.check_circle_outline_rounded,
      _AutoSaveStatus.pending => Icons.more_time_rounded,
      _AutoSaveStatus.saving => Icons.sync_rounded,
      _AutoSaveStatus.error => Icons.error_outline_rounded,
    };
    final color = isError ? theme.danger : theme.foregroundMuted;

    return Semantics(
      button: isError,
      child: InkWell(
        onTap: isError ? onRetry : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
          child: Row(children: [
            AnimatedSwitcher(
              duration: AppMotion.fast,
              child: Icon(icon, key: ValueKey(status), size: 14, color: color),
            ),
            const SizedBox(width: AppSpacing.s5),
            Text(label, style: AppText.caption.copyWith(color: color)),
            const Spacer(),
            Text('$count 字',
                style: AppText.caption.copyWith(color: theme.foregroundMuted)),
          ]),
        ),
      ),
    );
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
    final theme = NightTheme.of(context);
    // 动画受 TickerMode 控制 — 父级关闭 TickerMode 时自动暂停
    return AnimatedBuilder(
      animation: _breathe,
      builder: (_, __) {
        final alpha = 0.14 + _breathe.value * 0.08;
        return SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: widget.onTap,
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('润色', maxLines: 1),
            style: FilledButton.styleFrom(
              backgroundColor: theme.accent.withValues(alpha: alpha + .08),
              foregroundColor: theme.foreground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
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
