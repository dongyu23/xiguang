import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../fragment/domain/fragment.dart';
import '../../../fragment/application/fragment_library_controller.dart';
import '../../../fragment/presentation/providers/fragment_providers.dart';
import '../../../timeline/presentation/providers/timeline_provider.dart';

class TrashPage extends ConsumerStatefulWidget {
  const TrashPage({super.key});

  @override
  ConsumerState<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends ConsumerState<TrashPage> {
  late Future<List<Fragment>> _items;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _items = ref.read(fragmentLibraryControllerProvider).listDeleted();
  }

  Future<void> _restore(Fragment fragment) async {
    if (_busy.contains(fragment.id)) return;
    setState(() => _busy.add(fragment.id));
    try {
      await ref.read(fragmentLibraryControllerProvider).restore(fragment.id);
      ref.invalidate(fragmentsProvider);
      ref.invalidate(timelineGroupsProvider);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('这束光已经回到时间河。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(fragment.id));
    }
  }

  Future<void> _deletePermanently(Fragment fragment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('彻底删除这束光？'),
        content: const Text('删除后无法恢复，相关的本地媒体也可能在后续缓存清理中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sunsetCoral,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('彻底删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busy.contains(fragment.id)) return;
    setState(() => _busy.add(fragment.id));
    try {
      await ref
          .read(fragmentLibraryControllerProvider)
          .deletePermanently(fragment.id);
      if (!mounted) return;
      setState(_reload);
    } finally {
      if (mounted) setState(() => _busy.remove(fragment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_rounded, color: theme.foreground),
          ),
          const SizedBox(height: AppSpacing.s6),
          Text('AFTERGLOW',
              style: AppText.eyebrow.copyWith(color: theme.accent)),
          const SizedBox(height: AppSpacing.sm),
          Text('回收站', style: AppText.hero.copyWith(color: theme.foreground)),
          const SizedBox(height: AppSpacing.s9),
          Text(
            '误删的光会先停在这里。你可以让它回到时间河，或确认后彻底删除。',
            style: AppText.body.copyWith(color: theme.foregroundMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          FutureBuilder<List<Fragment>>(
            future: _items,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(color: theme.accent),
                  ),
                );
              }
              if (snapshot.hasError) {
                return _TrashMessage(
                  icon: Icons.cloud_off_rounded,
                  title: '暂时打不开回收站',
                  subtitle: '请检查网络后重试。',
                  action: TextButton(
                    onPressed: () => setState(_reload),
                    child: const Text('重新读取'),
                  ),
                );
              }
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return const _TrashMessage(
                  icon: Icons.auto_awesome_rounded,
                  title: '这里很安静',
                  subtitle: '删除的光片会出现在这里。',
                );
              }
              return Column(
                children: [
                  for (final fragment in items)
                    _TrashFragmentTile(
                      fragment: fragment,
                      busy: _busy.contains(fragment.id),
                      onRestore: () => _restore(fragment),
                      onDelete: () => _deletePermanently(fragment),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrashFragmentTile extends StatelessWidget {
  const _TrashFragmentTile({
    required this.fragment,
    required this.busy,
    required this.onRestore,
    required this.onDelete,
  });

  final Fragment fragment;
  final bool busy;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final preview = fragment.contentText.trim().isEmpty
        ? (fragment.mediaUrls.isEmpty ? '一束没有文字的光' : '一束媒体光片')
        : fragment.contentText.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: theme.surfaceHigh.withValues(alpha: .68),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.border.withValues(alpha: .82)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyStrong.copyWith(color: theme.foreground),
          ),
          const SizedBox(height: AppSpacing.s7),
          Text(
            '${fragment.dateLabel} · ${fragment.emotion}',
            style: AppText.caption.copyWith(color: theme.foregroundMuted),
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: busy ? null : onDelete,
                child: Text('彻底删除',
                    style: AppText.chip.copyWith(color: theme.danger)),
              ),
              const SizedBox(width: AppSpacing.s6),
              FilledButton.icon(
                onPressed: busy ? null : onRestore,
                icon: busy
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore_rounded, size: 17),
                label: const Text('恢复'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrashMessage extends StatelessWidget {
  const _TrashMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 38, color: theme.accent),
            const SizedBox(height: AppSpacing.s12),
            Text(title,
                style: AppText.titleMedium.copyWith(color: theme.foreground)),
            const SizedBox(height: AppSpacing.s6),
            Text(subtitle,
                style:
                    AppText.bodyMuted.copyWith(color: theme.foregroundMuted)),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.s10),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
