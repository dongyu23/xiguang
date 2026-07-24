import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/emotion/application/emotions_controller.dart';
import '../../../features/emotion/domain/user_emotion.dart';
import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/colors.dart';
import '../../design/tokens/motion.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/typography.dart';
import '../../design/tokens/spacing.dart';
import 'emotion_more_sheet.dart';
import '../primitives/overlay_snackbar.dart';

/// 微光情绪选择器 — 柔和色点 + 情绪词
///
/// 显示前 8 个情绪 + 第 9 个"更多"按钮。点"更多"打开滚动列表，
/// 可选全部情绪或在列表底部新增自定义情绪（只新增，不编辑/删除）。
/// 增删改查完整功能在「我的 → 管理心情」工具栏。
class EmotionPicker extends ConsumerStatefulWidget {
  const EmotionPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.dense = false,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final bool dense;

  @override
  ConsumerState<EmotionPicker> createState() => _EmotionPickerState();
}

class _EmotionPickerState extends ConsumerState<EmotionPicker> {
  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final emotionsAsync = ref.watch(emotionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('心绪收录',
            style: AppText.titleSmall.copyWith(color: theme.foreground)),
        SizedBox(height: widget.dense ? AppSpacing.s7 : AppSpacing.s10),
        emotionsAsync.when(
          loading: () => _grid(_fallbackEmotions()),
          error: (_, __) => _grid(_fallbackEmotions()),
          data: (emotions) => _grid(emotions),
        ),
      ],
    );
  }

  /// 降级用：DB 未就绪时显示静态默认情绪，保证选择器不空。
  List<UserEmotion> _fallbackEmotions() {
    const defaults = <(String, Color, String)>[
      ('平静', AppColors.emotionCalm, '内心安静，没有波澜'),
      ('开心', AppColors.emotionHappy, '有一点点想笑'),
      ('疲惫', AppColors.emotionTired, '身体或心里有点累'),
      ('焦虑', AppColors.emotionAnxious, '心悬着，不太安稳'),
      ('失落', AppColors.emotionLost, '空空的，说不上来'),
      ('被击中', AppColors.emotionStruck, '被什么触动了'),
      ('混乱', AppColors.emotionChaos, '一团乱，理不清楚'),
      ('说不清', AppColors.emotionUnclear, '暂时不需要说清楚'),
    ];
    return defaults
        .map((e) => UserEmotion(
              id: -1,
              name: e.$1,
              color: e.$2,
              description: e.$3,
              isDefault: true,
              sortOrder: 0,
            ))
        .toList();
  }

  Widget _grid(List<UserEmotion> emotions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final dense = widget.dense;
        // 首屏保持 4×2；若当前选项不在前 7 个，用它替换末位，避免选中态消失。
        final shown = emotions.where((e) => !e.hidden).toList();
        final visible = shown.take(7).toList();
        UserEmotion? selectedEmotion;
        for (final emotion in emotions) {
          if (emotion.name == widget.selected) {
            selectedEmotion = emotion;
            break;
          }
        }
        final resolvedSelection = selectedEmotion;
        if (resolvedSelection != null &&
            !visible.any((emotion) => emotion.name == resolvedSelection.name)) {
          if (visible.length == 7) {
            visible[6] = resolvedSelection;
          } else {
            visible.add(resolvedSelection);
          }
        }
        final itemCount = visible.length + 1; // +1 更多
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: dense ? 6 : 8,
            crossAxisSpacing: dense ? 6 : (compact ? 7 : 9),
            mainAxisExtent: dense ? 34 : (compact ? 36 : 40),
          ),
          itemBuilder: (context, index) {
            if (index < visible.length) {
              final emotion = visible[index];
              return _EmotionChip(
                label: emotion.name,
                color: emotion.color,
                hint: emotion.description,
                isSelected: widget.selected == emotion.name,
                compact: compact || dense,
                onTap: () => widget.onSelected(emotion.name),
              );
            }
            // 最后一格：更多
            return _EmotionChip(
              label: '更多',
              color: AppColors.inkMuted,
              hint: '查看全部情绪或新增',
              isSelected: false,
              compact: compact || dense,
              isMore: true,
              onTap: _openMore,
            );
          },
        );
      },
    );
  }

  void _openMore() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EmotionMoreSheet(
        selected: widget.selected,
        onSelected: (name) {
          if (mounted) widget.onSelected(name);
        },
      ),
    );
  }
}

class _EmotionChip extends StatelessWidget {
  const _EmotionChip({
    required this.label,
    required this.color,
    required this.hint,
    required this.isSelected,
    required this.compact,
    required this.onTap,
    this.isMore = false,
  });

  final String label;
  final Color color;
  final String hint;
  final bool isSelected;
  final bool compact;
  final bool isMore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final bgColor = isSelected
        ? color.withValues(alpha: theme.isNight ? .22 : .16)
        : theme.surface.withValues(alpha: .5);
    final borderColor =
        isSelected ? color.withValues(alpha: .72) : theme.border;
    final textColor = isSelected ? theme.foreground : theme.foregroundMuted;
    final dotColor = color;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: () {
        showOverlaySnackBar(
          context,
          SnackBar(
              content: Text(hint),
              duration: AppMotion.snackbar,
              behavior: SnackBarBehavior.floating),
        );
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.s5 : AppSpacing.s7,
            vertical: AppSpacing.s5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.1 : .85,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMore)
              Icon(Icons.more_horiz_rounded,
                  size: compact ? 13 : 14, color: dotColor)
            else
              Container(
                width: compact ? 7 : 8,
                height: compact ? 7 : 8,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
            SizedBox(width: compact ? AppSpacing.xs : AppSpacing.s5),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: AppText.chip.copyWith(
                    color: textColor,
                    height: 1.08,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
