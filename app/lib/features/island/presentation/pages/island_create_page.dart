import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';

import '../../application/island_create_controller.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../../ui/spaces/space_canvas.dart';

// PAGE_SIZE_EXEMPT: 本轮保留建岛表单、预览与提交状态编排；
// 后续将新岛预览和字段区域拆为独立 widgets 后移除此豁免。
class IslandCreatePage extends ConsumerStatefulWidget {
  const IslandCreatePage({super.key});

  @override
  ConsumerState<IslandCreatePage> createState() => _IslandCreatePageState();
}

class _IslandCreatePageState extends ConsumerState<IslandCreatePage> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String? _notice;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_syncNameState);
  }

  @override
  void dispose() {
    _nameController.removeListener(_syncNameState);
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _syncNameState() {
    if (!mounted) return;
    setState(() {
      if (_notice != null && _nameController.text.trim().isNotEmpty) {
        _notice = null;
      }
    });
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _notice = '先给这座岛取一个名字。');
      return;
    }
    setState(() {
      _notice = null;
    });
    try {
      final island =
          await ref.read(islandCreateControllerProvider.notifier).create(
                name: name,
                description: _descController.text.trim(),
              );
      if (mounted) {
        final revealKey = island.islandId > 0
            ? 'island-${island.islandId}'
            : 'name-${island.name}';
        context.go(
          '/universe?reveal=${Uri.encodeQueryComponent(revealKey)}',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notice = '小岛暂时没有建起来，请检查后端连接后再试。');
        showOverlaySnackBar(
          context,
          const SnackBar(content: Text('创建小岛失败，请稍后再试。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(islandCreateControllerProvider);
    final theme = NightTheme.of(context);
    final canCreate =
        _nameController.text.trim().isNotEmpty && !createState.isCreating;
    return XiguangPage(
      backgroundLayer: const AtmosphereBackground(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s22,
        AppSpacing.s12,
        AppSpacing.s22,
        AppSpacing.pageBottomNav + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IslandPageHeader(title: '新岛'),
          const SizedBox(height: AppSpacing.s6),
          _NewIslandPreview(name: _nameController.text.trim()),
          const SizedBox(height: AppSpacing.s6),
          Center(
            child: Text(
              '让一座岛浮起来',
              style: AppText.subHero.copyWith(color: theme.foreground),
            ),
          ),
          const SizedBox(height: AppSpacing.s10),
          Center(
            child: Text(
              '名字是它最初的坐标，以后再慢慢把光放进来。',
              textAlign: TextAlign.center,
              style: AppText.bodyMuted.copyWith(color: theme.foregroundMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.s28),
          _CreateField(
            key: const ValueKey('island-name-field'),
            controller: _nameController,
            label: '岛名',
            hint: '比如：午夜咖啡馆',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.s18),
          _CreateField(
            key: const ValueKey('island-description-field'),
            controller: _descController,
            label: '留一句话（可选）',
            hint: '这里会收好怎样的光？',
            maxLines: 3,
          ),
          if (_notice != null) ...[
            const SizedBox(height: AppSpacing.s10),
            Text(
              _notice!,
              style: AppText.caption.copyWith(color: theme.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.s22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              key: const ValueKey('create-island-submit'),
              onPressed: canCreate ? _create : null,
              icon: createState.isCreating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded, size: 19),
              label: Text(createState.isCreating ? '正在让小岛浮起…' : '创建这座小岛'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.background,
                disabledBackgroundColor:
                    theme.foregroundMuted.withValues(alpha: .10),
                disabledForegroundColor:
                    theme.foregroundMuted.withValues(alpha: .62),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewIslandPreview extends StatelessWidget {
  const _NewIslandPreview({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return SizedBox(
      key: const ValueKey('new-island-preview'),
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var ring = 0; ring < 3; ring++)
            Container(
              width: 150.0 + ring * 48,
              height: 55.0 + ring * 19,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: theme.foregroundMuted.withValues(
                    alpha: .10 - ring * .018,
                  ),
                ),
              ),
            ),
          TweenAnimationBuilder<double>(
            duration: AppMotion.islandReveal,
            curve: Curves.easeOutBack,
            tween: Tween(begin: .78, end: 1),
            builder: (_, scale, child) => Transform.scale(
              scale: scale,
              child: Opacity(opacity: scale.clamp(0, 1), child: child),
            ),
            child: Image.asset(
              'assets/islands/family_0/shoal.png',
              width: 230,
              height: 230,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            bottom: 0,
            child: AnimatedSwitcher(
              duration: AppMotion.selection,
              child: Text(
                name.isEmpty ? '一座还没有名字的小岛' : name,
                key: ValueKey(name),
                style: AppText.caption.copyWith(
                  color: name.isEmpty ? theme.foregroundMuted : theme.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateField extends StatelessWidget {
  const _CreateField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.captionStrong.copyWith(color: theme.foregroundMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          maxLines: maxLines,
          textInputAction: textInputAction,
          style: AppText.body.copyWith(color: theme.foreground),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: theme.foreground.withValues(alpha: .045),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.s14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              borderSide: BorderSide(
                color: theme.border.withValues(alpha: .55),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              borderSide: BorderSide(
                color: theme.accent.withValues(alpha: .62),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IslandPageHeader extends StatelessWidget {
  const _IslandPageHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: '返回',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: theme.foreground),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            title,
            style: AppText.titleLarge.copyWith(color: theme.foreground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
