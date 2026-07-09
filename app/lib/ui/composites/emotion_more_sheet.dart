import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/emotion/data/emotion_repository.dart';
import '../../../features/emotion/domain/user_emotion.dart';
import '../../design/tokens/colors.dart';
import '../../design/tokens/motion.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/shadows.dart';
import '../../design/tokens/typography.dart';
import '../../design/tokens/spacing.dart';
import '../primitives/overlay_snackbar.dart';

/// "更多"情绪选择 sheet — 可滚动的全部情绪列表 + 底部"新增自定义"。
///
/// 只做"选择"和"新增"两件事。编辑/删除在「我的 → 管理心情」工具栏。
class EmotionMoreSheet extends ConsumerStatefulWidget {
  const EmotionMoreSheet({
    super.key,
    required this.emotions,
    required this.selected,
    required this.nightMode,
  });

  final List<UserEmotion> emotions;
  final String selected;
  final bool nightMode;

  @override
  ConsumerState<EmotionMoreSheet> createState() => _EmotionMoreSheetState();
}

class _EmotionMoreSheetState extends ConsumerState<EmotionMoreSheet> {
  late List<UserEmotion> _emotions;
  final _newCtrl = TextEditingController();
  bool _adding = false;

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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + bottomInset),
        decoration: widget.nightMode
            ? nightDecoration()
            : softDecoration(AppColors.white),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('更多心绪',
                    style:
                        AppText.onNight(AppText.titleLarge, widget.nightMode)),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: widget.nightMode
                        ? AppText.nightInkMuted
                        : AppColors.inkMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            // 用明确高度避免 Flexible 在 min Column 里塌缩到 0
            SizedBox(
              height: 240,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: AppSpacing.s6,
                  runSpacing: AppSpacing.s6,
                  children: _emotions
                      .map((e) => _MoreChip(
                            emotion: e,
                            isSelected: widget.selected == e.name,
                            nightMode: widget.nightMode,
                            onTap: () => Navigator.of(context).pop(e.name),
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // 新增自定义 — 只新增，不编辑/删除
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _newCtrl,
                  maxLength: 8,
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '写一个自己的感觉',
                    prefixIcon: Icon(Icons.add_rounded, size: 18),
                  ),
                  onSubmitted: (_) => _addCustom(),
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              FilledButton(
                onPressed: _adding ? null : _addCustom,
                child: const Text('新增'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _addCustom() async {
    final name = _newCtrl.text.trim();
    if (name.isEmpty) {
      showOverlaySnackBar(context,
          SnackBar(content: const Text('先写一个感觉的名字。'),
              duration: AppMotion.snackbar, behavior: SnackBarBehavior.floating));
      return;
    }
    if (_emotions.any((e) => e.name == name)) {
      showOverlaySnackBar(context,
          SnackBar(content: const Text('这个感觉已经在啦。'),
              duration: AppMotion.snackbar, behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _adding = true);
    try {
      final repo = ref.read(emotionRepositoryProvider);
      final id = await repo.addCustom(name);
      final newEmotion = UserEmotion(
        id: id,
        name: name,
        color: autoColorForName(name),
        description: '',
        isDefault: false,
        sortOrder: _emotions.length,
      );
      setState(() {
        _emotions.add(newEmotion);
        _newCtrl.clear();
      });
      // 刷新全局 provider，主选择器下次打开会带上新情绪
      ref.invalidate(emotionsProvider);
    } catch (_) {
      if (mounted) {
        showOverlaySnackBar(context,
            SnackBar(content: const Text('新增失败，请稍后再试。'),
                duration: AppMotion.snackbar, behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }
}

class _MoreChip extends StatelessWidget {
  const _MoreChip({
    required this.emotion,
    required this.isSelected,
    required this.nightMode,
    required this.onTap,
  });

  final UserEmotion emotion;
  final bool isSelected;
  final bool nightMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? emotion.color.withValues(alpha: .88)
        : nightMode
            ? AppColors.white.withValues(alpha: .07)
            : AppColors.white.withValues(alpha: .72);
    final borderColor = isSelected
        ? emotion.color
        : nightMode
            ? AppColors.white.withValues(alpha: .12)
            : AppColors.line;
    final textColor = isSelected
        ? Colors.white
        : nightMode
            ? AppText.nightInk
            : AppColors.ink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s7, vertical: AppSpacing.s5),
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
                BoxDecoration(color: isSelected ? Colors.white : emotion.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.s5),
          Text(emotion.name,
              style: AppText.chip.copyWith(color: textColor, height: 1.08)),
        ]),
      ),
    );
  }
}
