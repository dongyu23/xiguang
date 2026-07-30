import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/relation_types_controller.dart';
import '../../domain/relation_type_color.dart';
import '../../domain/user_relation_type.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/composites/relation_type_more_sheet.dart';
import '../../../../ui/primitives/overlay_snackbar.dart';

/// 织线类型选择器 - 柔和色点 + 类型名。
///
/// 与 [EmotionPicker] 同构：显示前 7 个类型 + 第 9 个"更多"按钮。
/// 点"更多"打开滚动列表，可勾选展示/收起、在底部新增自定义类型。
/// 增删改查完整功能在「我的 -> 管理织线类型」工具栏。
///
/// 选中值存类型 name（如"回声"），与情绪选择器一致；后端 relation_type
/// 列为 TEXT，直接存 name。
class RelationTypePicker extends ConsumerStatefulWidget {
  const RelationTypePicker({
    super.key,
    required this.onSelected,
    this.selectedType = '',
  });

  final ValueChanged<String> onSelected;

  /// 当前选中的类型名；空串表示未选，首屏会自动选中第一个可见类型。
  final String selectedType;

  @override
  ConsumerState<RelationTypePicker> createState() => _RelationTypePickerState();
}

class _RelationTypePickerState extends ConsumerState<RelationTypePicker> {
  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final typesAsync = ref.watch(relationTypesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        typesAsync.when(
          loading: () => _grid(_fallbackTypes(), theme),
          error: (_, __) => _grid(_fallbackTypes(), theme),
          data: (types) =>
              _grid(types.isEmpty ? _fallbackTypes() : types, theme),
        ),
      ],
    );
  }

  /// 降级用：DB 未就绪时显示静态默认类型，保证选择器不空。
  List<UserRelationType> _fallbackTypes() {
    const defaults = <(String, Color, String, String)>[
      ('回声', AppColors.relationEcho, '一束光在另一束里轻轻回应。', 'auto_awesome_rounded'),
      (
        '伏笔',
        AppColors.relationForeshadow,
        '更早的那束，原来早就埋下了线索。',
        'edit_note_rounded'
      ),
      (
        '余震',
        AppColors.relationAftershock,
        '情绪还在继续，没有马上过去。',
        'trip_origin_rounded'
      ),
      ('平行宇宙', AppColors.relationParallel, '同时存在的另一种可能。', 'grain_rounded'),
      ('小小救命', AppColors.relationRescue, '那一次被接住了。', 'favorite_border_rounded'),
      ('潮汐', AppColors.relationTide, '来来去去，有自己的节律。', 'waves_rounded'),
      ('旧光', AppColors.relationOldLight, '很久以前的，又被想起。', 'circle_rounded'),
    ];
    return defaults
        .map((e) => UserRelationType(
              id: -1,
              name: e.$1,
              color: e.$2,
              iconKey: e.$4,
              description: e.$3,
              isDefault: true,
              sortOrder: 0,
            ))
        .toList();
  }

  Widget _grid(List<UserRelationType> types, NightTheme theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        // 首屏保持 3×3 区域：前 7 个 + "更多"。若当前选中不在前 7 个，替换末位。
        final shown = types.where((t) => !t.hidden).toList();
        final visible = shown.take(maxShownRelationTypes).toList();
        UserRelationType? selectedType;
        for (final type in types) {
          if (type.name == widget.selectedType) {
            selectedType = type;
            break;
          }
        }
        final resolvedSelection = selectedType;
        if (resolvedSelection != null &&
            !visible.any((t) => t.name == resolvedSelection.name)) {
          if (visible.length == maxShownRelationTypes) {
            visible[maxShownRelationTypes - 1] = resolvedSelection;
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
            crossAxisCount: 3,
            mainAxisSpacing: compact ? 6 : AppSpacing.sm,
            crossAxisSpacing: compact ? 6 : AppSpacing.sm,
            mainAxisExtent: 40,
          ),
          itemBuilder: (context, index) {
            if (index < visible.length) {
              final type = visible[index];
              return _RelationChip(
                label: type.name,
                color: type.color,
                icon: iconForRelationType(type.iconKey),
                hint: type.description,
                isSelected: widget.selectedType == type.name,
                compact: compact,
                onTap: () => widget.onSelected(type.name),
              );
            }
            // 最后一格：更多
            return _RelationChip(
              label: '更多',
              color: AppColors.inkMuted,
              icon: Icons.more_horiz_rounded,
              hint: '查看全部类型或新增',
              isSelected: false,
              compact: compact,
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
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RelationTypeMoreSheet(
        selected: widget.selectedType,
        onSelected: (name) {
          if (mounted) widget.onSelected(name);
        },
      ),
    );
  }
}

class _RelationChip extends StatelessWidget {
  const _RelationChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.hint,
    required this.isSelected,
    required this.compact,
    required this.onTap,
    this.isMore = false,
  });

  final String label;
  final Color color;
  final IconData icon;
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
        curve: AppMotion.easeOut,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.s5 : AppSpacing.s7,
            vertical: AppSpacing.s5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.1 : .85,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSelected ? .78 : .34),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.white : theme.foregroundMuted,
                size: 11,
              ),
            ),
            SizedBox(width: compact ? AppSpacing.xs : AppSpacing.s6),
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
