import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/emotion/data/emotion_repository.dart';
import '../../../features/emotion/domain/user_emotion.dart';
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
    this.nightMode = false,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final bool dense;
  final bool nightMode;

  @override
  ConsumerState<EmotionPicker> createState() => _EmotionPickerState();
}

class _EmotionPickerState extends ConsumerState<EmotionPicker> {
  @override
  Widget build(BuildContext context) {
    final emotionsAsync = ref.watch(emotionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('心绪收录',
            style: AppText.onNight(AppText.titleSmall, widget.nightMode)),
        SizedBox(height: widget.dense ? AppSpacing.s7 : AppSpacing.s10),
        emotionsAsync.when(
          loading: () => _grid(_fallbackEmotions(), null),
          error: (_, __) => _grid(_fallbackEmotions(), null),
          data: (emotions) => _grid(emotions, emotions),
        ),
      ],
    );
  }

  /// 降级用：DB 未就绪时显示静态 7 个默认情绪，保证选择器不空。
  List<UserEmotion> _fallbackEmotions() {
    const defaults = <(String, int, String)>[
      ('平静', 0xFF72A58F, '内心安静，没有波澜'),
      ('开心', 0xFFF0C78E, '有一点点想笑'),
      ('疲惫', 0xFF9EBBCC, '身体或心里有点累'),
      ('焦虑', 0xFFE9A18B, '心悬着，不太安稳'),
      ('失落', 0xFFC4C4C4, '空空的，说不上来'),
      ('被击中', 0xFFE8B88A, '被什么触动了'),
      ('混乱', 0xFFD9CCE8, '一团乱，理不清楚'),
    ];
    return defaults
        .map((e) => UserEmotion(
              id: -1,
              name: e.$1,
              color: Color(e.$2),
              description: e.$3,
              isDefault: true,
              sortOrder: 0,
            ))
        .toList();
  }

  Widget _grid(List<UserEmotion> emotions, List<UserEmotion>? fullList) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final dense = widget.dense;
        // 前 8 个情绪 + 第 9 个"更多"按钮
        final visible = emotions.take(8).toList();
        final itemCount = visible.length + 1; // +1 更多
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: dense ? 6 : (compact ? 7 : 8),
            crossAxisSpacing: dense ? 7 : (compact ? 7 : 9),
            mainAxisExtent: dense ? 36 : (compact ? 40 : 42),
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
                nightMode: widget.nightMode,
                onTap: () => widget.onSelected(emotion.name),
              );
            }
            // 第 9 个：更多
            return _EmotionChip(
              label: '更多',
              color: AppColors.inkMuted,
              hint: '查看全部情绪或新增',
              isSelected: false,
              compact: compact || dense,
              nightMode: widget.nightMode,
              isMore: true,
              onTap: () => _openMore(fullList ?? emotions),
            );
          },
        );
      },
    );
  }

  void _openMore(List<UserEmotion> all) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EmotionMoreSheet(
        emotions: all,
        selected: widget.selected,
        nightMode: widget.nightMode,
      ),
    );
    if (picked != null && mounted) {
      widget.onSelected(picked);
      ref.invalidate(emotionsProvider);
    }
  }
}

class _EmotionChip extends StatelessWidget {
  const _EmotionChip({
    required this.label,
    required this.color,
    required this.hint,
    required this.isSelected,
    required this.compact,
    required this.nightMode,
    required this.onTap,
    this.isMore = false,
  });

  final String label;
  final Color color;
  final String hint;
  final bool isSelected;
  final bool compact;
  final bool nightMode;
  final bool isMore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? color.withValues(alpha: .88)
        : nightMode
            ? AppColors.white.withValues(alpha: .07)
            : AppColors.white.withValues(alpha: .72);
    final borderColor = isSelected
        ? color
        : nightMode
            ? AppColors.white.withValues(alpha: .12)
            : AppColors.line;
    final textColor = isSelected
        ? Colors.white
        : nightMode
            ? AppText.nightInk
            : AppColors.ink;
    final dotColor = isSelected ? Colors.white : color;

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
