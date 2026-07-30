import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/relation/application/relation_types_controller.dart';
import '../../features/relation/domain/user_relation_type.dart';
import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/colors.dart';
import '../../design/tokens/motion.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/typography.dart';
import '../../design/tokens/spacing.dart';
import '../primitives/overlay_snackbar.dart';
import 'xiguang_bottom_sheet.dart';

/// "更多"织线类型配置 sheet - 勾选要在织线页展示的类型 + 底部"新增自定义"。
///
/// 与 [EmotionMoreSheet] 同构：勾选展示/收起、新增自定义、当收起当前选中项时自动改选。
/// 编辑/删除在「我的 -> 管理织线类型」工具栏。
class RelationTypeMoreSheet extends ConsumerStatefulWidget {
  const RelationTypeMoreSheet({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// 当前选中的类型名；收起它时需要自动改选。
  final String selected;

  /// 当当前选中项被收起、需要切换到另一个类型时回调。
  final ValueChanged<String> onSelected;

  @override
  ConsumerState<RelationTypeMoreSheet> createState() =>
      _RelationTypeMoreSheetState();
}

class _RelationTypeMoreSheetState extends ConsumerState<RelationTypeMoreSheet> {
  final _newCtrl = TextEditingController();

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final async = ref.watch(relationTypesProvider);
    final types = async.valueOrNull ?? const <UserRelationType>[];
    final adding = async.isLoading;
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
                      Text('更多织线类型',
                          style: AppText.titleLarge
                              .copyWith(color: theme.foreground)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '勾选要在织线页展示的类型，最多 $maxShownRelationTypes 个。',
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
                child: types.isEmpty && adding
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: types.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 44,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                        ),
                        itemBuilder: (context, index) {
                          final type = types[index];
                          return _MoreChip(
                            type: type,
                            isShown: !type.hidden,
                            onTap: () => _toggleShow(type, types),
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppSpacing.s14),
              Divider(height: 1, color: theme.border.withValues(alpha: .72)),
              const SizedBox(height: AppSpacing.s14),
              Text('给这条线一个自己的名字',
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
                  hintText: '例如：未完待续',
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: IconButton.filled(
                      tooltip: '新增类型',
                      onPressed: adding ? null : _addCustom,
                      style: IconButton.styleFrom(
                        backgroundColor: theme.foreground,
                        foregroundColor:
                            theme.isNight ? theme.background : AppColors.white,
                      ),
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

  /// 切换某个类型的展示/收起状态，带 max-7 / min-1 约束。
  Future<void> _toggleShow(
      UserRelationType type, List<UserRelationType> all) async {
    final shownCount = all.where((t) => !t.hidden).length;
    if (!type.hidden) {
      // 收起
      if (shownCount <= 1) {
        _toast('至少保留一个展示的类型。');
        return;
      }
      // 收起的若正是当前选中项，先改选到另一个仍展示的类型
      if (type.name == widget.selected) {
        final next = all.firstWhere(
          (t) => !t.hidden && t.id != type.id,
          orElse: () => type,
        );
        if (next.id != type.id) {
          widget.onSelected(next.name);
        }
      }
    } else {
      // 展示
      if (shownCount >= maxShownRelationTypes) {
        _toast('最多展示 $maxShownRelationTypes 个类型，请先取消其他。');
        return;
      }
    }
    await ref.read(relationTypesProvider.notifier).toggleHidden(type);
  }

  Future<void> _addCustom() async {
    final name = _newCtrl.text.trim();
    if (name.isEmpty) {
      _toast('先写一个类型的名字。');
      return;
    }
    final types = ref.read(relationTypesProvider).valueOrNull ?? const [];
    if (types.any((t) => t.name == name)) {
      _toast('这个类型已经在啦。');
      return;
    }
    try {
      final newType =
          await ref.read(relationTypesProvider.notifier).addCustom(name);
      // 展示已达上限时，新增项先收起，避免超过 maxShownRelationTypes
      final shownCount = types.where((t) => !t.hidden).length;
      if (shownCount >= maxShownRelationTypes) {
        await ref.read(relationTypesProvider.notifier).toggleHidden(newType);
        _toast('已添加。展示已满 $maxShownRelationTypes 个，已先收起，勾选即可展示。');
      }
      _newCtrl.clear();
    } catch (_) {
      if (mounted) {
        _toast('新增失败，请稍后再试。');
      }
    }
  }

  void _toast(String msg) {
    showOverlaySnackBar(
      context,
      SnackBar(
        content: Text(msg),
        duration: AppMotion.snackbar,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _MoreChip extends StatelessWidget {
  const _MoreChip({
    required this.type,
    required this.isShown,
    required this.onTap,
  });

  final UserRelationType type;
  final bool isShown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final bgColor = isShown
        ? type.color.withValues(alpha: theme.isNight ? .2 : .14)
        : theme.surface.withValues(alpha: .32);
    final borderColor = isShown
        ? type.color.withValues(alpha: .72)
        : theme.border.withValues(alpha: .6);
    final textColor = isShown ? theme.foreground : theme.foregroundMuted;
    return Opacity(
      opacity: isShown ? 1 : .55,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: borderColor, width: isShown ? 1.1 : .85),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: type.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.s5),
            Expanded(
              child: Text(
                type.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.chip.copyWith(color: textColor, height: 1.08),
              ),
            ),
            if (isShown) Icon(Icons.check_rounded, size: 15, color: type.color),
          ]),
        ),
      ),
    );
  }
}
