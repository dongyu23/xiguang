// PAGE_SIZE_EXEMPT: migration in progress; graph clustering and ledger cards will be extracted.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/relation_providers.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/primitives/glow_button.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../../fragment/domain/fragment.dart';
import '../../domain/relation.dart';

class RelationLedgerPage extends ConsumerWidget {
  const RelationLedgerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relations = ref.watch(relationLedgerProvider);
    return XiguangPage(
      backgroundLayer: const AtmosphereBackground(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LedgerHeader(),
          const SizedBox(height: AppSpacing.s22),
          relations.when(
            data: (data) {
              final clusters = _buildRelationClusters(data);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LedgerOverview(data: data, clusters: clusters),
                  const SizedBox(height: AppSpacing.s18),
                  const _SectionLabel(),
                  const SizedBox(height: AppSpacing.s12),
                  _RelationLedgerList(data: data, clusters: clusters),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => _LedgerError(
              onRetry: () => ref.invalidate(relationLedgerProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerHeader extends StatelessWidget {
  const _LedgerHeader();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageBackButton(
        onTap: () => context.pop(),
      ),
      const SizedBox(width: AppSpacing.s6),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '线索簿',
            style: AppText.subHero.copyWith(color: theme.foreground),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '这里收着已经被你确认过的关系。',
            style: AppText.bodyMuted.copyWith(color: theme.foregroundMuted),
          ),
        ]),
      ),
    ]);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(children: [
      Icon(
        Icons.eco_outlined,
        size: 17,
        color: theme.accent,
      ),
      const SizedBox(width: AppSpacing.sm),
      Text(
        '全部线索',
        style: AppText.eyebrow.copyWith(color: theme.accent),
      ),
    ]);
  }
}

class _LedgerOverview extends StatelessWidget {
  const _LedgerOverview({
    required this.data,
    required this.clusters,
  });

  final RelationLedgerData data;
  final List<_RelationCluster> clusters;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final fragments = data.fragmentsById.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latestFragmentId = fragments.isEmpty ? null : fragments.first.id;
    final latestCluster = clusters.isEmpty
        ? null
        : clusters.reduce((a, b) => a.latestTime.isAfter(b.latestTime) ? a : b);
    final subtitle = data.relations.isEmpty
        ? '还没有已确认的线索。'
        : '最近更新：${_formatLedgerTime(latestCluster?.latestTime)}';
    final actionLabel = latestFragmentId == null
        ? '去时间河织第一条线'
        : data.relations.isEmpty
            ? '去织第一条线'
            : '继续织线';
    final accent = theme.accent;

    return XiguangCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.s15, AppSpacing.md, AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: theme.isNight ? .20 : .12),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: accent.withValues(alpha: .24)),
            ),
            child: Icon(
              Icons.account_tree_outlined,
              color: theme.foreground,
              size: 19,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '线索概览',
                style: AppText.titleSmall.copyWith(color: theme.foreground),
              ),
              const SizedBox(height: AppSpacing.s6),
              Text(
                subtitle,
                style: AppText.bodyMuted.copyWith(color: theme.foregroundMuted),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: AppSpacing.s14),
        Row(children: [
          Expanded(
            child: _LedgerStat(
              label: '线索',
              value: '${data.relations.length}',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _LedgerStat(
              label: '关系组',
              value: '${clusters.length}',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _LedgerStat(
              label: '入簿光片',
              value: '${_involvedFragmentCount(data)}',
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.s14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: latestFragmentId == null
                ? () => context.go('/timeline')
                : () => context.push('/weave/$latestFragmentId'),
            icon: const Icon(Icons.add_link_rounded, size: 18),
            label: Text(actionLabel),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 42),
              side: BorderSide(color: theme.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _LedgerStat extends StatelessWidget {
  const _LedgerStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10, vertical: AppSpacing.s10),
      decoration: BoxDecoration(
        color: theme.surfaceHigh.withValues(alpha: theme.isNight ? .42 : .74),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.border.withValues(alpha: .62),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.titleSmall.copyWith(color: theme.foreground),
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption.copyWith(color: theme.foregroundMuted),
        ),
      ]),
    );
  }
}

class _RelationLedgerList extends StatelessWidget {
  const _RelationLedgerList({
    required this.data,
    required this.clusters,
  });

  final RelationLedgerData data;
  final List<_RelationCluster> clusters;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    if (data.relations.isEmpty) {
      return const _EmptyLedger();
    }
    return XiguangCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < clusters.length; i++) ...[
            _RelationClusterCard(cluster: clusters[i]),
            if (i != clusters.length - 1)
              Divider(
                height: 1,
                color: theme.border.withValues(alpha: .72),
              ),
          ],
        ],
      ),
    );
  }
}

List<_RelationCluster> _buildRelationClusters(RelationLedgerData data) {
  final adjacency = <int, Set<int>>{};
  final relationsByNode = <int, List<Relation>>{};
  for (final relation in data.relations) {
    adjacency
        .putIfAbsent(relation.sourceFragmentId, () => <int>{})
        .add(relation.targetFragmentId);
    adjacency
        .putIfAbsent(relation.targetFragmentId, () => <int>{})
        .add(relation.sourceFragmentId);
    relationsByNode
        .putIfAbsent(relation.sourceFragmentId, () => <Relation>[])
        .add(relation);
    relationsByNode
        .putIfAbsent(relation.targetFragmentId, () => <Relation>[])
        .add(relation);
  }

  final visited = <int>{};
  final clusters = <_RelationCluster>[];
  for (final start in adjacency.keys) {
    if (visited.contains(start)) continue;
    final nodeIds = <int>[];
    final relationIds = <int>{};
    final relations = <Relation>[];
    final queue = <int>[start];
    visited.add(start);

    for (var index = 0; index < queue.length; index++) {
      final node = queue[index];
      nodeIds.add(node);
      for (final relation in relationsByNode[node] ?? const <Relation>[]) {
        if (relationIds.add(relation.id)) {
          relations.add(relation);
        }
      }
      for (final next in adjacency[node] ?? const <int>{}) {
        if (visited.add(next)) {
          queue.add(next);
        }
      }
    }

    final fragments = nodeIds
        .map((id) => data.fragmentsById[id])
        .whereType<Fragment>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    relations.sort((a, b) => a.id.compareTo(b.id));
    clusters.add(_RelationCluster(
      nodeIds: nodeIds,
      fragments: fragments,
      relations: relations,
    ));
  }

  clusters.sort((a, b) {
    final bySize = b.relations.length.compareTo(a.relations.length);
    if (bySize != 0) return bySize;
    return b.latestTime.compareTo(a.latestTime);
  });
  return clusters;
}

class _RelationCluster {
  const _RelationCluster({
    required this.nodeIds,
    required this.fragments,
    required this.relations,
  });

  final List<int> nodeIds;
  final List<Fragment> fragments;
  final List<Relation> relations;

  DateTime get latestTime {
    if (fragments.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return fragments
        .map((fragment) => fragment.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

class _RelationClusterCard extends StatelessWidget {
  const _RelationClusterCard({required this.cluster});

  final _RelationCluster cluster;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final labels = _clusterLabels(cluster.relations);
    final notes = cluster.relations
        .map((relation) => relation.note?.trim())
        .whereType<String>()
        .where((note) => note.isNotEmpty)
        .toSet()
        .take(3)
        .toList();
    final visibleFragments = cluster.fragments.take(4).toList();
    final fallbackId = cluster.nodeIds.isEmpty ? null : cluster.nodeIds.first;
    final openId = visibleFragments.firstOrNull?.id ?? fallbackId;
    final accent = theme.accent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s14, AppSpacing.s14, AppSpacing.s12, AppSpacing.s14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: theme.isNight ? .20 : .12),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: accent.withValues(alpha: .24)),
            ),
            child: Icon(
              Icons.account_tree_outlined,
              color: theme.foreground,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${cluster.fragments.length} 束光织成一组',
                style: AppText.titleSmall.copyWith(color: theme.foreground),
              ),
              const SizedBox(height: AppSpacing.s6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final label in labels) _RelationTag(label: label),
                  _RelationTag(
                    label: '${cluster.relations.length} 条联系',
                    muted: true,
                  ),
                ],
              ),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed:
                openId == null ? null : () => context.push('/weave/$openId'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(54, 34),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: theme.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Text(
              '查看',
              style: AppText.chip.copyWith(color: theme.foreground),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.s13),
        _ClusterFragmentsStrip(
          fragments: visibleFragments,
          hiddenCount: cluster.fragments.length - visibleFragments.length,
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s12),
          _ClusterNotes(notes: notes),
        ],
      ]),
    );
  }
}

List<String> _clusterLabels(List<Relation> relations) {
  final labels = <String>[];
  for (final relation in relations) {
    final label = _relationLabel(relation.relationType);
    if (!labels.contains(label)) {
      labels.add(label);
    }
  }
  return labels;
}

class _RelationTag extends StatelessWidget {
  const _RelationTag({
    required this.label,
    this.muted = false,
  });

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final color = muted ? theme.foregroundMuted : theme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: muted ? .08 : (theme.isNight ? .15 : .12),
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: muted ? .16 : .24)),
      ),
      child: Text(
        label,
        style: AppText.microLabel.copyWith(color: color),
      ),
    );
  }
}

class _ClusterFragmentsStrip extends StatelessWidget {
  const _ClusterFragmentsStrip({
    required this.fragments,
    required this.hiddenCount,
  });

  final List<Fragment> fragments;
  final int hiddenCount;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    if (fragments.isEmpty) {
      return Text(
        '这一组里有旧光暂时不可见。',
        style: AppText.caption.copyWith(color: theme.foregroundMuted),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final fragment in fragments)
          _ClusterFragmentChip(fragment: fragment),
        if (hiddenCount > 0) _MoreFragmentsChip(count: hiddenCount),
      ],
    );
  }
}

class _ClusterFragmentChip extends StatelessWidget {
  const _ClusterFragmentChip({required this.fragment});

  final Fragment fragment;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final color = AppColors.emotionColor(fragment.emotion);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => context.push('/fragments/${fragment.id}'),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 246),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s9, AppSpacing.sm, AppSpacing.s10, AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.surfaceHigh.withValues(alpha: theme.isNight ? .42 : .78),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: theme.border.withValues(alpha: .76),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _FragmentGlyph(color: color, size: 24),
          const SizedBox(width: AppSpacing.s7),
          Flexible(
            child: Text(
              fragment.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.captionStrong.copyWith(color: theme.foreground),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MoreFragmentsChip extends StatelessWidget {
  const _MoreFragmentsChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s9, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.surfaceHigh.withValues(alpha: theme.isNight ? .36 : .70),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        '+$count',
        style: AppText.caption.copyWith(color: theme.foregroundMuted),
      ),
    );
  }
}

class _ClusterNotes extends StatelessWidget {
  const _ClusterNotes({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final note in notes) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
            Icons.short_text_rounded,
            size: 15,
            color: theme.foregroundMuted,
          ),
          const SizedBox(width: AppSpacing.s6),
          Expanded(
            child: Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: theme.foregroundMuted),
            ),
          ),
        ]),
        if (note != notes.last) const SizedBox(height: AppSpacing.s5),
      ],
    ]);
  }
}

class _FragmentGlyph extends StatelessWidget {
  const _FragmentGlyph({
    required this.color,
    this.size = 46,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: theme.isNight ? .34 : .22),
      ),
      child: Icon(
        Icons.local_florist_outlined,
        size: size < 32 ? 13 : 22,
        color: theme.foregroundMuted,
      ),
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger();

  @override
  Widget build(BuildContext context) {
    return XiguangEmptyState(
      title: '还没有已织线索',
      description: '在时间河里选择一束光，去织线后会出现在这里。',
      icon: Icons.account_tree_outlined,
      action: GlowButton(
        label: '去时间河',
        icon: Icons.timeline_rounded,
        onPressed: () => context.go('/timeline'),
      ),
    );
  }
}

class _LedgerError extends StatelessWidget {
  const _LedgerError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return XiguangEmptyState(
      title: '线索簿暂时打不开',
      description: '后端暂时没有回应，已经织好的线索不会丢失。',
      icon: Icons.wifi_off_rounded,
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('重新加载'),
      ),
    );
  }
}

String _relationLabel(String value) {
  return switch (value) {
    'reminds_me' => '回声',
    'inspiration' => '伏笔',
    'emotion_continue' => '余震',
    'same_phase' => '平行',
    'cause' => '小小救命',
    'custom' => '旧光',
    _ => '线索',
  };
}

int _involvedFragmentCount(RelationLedgerData data) {
  final ids = <int>{};
  for (final relation in data.relations) {
    if (data.fragmentsById.containsKey(relation.sourceFragmentId)) {
      ids.add(relation.sourceFragmentId);
    }
    if (data.fragmentsById.containsKey(relation.targetFragmentId)) {
      ids.add(relation.targetFragmentId);
    }
  }
  return ids.length;
}

String _formatLedgerTime(DateTime? value) {
  if (value == null || value.millisecondsSinceEpoch == 0) return '尚未更新';
  final local = value.toLocal();
  final now = DateTime.now();
  final sameDay = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  if (sameDay) return '今天 $hour:$minute';
  return '${local.month}/${local.day} $hour:$minute';
}
