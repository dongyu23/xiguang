import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../application/universe_overview_provider.dart';
import '../widgets/branch_river_canvas.dart';

class BranchDetailPage extends ConsumerStatefulWidget {
  const BranchDetailPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<BranchDetailPage> createState() => _BranchDetailPageState();
}

class _BranchDetailPageState extends ConsumerState<BranchDetailPage> {
  int? _selectedNodeId;

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(universeOverviewProvider);
    final theme = NightTheme.of(context);
    return XiguangPage(
      child: overview.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(universeOverviewProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新加载支线'),
          ),
        ),
        data: (data) {
          final branch = data.branches
              .where((item) => item.publicId == widget.id)
              .firstOrNull;
          if (branch == null) {
            return Column(children: [
              Row(children: [
                PageBackButton(onTap: context.pop),
                const SizedBox(width: AppSpacing.s10),
                Text('支线',
                    style:
                        AppText.titleLarge.copyWith(color: theme.foreground)),
              ]),
              const SizedBox(height: AppSpacing.xl),
              Text('这条支线暂时没有找到。',
                  style:
                      AppText.bodyMuted.copyWith(color: theme.foregroundMuted)),
            ]);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  PageBackButton(onTap: context.pop),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(branch.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.titleLarge
                                  .copyWith(color: theme.foreground)),
                          const SizedBox(height: AppSpacing.s3),
                          Text(
                            '${branch.fragmentCount} 个节点 · ${branch.edgeCount} 条连接${branch.hasBidirectional ? ' · 含双向' : ''}',
                            style: AppText.caption
                                .copyWith(color: theme.foregroundMuted),
                          ),
                        ]),
                  ),
                  IconButton(
                    tooltip: '添加一束光',
                    onPressed: branch.fragments.isEmpty
                        ? null
                        : () =>
                            context.push('/weave/${branch.fragments.last.id}'),
                    icon: const Icon(Icons.add_link_rounded),
                  ),
                ]),
                const SizedBox(height: AppSpacing.s18),
                Container(
                  height: 420,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: theme.surface.withValues(alpha: .28),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: BranchRiverCanvas(
                    branches: [branch],
                    selectedBranch: branch,
                    selectedNodeId: _selectedNodeId,
                    onSelectBranch: (_) {},
                    onSelectNode: (id) => setState(() => _selectedNodeId = id),
                    interactive: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.s18),
                Text('事件顺序',
                    style: AppText.eyebrow.copyWith(color: theme.accent)),
                const SizedBox(height: AppSpacing.s6),
                ...branch.fragments.asMap().entries.map((entry) {
                  final fragment = entry.value;
                  final selected = fragment.id == _selectedNodeId;
                  return InkWell(
                    onTap: () => context.push('/fragments/${fragment.id}'),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.s10),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: AppMotion.fast,
                          width: selected ? 12 : 8,
                          height: selected ? 12 : 8,
                          decoration: BoxDecoration(
                            color:
                                selected ? theme.accent : theme.foregroundMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        SizedBox(
                          width: 24,
                          child: Text('${entry.key + 1}',
                              style: AppText.microLabel
                                  .copyWith(color: theme.foregroundMuted)),
                        ),
                        Expanded(
                          child: Text(
                            fragment.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                AppText.body.copyWith(color: theme.foreground),
                          ),
                        ),
                        Text(fragment.time,
                            style: AppText.caption
                                .copyWith(color: theme.foregroundMuted)),
                      ]),
                    ),
                  );
                }),
              ]);
        },
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
