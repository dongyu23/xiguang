import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_bottom_sheet.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_input.dart';
import '../../application/relation_types_controller.dart';
import '../../domain/relation_type_color.dart';
import '../../domain/user_relation_type.dart';

class RelationTypeEditSheet extends ConsumerStatefulWidget {
  const RelationTypeEditSheet({super.key, required this.existing});

  final UserRelationType? existing;

  @override
  ConsumerState<RelationTypeEditSheet> createState() =>
      _RelationTypeEditSheetState();
}

class _RelationTypeEditSheetState extends ConsumerState<RelationTypeEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _iconKey;

  @override
  void initState() {
    super.initState();
    final type = widget.existing;
    _nameController = TextEditingController(text: type?.name ?? '');
    _descriptionController =
        TextEditingController(text: type?.description ?? '');
    _iconKey = type?.iconKey ?? 'auto_awesome_rounded';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final saving = ref.watch(relationTypesProvider).isLoading;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final maxSheetHeight =
        mediaQuery.size.height - bottomInset - mediaQuery.padding.top - AppSpacing.md;
    final isEdit = widget.existing != null;
    return AnimatedPadding(
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: XiguangBottomSheet(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _dismissKeyboard,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(isEdit ? '编辑织线类型' : '新增织线类型',
                        style: AppText.titleLarge
                            .copyWith(color: theme.foreground)),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    icon:
                        Icon(Icons.close_rounded, color: theme.foregroundMuted),
                    onPressed: _close,
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: _buildForm(theme),
                  ),
                ),
                const SizedBox(height: AppSpacing.s14),
                Divider(height: 1, color: theme.border),
                const SizedBox(height: AppSpacing.s14),
                XiguangButton(
                  label: saving ? '保存中…' : '保存',
                  loading: saving,
                  leading: const Icon(Icons.check_rounded, size: 18),
                  onPressed: saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(NightTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        XiguangInput(
          controller: _nameController,
          maxLength: 8,
          autofocus: widget.existing == null,
          textInputAction: TextInputAction.next,
          label: '类型名字',
          hint: '例如：未完待续',
        ),
        const SizedBox(height: AppSpacing.s6),
        XiguangInput(
          controller: _descriptionController,
          maxLength: 30,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _dismissKeyboard(),
          label: '一句话描述（可选）',
          hint: '这种联系是…',
        ),
        const SizedBox(height: AppSpacing.md),
        Text('图标',
            style: AppText.caption.copyWith(color: theme.foregroundMuted)),
        const SizedBox(height: AppSpacing.s6),
        Wrap(
          spacing: AppSpacing.s6,
          runSpacing: AppSpacing.s6,
          children: relationTypeIconOptions.map((entry) {
            final (key, icon) = entry;
            final selected = _iconKey == key;
            return GestureDetector(
              onTap: () {
                _dismissKeyboard();
                setState(() => _iconKey = key);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.accent.withValues(alpha: theme.isNight ? .22 : .14)
                      : theme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? theme.accent : theme.border,
                    width: selected ? 1.8 : 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? theme.accent : theme.foregroundMuted,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _save() async {
    _dismissKeyboard();
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('类型名字不能为空。');
      return;
    }
    try {
      final description = _descriptionController.text.trim();
      if (widget.existing == null) {
        final types = ref.read(relationTypesProvider).valueOrNull ??
            const <UserRelationType>[];
        final shownCount = types.where((t) => !t.hidden).length;
        final newType = await ref.read(relationTypesProvider.notifier).addCustom(
              name,
              description: description,
              iconKey: _iconKey,
            );
        // 展示已达上限时，新增项先收起，避免超过 maxShownRelationTypes
        if (shownCount >= maxShownRelationTypes) {
          await ref.read(relationTypesProvider.notifier).toggleHidden(newType);
          _showMessage('已添加。展示已满 $maxShownRelationTypes 个，已先收起。');
        }
      } else {
        await ref.read(relationTypesProvider.notifier).save(
              existing: widget.existing!,
              name: name,
              iconKey: _iconKey,
              description: description,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } on DuplicateRelationTypeNameException {
      _showMessage('这个名字已经存在啦。');
    } catch (_) {
      _showMessage('保存失败，请稍后再试。');
    }
  }

  void _close() {
    _dismissKeyboard();
    Navigator.of(context).pop();
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }
}
