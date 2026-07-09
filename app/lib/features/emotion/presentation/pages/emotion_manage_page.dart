import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/primitives/night_background.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../data/emotion_repository.dart';
import '../../domain/user_emotion.dart';

/// 管理心情 — 增删改查用户的微光情绪。
///
/// 默认 7 个情绪可编辑（名/色/描述）但不可删除；自定义情绪可增删改。
/// 这是「我的」页的工具栏入口。捕光选择器里的"更多"sheet 只做选择+新增。
class EmotionManagePage extends ConsumerStatefulWidget {
  const EmotionManagePage({super.key});

  @override
  ConsumerState<EmotionManagePage> createState() => _EmotionManagePageState();
}

class _EmotionManagePageState extends ConsumerState<EmotionManagePage> {
  @override
  Widget build(BuildContext context) {
    final nightMode = ref.watch(nightModeProvider);
    final emotionsAsync = ref.watch(emotionsProvider);
    return Stack(children: [
      const Positioned.fill(child: NightBackgroundPlaceholder()),
      Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s22, AppSpacing.s10, AppSpacing.s22, 0),
                child: Row(children: [
                  PageBackButton(
                    onTap: () => Navigator.of(context).maybePop(),
                    nightMode: nightMode,
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text('管理心情',
                        style:
                            AppText.onNight(AppText.titleLarge, nightMode)),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showEditSheet(null, nightMode),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('新增'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s12),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: emotionsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text('暂时读不到心情，请稍后再试。',
                          style: AppText.onNight(AppText.body, nightMode)),
                    ),
                  ),
                  data: (emotions) => emotions.isEmpty
                      ? Center(
                          child: Text('还没有心情。点右上"新增"加一个。',
                              style:
                                  AppText.onNight(AppText.body, nightMode)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.s22,
                              0, AppSpacing.s22, AppSpacing.pageBottomNav),
                          itemCount: emotions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.s6),
                          itemBuilder: (context, index) {
                            final e = emotions[index];
                            return _EmotionRow(
                              emotion: e,
                              nightMode: nightMode,
                              onEdit: () => _showEditSheet(e, nightMode),
                              onDelete: e.isDefault
                                  ? null
                                  : () => _confirmDelete(e, nightMode),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Future<void> _showEditSheet(UserEmotion? existing, bool nightMode) async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      enableDrag: false, // 含 TextField，禁拖关防黑屏
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmotionEditSheet(
        existing: existing,
        nightMode: nightMode,
      ),
    );
    // 编辑/新增后刷新列表
    if (mounted) ref.invalidate(emotionsProvider);
  }

  Future<void> _confirmDelete(UserEmotion emotion, bool nightMode) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除心情'),
        content: Text('删除「${emotion.name}」后，已用它记录的光片仍保留原文字，'
            '只是选择器不再显示这个心情。确定删除吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sunsetCoral,
              foregroundColor: AppColors.white,
            ),
            child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(emotionRepositoryProvider).delete(emotion.id);
    if (mounted) ref.invalidate(emotionsProvider);
  }
}

class _EmotionRow extends StatelessWidget {
  const _EmotionRow({
    required this.emotion,
    required this.nightMode,
    required this.onEdit,
    required this.onDelete,
  });

  final UserEmotion emotion;
  final bool nightMode;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
          decoration: nightMode
              ? nightDecoration()
              : softDecoration(AppColors.white),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: emotion.color.withValues(alpha: .30),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: emotion.color, width: 1.2),
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration:
                      BoxDecoration(color: emotion.color, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(emotion.name,
                        style:
                            AppText.onNight(AppText.titleSmall, nightMode)),
                    if (emotion.isDefault) ...[
                      const SizedBox(width: AppSpacing.s6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.inkMuted.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text('默认',
                            style: AppText.microLabel.copyWith(
                                color: nightMode
                                    ? AppText.nightInkMuted
                                    : AppColors.inkMuted)),
                      ),
                    ],
                  ]),
                  if (emotion.description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s2),
                    Text(emotion.description,
                        style:
                            AppText.onNight(AppText.caption, nightMode)),
                  ],
                ],
              ),
            ),
            Icon(Icons.edit_outlined,
                size: 18,
                color: nightMode ? AppText.nightInkMuted : AppColors.inkMuted),
            if (onDelete != null) ...[
              const SizedBox(width: AppSpacing.s6),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.sunsetCoral),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// 新增/编辑情绪 sheet — 名字 + 描述 + 颜色（默认情绪可改色，自定义色自动分配但可覆盖）
class _EmotionEditSheet extends ConsumerStatefulWidget {
  const _EmotionEditSheet({required this.existing, required this.nightMode});

  final UserEmotion? existing; // null = 新增
  final bool nightMode;

  @override
  ConsumerState<_EmotionEditSheet> createState() => _EmotionEditSheetState();
}

class _EmotionEditSheetState extends ConsumerState<_EmotionEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late Color _color;
  bool _saving = false;
  bool _sheetDisposed = false;

  // 可选莫兰迪色板
  static const _palette = <int>[
    0xFF72A58F, 0xFF9EBBCC, 0xFFE9A18B, 0xFFD9CCE8,
    0xFFF0C78E, 0xFFC4C4C4, 0xFFE8B88A, 0xFFB8C5B2,
    0xFFC9B8D4, 0xFFD4C5B8, 0xFFB8C9D4, 0xFFD4B8C0,
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _color = e?.color ?? autoColorForName('');
  }

  @override
  void dispose() {
    _sheetDisposed = true;
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (_sheetDisposed || !mounted) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final nightMode = widget.nightMode;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isEdit = widget.existing != null;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
            AppSpacing.lg + bottomInset),
        decoration:
            nightMode ? nightDecoration() : softDecoration(AppColors.white),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(isEdit ? '编辑心情' : '新增心情',
                      style:
                          AppText.onNight(AppText.titleLarge, nightMode)),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: nightMode
                          ? AppText.nightInkMuted
                          : AppColors.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _nameCtrl,
                maxLength: 8,
                autofocus: !isEdit,
                decoration: const InputDecoration(
                  labelText: '心情名字',
                  hintText: '例如：释怀',
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              TextField(
                controller: _descCtrl,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: '一句话描述（可选）',
                  hintText: '这种感觉是…',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('颜色', style: AppText.onNight(AppText.caption, nightMode)),
              const SizedBox(height: AppSpacing.s6),
              Wrap(
                spacing: AppSpacing.s6,
                runSpacing: AppSpacing.s6,
                children: _palette.map((c) {
                  final color = Color(c);
                  final selected = _color.toARGB32() == c;
                  return GestureDetector(
                    onTap: () => _safeSetState(() => _color = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.ink
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(_saving ? '保存中…' : '保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _safeSetState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('心情名字不能为空。'),
              behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    _safeSetState(() => _saving = true);
    try {
      final repo = ref.read(emotionRepositoryProvider);
      final all = await repo.getAll();
      final dup = all.any((e) =>
          e.name == name && e.id != widget.existing?.id);
      if (dup) {
        _safeSetState(() => _saving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('这个名字已经存在啦。'),
                behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }
      final desc = _descCtrl.text.trim();
      if (widget.existing == null) {
        await repo.addCustom(name, description: desc);
      } else {
        await repo.update(widget.existing!.copyWith(
          name: name,
          color: _color,
          description: desc,
        ));
      }
      if (!_sheetDisposed && mounted) Navigator.of(context).pop();
    } catch (_) {
      _safeSetState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('保存失败，请稍后再试。'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
