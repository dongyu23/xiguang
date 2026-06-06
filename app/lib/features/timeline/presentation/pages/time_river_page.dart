import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../features/fragment/data/fragment_repository.dart';
import '../../../../features/fragment/presentation/pages/fragment_detail_page.dart';
import '../../../../features/timeline/presentation/providers/timeline_provider.dart';
import '../../../../ui/composites/light_card.dart';
import '../../../../ui/composites/tag_chip.dart';
import '../../../../ui/spaces/space_canvas.dart';

/// 时间河流页 — 按时间自然铺展的光片流
///
/// "这些碎片不用被整理成答案，它们先按时间流动。"
class TimeRiverPage extends ConsumerStatefulWidget {
  const TimeRiverPage({super.key});

  @override
  ConsumerState<TimeRiverPage> createState() => _TimeRiverPageState();
}

class _TimeRiverPageState extends ConsumerState<TimeRiverPage> {
  String _filter = '全部';

  @override
  Widget build(BuildContext context) {
    final fragments = ref.watch(fragmentsProvider);
    final timeline = ref.watch(timelineGroupsProvider);
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 104),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Header(),
                    const SizedBox(height: 18),
                    timeline.when(
                      data: (groups) {
                        final items = groups.expand((group) {
                          return group.fragments.map(_fromDomainFragment);
                        }).toList();
                        final filters = [
                          '全部',
                          ...items
                              .expand((item) => [item.emotion, ...item.tags])
                              .toSet()
                              .take(8)
                        ];
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                              children: filters.map((label) {
                            return GestureDetector(
                              onTap: () => setState(() => _filter = label),
                              child: TagChip(
                                  label: label, filled: _filter == label),
                            );
                          }).toList()),
                        );
                      },
                      loading: () => const SizedBox(height: 32),
                      error: (_, __) => TagChip(label: '本地回看', filled: true),
                    ),
                    const SizedBox(height: 20),
                    timeline.when(
                      data: (groups) {
                        final visibleGroups = groups
                            .map((group) {
                              final visible = group.fragments
                                  .map(_fromDomainFragment)
                                  .where((item) =>
                                      _filter == '全部' ||
                                      item.emotion == _filter ||
                                      item.tags.contains(_filter))
                                  .toList();
                              return (label: group.dateLabel, items: visible);
                            })
                            .where((group) => group.items.isNotEmpty)
                            .toList();
                        if (visibleGroups.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Text('还没有这样的旧光。', style: AppText.body),
                          );
                        }
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final group in visibleGroups) ...[
                                _DateRail(
                                    label: group.label,
                                    count: '${group.items.length} 束光'),
                                ...group.items.map((f) => LightFragmentCard(
                                      tapKey: ValueKey('timeline-card-${f.id}'),
                                      fragment: f.toLightFragment(),
                                      onTap: () => Navigator.of(context,
                                              rootNavigator: true)
                                          .push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              FragmentDetailPage(id: '${f.id}'),
                                        ),
                                      ),
                                    )),
                                const SizedBox(height: 8),
                              ],
                            ]);
                      },
                      loading: () => const Center(
                          child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator())),
                      error: (error, _) => fragments.when(
                        data: (items) => _FallbackTimeline(
                          items: items,
                          filter: _filter,
                        ),
                        loading: () =>
                            Text('时间河暂时变浅了：$error', style: AppText.body),
                        error: (_, __) =>
                            Text('时间河暂时变浅了：$error', style: AppText.body),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('TIME RIVER', style: AppText.eyebrow),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text('线', style: AppText.hero)),
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: .86),
                shape: BoxShape.circle),
            child:
                const Icon(Icons.nights_stay_outlined, color: AppColors.ink)),
      ]),
      const SizedBox(height: 8),
      Text('这些碎片不用被整理成答案，它们先按时间流动。', style: AppText.body),
    ]);
  }
}

extension _LightFragmentAdapter on LightFragmentModel {
  LightFragment toLightFragment() {
    return LightFragment(
      time: time,
      date: dateLabel,
      title: title,
      text: contentText,
      emotion: emotion,
      tags: tags,
      color: color,
      relation: status,
    );
  }
}

LightFragmentModel _fromDomainFragment(dynamic fragment) {
  return LightFragmentModel(
    id: fragment.id as int,
    contentText: fragment.contentText as String,
    emotion: fragment.emotion as String? ?? '说不清',
    tags: List<String>.from(fragment.tags as List),
    mediaUrls: List<String>.from(fragment.mediaUrls as List),
    createdAt: fragment.createdAt as DateTime,
    status: (fragment.status as Object).toString().split('.').last,
  );
}

class _FallbackTimeline extends StatelessWidget {
  const _FallbackTimeline({required this.items, required this.filter});

  final List<LightFragmentModel> items;
  final String filter;

  @override
  Widget build(BuildContext context) {
    final visible = filter == '全部'
        ? items
        : items
            .where(
                (item) => item.emotion == filter || item.tags.contains(filter))
            .toList();
    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text('还没有这样的旧光。', style: AppText.body),
      );
    }
    final labels = visible.map((item) => item.dateLabel).toSet().toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final label in labels) ...[
        _DateRail(
          label: label,
          count: '${visible.where((f) => f.dateLabel == label).length} 束光',
        ),
        ...visible.where((f) => f.dateLabel == label).map(
              (f) => LightFragmentCard(
                tapKey: ValueKey('timeline-card-${f.id}'),
                fragment: f.toLightFragment(),
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FragmentDetailPage(id: '${f.id}'),
                  ),
                ),
              ),
            ),
        const SizedBox(height: 8),
      ],
    ]);
  }
}

class _DateRail extends StatelessWidget {
  const _DateRail({required this.label, required this.count});
  final String label, count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: AppColors.teaGreen, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: AppText.titleSmall),
        const SizedBox(width: 8),
        Text(count, style: AppText.caption),
      ]),
    );
  }
}
