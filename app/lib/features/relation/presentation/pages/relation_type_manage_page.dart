// PAGE_SIZE_EXEMPT: 列表+操作菜单的编排集中在一页，行组件已拆到 widgets。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_bottom_sheet.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../application/relation_types_controller.dart';
import '../../domain/relation_type_color.dart';
import '../../domain/user_relation_type.dart';
import '../widgets/relation_type_edit_sheet.dart';

enum _RelationTypeAction { edit, hide, show, delete }

class RelationTypeManagePage extends ConsumerWidget {
  const RelationTypeManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(relationTypesProvider);
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
                child: Text('管理织线类型',
                    style:
                        AppText.titleLarge.copyWith(color: theme.foreground)),
              ),
              XiguangButton(
                label: '添加类型',
                expand: false,
                height: 40,
                onPressed: () => _showEditSheet(context, null),
                leading: const Icon(Icons.add_rounded, size: 18),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: types.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                  child: XiguangEmptyState(
                    title: '暂时读不到类型',
                    description: '请稍后再试，已有的织线不会受到影响。',
                    icon: Icons.cloud_off_outlined,
                  ),
                ),
                data: (items) => items.isEmpty
                    ? const Center(
                        child: XiguangEmptyState(
                          title: '还没有织线类型',
                          description: '点右上角"添加类型"，写一个自己的联系。',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(
                            bottom: AppSpacing.pageBottomNav),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.s6),
                        itemBuilder: (context, index) {
                          final type = items[index];
                          return _RelationTypeRow(
                            type: type,
                            onEdit: () => _showEditSheet(context, type),
                            onLongPress: () =>
                                _showActionSheet(context, ref, type),
                            onDelete: type.isDefault
                                ? null
                                : () => _confirmDelete(context, ref, type),
                            onToggleHidden: () => ref
                                .read(relationTypesProvider.notifier)
                                .setHidden(type.id, !type.hidden),
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

  Future<void> _showActionSheet(
    BuildContext context,
    WidgetRef ref,
    UserRelationType type,
  ) async {
    final theme = NightTheme.of(context);
    final action = await showModalBottomSheet<_RelationTypeAction>(
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
                Text(type.name,
                    style:
                        AppText.titleLarge.copyWith(color: theme.foreground)),
                const SizedBox(height: AppSpacing.md),
                _ActionTile(
                  icon: Icons.edit_outlined,
                  label: '编辑',
                  onTap: () => Navigator.of(ctx).pop(_RelationTypeAction.edit),
                ),
                _ActionTile(
                  icon: type.hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  label: type.hidden ? '在选择器展示' : '在选择器收起',
                  onTap: () => Navigator.of(ctx).pop(type.hidden
                      ? _RelationTypeAction.show
                      : _RelationTypeAction.hide),
                ),
                if (!type.isDefault)
                  _ActionTile(
                    icon: Icons.delete_outline_rounded,
                    label: '删除',
                    color: theme.danger,
                    onTap: () =>
                        Navigator.of(ctx).pop(_RelationTypeAction.delete),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _RelationTypeAction.edit:
        _showEditSheet(context, type);
      case _RelationTypeAction.hide:
      case _RelationTypeAction.show:
        await ref
            .read(relationTypesProvider.notifier)
            .setHidden(type.id, !type.hidden);
      case _RelationTypeAction.delete:
        _confirmDelete(context, ref, type);
    }
  }

  Future<void> _showEditSheet(
    BuildContext context,
    UserRelationType? existing,
  ) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => RelationTypeEditSheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    UserRelationType type,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除织线类型'),
        content: Text('删除「${type.name}」后，已用它织的线仍保留原文字，'
            '只是选择器不再显示这个类型。确定删除吗？'),
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
      await ref.read(relationTypesProvider.notifier).delete(type.id);
    }
  }
}

class _RelationTypeRow extends StatelessWidget {
  const _RelationTypeRow({
    required this.type,
    required this.onEdit,
    required this.onLongPress,
    required this.onDelete,
    required this.onToggleHidden,
  });

  final UserRelationType type;
  final VoidCallback onEdit;
  final VoidCallback onLongPress;
  final VoidCallback? onDelete;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Opacity(
      opacity: type.hidden ? 0.5 : 1.0,
      child: Material(
        color: theme.surface.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onEdit,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s10,
            ),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: .22),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconForRelationType(type.iconKey),
                  size: 16,
                  color: type.color,
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.titleSmall
                            .copyWith(color: theme.foreground)),
                    if (type.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s2),
                        child: Text(type.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption
                                .copyWith(color: theme.foregroundMuted)),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: type.hidden ? '展示' : '收起',
                icon: Icon(
                  type.hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: theme.foregroundMuted,
                ),
                onPressed: onToggleHidden,
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: '删除',
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.sunsetCoral),
                  onPressed: onDelete,
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

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
    return ListTile(
      leading: Icon(icon, color: color ?? theme.foreground, size: 20),
      title: Text(label,
          style: AppText.body.copyWith(color: color ?? theme.foreground)),
      onTap: onTap,
    );
  }
}
