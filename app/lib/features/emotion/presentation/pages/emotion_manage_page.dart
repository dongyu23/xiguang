import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_bottom_sheet.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../application/audio_library_controller.dart';
import '../../application/emotions_controller.dart';
import '../../domain/audio_track.dart';
import '../../domain/user_emotion.dart';
import '../widgets/audio_edit_sheet.dart';
import '../widgets/emotion_edit_sheet.dart';
import '../widgets/emotion_row.dart';

// PAGE_SIZE_EXEMPT: 本轮保留页面级交互编排；编辑表单和列表行已拆到 widgets，
// 后续将新增/长按操作菜单抽为独立 coordinator 后移除此豁免。
enum _AddChoice { emotion, audio }

enum _EmotionAction { setDefault, toggleHidden, edit, delete }

class EmotionManagePage extends ConsumerStatefulWidget {
  const EmotionManagePage({super.key});

  @override
  ConsumerState<EmotionManagePage> createState() => _EmotionManagePageState();
}

class _EmotionManagePageState extends ConsumerState<EmotionManagePage> {
  AudioPlayer? _previewPlayer;
  int? _previewEmotionId;
  int _previewRequestId = 0;

  @override
  void dispose() {
    _previewRequestId++;
    final player = _previewPlayer;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emotions = ref.watch(emotionsProvider);
    final theme = NightTheme.of(context);
    return XiguangPage(
      scrollable: false,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s22,
        AppSpacing.s10,
        AppSpacing.s22,
        0,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconButton(
                tooltip: '返回',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(Icons.arrow_back_rounded, color: theme.foreground),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text('管理心情',
                    style:
                        AppText.titleLarge.copyWith(color: theme.foreground)),
              ),
              XiguangButton(
                label: '新增',
                expand: false,
                height: 40,
                onPressed: () => _showAddChoiceSheet(),
                leading: const Icon(Icons.add_rounded, size: 18),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: emotions.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                  child: XiguangEmptyState(
                    title: '暂时读不到心情',
                    description: '请稍后再试，已有的光片不会受到影响。',
                    icon: Icons.cloud_off_outlined,
                  ),
                ),
                data: (items) => items.isEmpty
                    ? const Center(
                        child: XiguangEmptyState(
                          title: '还没有心情',
                          description: '点右上角"新增"，写一个自己的感觉。',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(
                            bottom: AppSpacing.pageBottomNav),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.s6),
                        itemBuilder: (context, index) {
                          final emotion = items[index];
                          return EmotionRow(
                            emotion: emotion,
                            previewing: _previewEmotionId == emotion.id,
                            onPreview: () => _togglePreview(emotion),
                            onEdit: () => _showEditSheet(context, emotion),
                            onLongPress: () => _showEmotionActionSheet(emotion),
                            onDelete: emotion.isDefault
                                ? null
                                : () => _confirmDelete(context, ref, emotion),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePreview(UserEmotion emotion) async {
    if (emotion.soundKey == null) return;
    final tracks = ref.read(audioTracksProvider).valueOrNull ?? const [];
    AudioTrack? track;
    for (final t in tracks) {
      if (t.key == emotion.soundKey) track = t;
    }
    if (track == null) return;

    final player = _previewPlayer ??= AudioPlayer();
    final requestId = ++_previewRequestId;

    if (_previewEmotionId == emotion.id) {
      setState(() => _previewEmotionId = null);
      try {
        await player.stop();
      } catch (_) {
        // The UI is already reset; a stopped/disposed player needs no recovery.
      }
      return;
    }

    setState(() => _previewEmotionId = emotion.id);
    try {
      await player.stop();
      if (!mounted || requestId != _previewRequestId) return;
      await player.setLoopMode(LoopMode.one);
      if (!mounted || requestId != _previewRequestId) return;
      if (track.isBuiltin) {
        await player.setAsset(track.assetPath!);
      } else {
        await player.setFilePath(track.filePath!);
      }
      if (!mounted || requestId != _previewRequestId) return;
      unawaited(_playPreview(player, requestId));
    } catch (_) {
      if (mounted && requestId == _previewRequestId) {
        setState(() => _previewEmotionId = null);
      }
    }
  }

  Future<void> _playPreview(AudioPlayer player, int requestId) async {
    try {
      await player.play();
      if (mounted && requestId == _previewRequestId && !player.playing) {
        setState(() => _previewEmotionId = null);
      }
    } catch (_) {
      if (mounted && requestId == _previewRequestId) {
        setState(() => _previewEmotionId = null);
      }
    }
  }

  Future<void> _showAddChoiceSheet() async {
    final theme = NightTheme.of(context);
    final choice = await showModalBottomSheet<_AddChoice>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          child: XiguangBottomSheet(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('新增',
                    style:
                        AppText.titleLarge.copyWith(color: theme.foreground)),
                const SizedBox(height: AppSpacing.md),
                _ActionTile(
                  icon: Icons.mood_outlined,
                  label: '新增心情',
                  onTap: () => Navigator.of(ctx).pop(_AddChoice.emotion),
                ),
                _ActionTile(
                  icon: Icons.music_note_rounded,
                  label: '新增背景音乐',
                  onTap: () => Navigator.of(ctx).pop(_AddChoice.audio),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == _AddChoice.emotion) {
      _showEditSheet(context, null);
    } else if (choice == _AddChoice.audio) {
      _showAudioSheet(context);
    }
  }

  Future<void> _showEmotionActionSheet(
    UserEmotion emotion,
  ) async {
    final theme = NightTheme.of(context);
    final action = await showModalBottomSheet<_EmotionAction>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          child: XiguangBottomSheet(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emotion.name,
                    style:
                        AppText.titleLarge.copyWith(color: theme.foreground)),
                const SizedBox(height: AppSpacing.md),
                if (!emotion.isUserDefault)
                  _ActionTile(
                    icon: Icons.star_outline_rounded,
                    label: '设为默认心情',
                    onTap: () =>
                        Navigator.of(ctx).pop(_EmotionAction.setDefault),
                  ),
                _ActionTile(
                  icon: emotion.hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  label: emotion.hidden ? '取消隐藏' : '隐藏',
                  onTap: () =>
                      Navigator.of(ctx).pop(_EmotionAction.toggleHidden),
                ),
                _ActionTile(
                  icon: Icons.edit_outlined,
                  label: '编辑',
                  onTap: () => Navigator.of(ctx).pop(_EmotionAction.edit),
                ),
                if (!emotion.isDefault)
                  _ActionTile(
                    icon: Icons.delete_outline_rounded,
                    label: '删除',
                    color: theme.danger,
                    onTap: () => Navigator.of(ctx).pop(_EmotionAction.delete),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _EmotionAction.setDefault:
        await ref.read(emotionsProvider.notifier).setUserDefault(emotion);
      case _EmotionAction.toggleHidden:
        await ref.read(emotionsProvider.notifier).toggleHidden(emotion);
      case _EmotionAction.edit:
        _showEditSheet(context, emotion);
      case _EmotionAction.delete:
        _confirmDelete(context, ref, emotion);
    }
  }

  Future<void> _showEditSheet(
    BuildContext context,
    UserEmotion? existing,
  ) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => EmotionEditSheet(existing: existing),
    );
  }

  Future<void> _showAudioSheet(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const AudioEditSheet(),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    UserEmotion emotion,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除心情'),
        content: Text('删除「${emotion.name}」后，已用它记录的光片仍保留原文字，'
            '只是选择器不再显示这个心情。确定删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sunsetCoral,
              foregroundColor: AppColors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(emotionsProvider.notifier).delete(emotion);
    }
  }
}

/// action sheet / choice sheet 里的通栏选项行。
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final effective = color ?? theme.foreground;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s10, vertical: AppSpacing.s12),
        child: Row(children: [
          Icon(icon, size: 20, color: effective),
          const SizedBox(width: AppSpacing.s10),
          Text(label, style: AppText.body.copyWith(color: effective)),
        ]),
      ),
    );
  }
}
