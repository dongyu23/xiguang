import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/emotion/application/emotions_controller.dart';
import '../../../features/emotion/domain/user_emotion.dart';
import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/motion.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/typography.dart';
import '../../design/tokens/spacing.dart';
import '../primitives/overlay_snackbar.dart';
import 'xiguang_bottom_sheet.dart';

/// "更多"情绪选择 sheet — 可滚动的全部情绪列表 + 底部"新增自定义"。
///
/// 只做"选择"和"新增"两件事。编辑/删除在「我的 → 管理心情」工具栏。
class EmotionMoreSheet extends ConsumerStatefulWidget {
  const EmotionMoreSheet({
    super.key,
    required this.emotions,
    required this.selected,
  });

  final List<UserEmotion> emotions;
  final String selected;

  @override
  ConsumerState<EmotionMoreSheet> createState() => _EmotionMoreSheetState();
}

class _EmotionMoreSheetState extends ConsumerState<EmotionMoreSheet> {
  late List<UserEmotion> _emotions;
  final _newCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emotions = List.of(widget.emotions);
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final adding = ref.watch(emotionsProvider).isLoading;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: AppMotion.fast,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: .68,
        child: XiguangBottomSheet(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s14),
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('更多心绪',
                          style: AppText.titleLarge
                              .copyWith(color: theme.foreground)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '不用选得准确，靠近此刻就好。',
                        style: AppText.bodyMuted
                            .copyWith(color: theme.foregroundMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  icon: Icon(Icons.close_rounded, color: theme.foregroundMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _emotions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 44,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                  ),
                  itemBuilder: (context, index) {
                    final emotion = _emotions[index];
                    return _MoreChip(
                      emotion: emotion,
                      isSelected: widget.selected == emotion.name,
                      onTap: () => Navigator.of(context).pop(emotion.name),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.s14),
              Divider(height: 1, color: theme.border.withValues(alpha: .72)),
              const SizedBox(height: AppSpacing.s14),
              Text('给此刻一个自己的名字',
                  style:
                      AppText.captionStrong.copyWith(color: theme.foreground)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _newCtrl,
                maxLength: 8,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => adding ? null : _addCustom(),
                style: AppText.body.copyWith(color: theme.foreground),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '例如：松了一口气',
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: IconButton.filled(
                      tooltip: '新增心绪',
                      onPressed: adding ? null : _addCustom,
                      icon: adding
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_upward_rounded, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addCustom() async {
    final name = _newCtrl.text.trim();
    if (name.isEmpty) {
      showOverlaySnackBar(
          context,
          SnackBar(
              content: const Text('先写一个感觉的名字。'),
              duration: AppMotion.snackbar,
              behavior: SnackBarBehavior.floating));
      return;
    }
    if (_emotions.any((e) => e.name == name)) {
      showOverlaySnackBar(
          context,
          SnackBar(
              content: const Text('这个感觉已经在啦。'),
              duration: AppMotion.snackbar,
              behavior: SnackBarBehavior.floating));
      return;
    }
    try {
      final newEmotion =
          await ref.read(emotionsProvider.notifier).addCustom(name);
      setState(() {
        _emotions.add(newEmotion);
        _newCtrl.clear();
      });
    } catch (_) {
      if (mounted) {
        showOverlaySnackBar(
            context,
            SnackBar(
                content: const Text('新增失败，请稍后再试。'),
                duration: AppMotion.snackbar,
                behavior: SnackBarBehavior.floating));
      }
    }
  }
}

class _MoreChip extends StatelessWidget {
  const _MoreChip({
    required this.emotion,
    required this.isSelected,
    required this.onTap,
  });

  final UserEmotion emotion;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final bgColor = isSelected
        ? emotion.color.withValues(alpha: theme.isNight ? .2 : .14)
        : theme.surface.withValues(alpha: .48);
    final borderColor = isSelected
        ? emotion.color.withValues(alpha: .72)
        : theme.border.withValues(alpha: .8);
    final textColor = isSelected ? theme.foreground : theme.foregroundMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: borderColor, width: isSelected ? 1.1 : .85),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: emotion.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.s5),
          Expanded(
            child: Text(
              emotion.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.chip.copyWith(color: textColor, height: 1.08),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, size: 15, color: emotion.color),
        ]),
      ),
    );
  }
}
