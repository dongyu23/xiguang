// PAGE_SIZE_EXEMPT: sequence composition and submission form one focused flow.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/primitives/night_background.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../../fragment/domain/fragment.dart';
import '../../../fragment/presentation/providers/fragment_providers.dart';
import '../../application/relation_types_controller.dart';
import '../../application/weave_controller.dart';
import '../providers/relation_providers.dart';
import '../widgets/relation_note_input.dart';
import '../widgets/relation_type_picker.dart';

class WeavePage extends ConsumerStatefulWidget {
  const WeavePage({super.key, required this.sourceId});

  final int sourceId;

  @override
  ConsumerState<WeavePage> createState() => _WeavePageState();
}

class _WeavePageState extends ConsumerState<WeavePage> {
  final _noteController = TextEditingController();
  late final List<int> _chainIds;

  /// 当前选中的关系类型名（存 name，如"回声"）。空串表示尚未初始化，
  /// 首次拿到 relationTypesProvider 数据时自动选第一个可见类型。
  String _relationType = '';
  bool _isSubmitting = false;
  bool _completed = false;
  String? _submitNotice;

  @override
  void initState() {
    super.initState();
    _chainIds = [widget.sourceId];
    // 初始化默认选中：用 provider 里的第一个可见类型，避免硬编码 'reminds_me'。
    final types = ref.read(relationTypesProvider).valueOrNull;
    if (types != null) {
      final firstVisible = types.where((t) => !t.hidden).firstOrNull;
      if (firstVisible != null) {
        _relationType = firstVisible.name;
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fragments = ref.watch(fragmentsProvider);
    final theme = NightTheme.of(context);
    // 首次拿到类型数据时，若 _relationType 仍为空，自动选中第一个可见类型。
    if (_relationType.isEmpty) {
      final types = ref.watch(relationTypesProvider).valueOrNull;
      final firstVisible = types?.where((t) => !t.hidden).firstOrNull;
      if (firstVisible != null) {
        _relationType = firstVisible.name;
      }
    }
    return Stack(children: [
      const Positioned.fill(child: NightBackgroundPlaceholder()),
      const Positioned.fill(child: AtmosphereBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: fragments.when(
            data: (items) => _buildContent(context, items),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Text(
                '暂时无法展开这些光，请稍后再试。',
                style: AppText.body.copyWith(color: theme.foreground),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildContent(BuildContext context, List<Fragment> items) {
    final source =
        items.where((item) => item.id == widget.sourceId).firstOrNull;
    if (source == null) return _NotFoundState(onBack: () => context.pop());

    final fragmentsById = {for (final fragment in items) fragment.id: fragment};
    final chain =
        _chainIds.map((id) => fragmentsById[id]).whereType<Fragment>().toList();
    final candidates = [...items]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final relations = ref.watch(relationsProvider).valueOrNull ?? const [];
    final existingPairs = {
      for (final relation in relations)
        _pairKey(relation.sourceFragmentId, relation.targetFragmentId),
    };
    final directlyWovenIds = <int>{};
    for (final relation in relations) {
      if (relation.sourceFragmentId == source.id) {
        directlyWovenIds.add(relation.targetFragmentId);
      } else if (relation.targetFragmentId == source.id) {
        directlyWovenIds.add(relation.sourceFragmentId);
      }
    }

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s18,
            AppSpacing.sm,
            AppSpacing.s18,
            AppSpacing.s18,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(onBack: () => context.pop()),
                  const SizedBox(height: AppSpacing.s14),
                  _DevelopmentRail(
                    chain: chain,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        final id = _chainIds.removeAt(oldIndex);
                        _chainIds.insert(newIndex, id);
                        _resetNotice();
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  _CandidatePanel(
                    fragments: candidates,
                    sourceId: source.id,
                    selectedIds: _chainIds.toSet(),
                    directlyWovenIds: directlyWovenIds,
                    onToggle: (id) {
                      setState(() {
                        if (_chainIds.contains(id)) {
                          _chainIds.remove(id);
                        } else {
                          _chainIds.add(id);
                        }
                        _resetNotice();
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.s14),
                  Text(
                    '它们为什么接着发生',
                    style: AppText.titleSmall
                        .copyWith(color: NightTheme.of(context).foreground),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  RelationTypePicker(
                    selectedType: _relationType,
                    onSelected: (type) => setState(() => _relationType = type),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  RelationNoteInput(controller: _noteController),
                  AnimatedSwitcher(
                    duration: AppMotion.normal,
                    child: _completed || _submitNotice != null
                        ? Padding(
                            key: ValueKey(
                                _completed ? 'complete' : 'submit-notice'),
                            padding: const EdgeInsets.only(top: AppSpacing.s10),
                            child: _completed
                                ? _CompleteToast(eventCount: chain.length)
                                : _SubmitNotice(text: _submitNotice!),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      _BottomWeaveBar(
        eventCount: chain.length,
        isSubmitting: _isSubmitting,
        onPressed: chain.length < 2 || _isSubmitting
            ? null
            : () => _submit(chain, existingPairs),
      ),
    ]);
  }

  void _resetNotice() {
    _completed = false;
    _submitNotice = null;
  }

  Future<void> _submit(List<Fragment> chain, Set<String> existingPairs) async {
    if (_isSubmitting || chain.length < 2) return;
    setState(() {
      _isSubmitting = true;
      _resetNotice();
    });
    var createdCount = 0;
    try {
      for (var index = 0; index < chain.length - 1; index++) {
        final from = chain[index];
        final to = chain[index + 1];
        if (existingPairs.contains(_pairKey(from.id, to.id))) continue;
        final relation =
            await ref.read(weaveControllerProvider.notifier).submit(
                  sourceFragmentId: from.id,
                  targetFragmentId: to.id,
                  relationType: _relationType,
                  note: _noteController.text,
                );
        if (relation == null) throw StateError('weave_failed');
        createdCount++;
      }
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _completed = createdCount > 0;
        _submitNotice = createdCount == 0 ? '这些事件已经在同一条线上了。' : null;
      });
      ref.invalidate(relationsProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _completed = false;
        _submitNotice = createdCount == 0
            ? '后端暂时没有回应，这条线还没有写入。'
            : '已织好前 $createdCount 段，剩下的暂时没有写入。';
      });
    }
  }
}

String _pairKey(int first, int second) {
  final low = first < second ? first : second;
  final high = first < second ? second : first;
  return '$low:$high';
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(children: [
      PageBackButton(onTap: onBack),
      const SizedBox(width: AppSpacing.s12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('织线',
              style: AppText.titleLarge.copyWith(color: theme.foreground)),
          const SizedBox(height: AppSpacing.s2),
          Text(
            '按事情发展的顺序，把片刻接起来。',
            style: AppText.caption.copyWith(color: theme.foregroundMuted),
          ),
        ]),
      ),
    ]);
  }
}

class _DevelopmentRail extends StatelessWidget {
  const _DevelopmentRail({required this.chain, required this.onReorder});

  final List<Fragment> chain;
  final ReorderCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangCard(
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.route_rounded, size: 18, color: theme.accent),
          const SizedBox(width: AppSpacing.s7),
          Text('发展顺序',
              style: AppText.bodyStrong.copyWith(color: theme.foreground)),
          const Spacer(),
          Text('长按拖动',
              style: AppText.caption.copyWith(color: theme.foregroundMuted)),
        ]),
        const SizedBox(height: AppSpacing.s10),
        SizedBox(
          height: 82,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            onReorderItem: onReorder,
            itemCount: chain.length,
            proxyDecorator: (child, _, animation) => FadeTransition(
              opacity: animation.drive(Tween(begin: .72, end: 1.0)),
              child: child,
            ),
            itemBuilder: (context, index) {
              final fragment = chain[index];
              return ReorderableDragStartListener(
                key: ValueKey('chain-${fragment.id}'),
                index: index,
                child: _ChainEventCard(
                  fragment: fragment,
                  order: index + 1,
                  showArrow: index < chain.length - 1,
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _ChainEventCard extends StatelessWidget {
  const _ChainEventCard({
    required this.fragment,
    required this.order,
    required this.showArrow,
  });

  final Fragment fragment;
  final int order;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(children: [
      Container(
        width: 104,
        height: 74,
        padding: const EdgeInsets.all(AppSpacing.s9),
        decoration: BoxDecoration(
          color: fragment.color.withValues(alpha: theme.isNight ? .16 : .1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: fragment.color.withValues(alpha: .32)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fragment.color,
                shape: BoxShape.circle,
              ),
              child: Text('$order',
                  style: AppText.caption
                      .copyWith(color: AppColors.white, fontSize: 10)),
            ),
            const Spacer(),
            Icon(Icons.drag_indicator_rounded,
                size: 17, color: theme.foregroundMuted),
          ]),
          const SizedBox(height: AppSpacing.s6),
          Text(
            fragment.contentText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(
              color: theme.foreground,
              height: 1.25,
            ),
          ),
        ]),
      ),
      if (showArrow) ...[
        const SizedBox(width: AppSpacing.s3),
        Icon(Icons.arrow_forward_rounded, size: 14, color: theme.accent),
        const SizedBox(width: AppSpacing.s3),
      ] else
        const SizedBox(width: AppSpacing.sm),
    ]);
  }
}

class _CandidatePanel extends StatelessWidget {
  const _CandidatePanel({
    required this.fragments,
    required this.sourceId,
    required this.selectedIds,
    required this.directlyWovenIds,
    required this.onToggle,
  });

  final List<Fragment> fragments;
  final int sourceId;
  final Set<int> selectedIds;
  final Set<int> directlyWovenIds;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s10,
        AppSpacing.s12,
        AppSpacing.s10,
        AppSpacing.sm,
      ),
      child: Column(children: [
        Row(children: [
          Icon(Icons.add_circle_outline_rounded, size: 18, color: theme.accent),
          const SizedBox(width: AppSpacing.s7),
          Text('挑选事件',
              style: AppText.bodyStrong.copyWith(color: theme.foreground)),
          const Spacer(),
          Text('按时间查找',
              style: AppText.caption.copyWith(color: theme.foregroundMuted)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        for (final fragment in fragments)
          _CandidateEventTile(
            fragment: fragment,
            isSource: fragment.id == sourceId,
            selected: selectedIds.contains(fragment.id),
            alreadyWoven: directlyWovenIds.contains(fragment.id),
            onTap: fragment.id == sourceId ? null : () => onToggle(fragment.id),
          ),
      ]),
    );
  }
}

class _CandidateEventTile extends StatelessWidget {
  const _CandidateEventTile({
    required this.fragment,
    required this.isSource,
    required this.selected,
    required this.alreadyWoven,
    required this.onTap,
  });

  final Fragment fragment;
  final bool isSource;
  final bool selected;
  final bool alreadyWoven;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final local = fragment.createdAt.toLocal();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          height: 52,
          child: Row(children: [
            SizedBox(
              width: 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${local.month}/${local.day}',
                      style: AppText.chip.copyWith(color: theme.foreground)),
                  Text(fragment.time,
                      style: AppText.caption
                          .copyWith(color: theme.foregroundMuted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s10),
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: fragment.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: Text(
                fragment.contentText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(color: theme.foreground),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: isSource
                    ? _CompactStatus(label: '当前', color: fragment.color)
                    : selected
                        ? _CompactStatus(label: '已选', color: fragment.color)
                        : alreadyWoven
                            ? _CompactStatus(label: '已织', color: theme.accent)
                            : Icon(Icons.add_rounded,
                                size: 20, color: theme.foregroundMuted),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CompactStatus extends StatelessWidget {
  const _CompactStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: AppText.caption.copyWith(color: color)),
    );
  }
}

class _BottomWeaveBar extends StatelessWidget {
  const _BottomWeaveBar({
    required this.eventCount,
    required this.isSubmitting,
    required this.onPressed,
  });

  final int eventCount;
  final bool isSubmitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s18),
        decoration: BoxDecoration(
          color: theme.surfaceHigh.withValues(alpha: .96),
          border: Border(top: BorderSide(color: theme.border)),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: .08),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              eventCount < 2 ? '再选一个事件' : '$eventCount 个事件依次发展',
              style: AppText.caption.copyWith(color: theme.foregroundMuted),
            ),
          ),
          SizedBox(
            width: 148,
            child: XiguangButton(
              label: eventCount < 2 ? '织线' : '织起这条线',
              leading: const Icon(Icons.route_rounded, size: 18),
              onPressed: onPressed,
              loading: isSubmitting,
              height: 42,
            ),
          ),
        ]),
      ),
    );
  }
}

class _CompleteToast extends StatelessWidget {
  const _CompleteToast({required this.eventCount});

  final int eventCount;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.teaGreen.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_outline_rounded,
            size: 18, color: AppColors.teaGreen),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '$eventCount 个事件已经按发展顺序织在一起。',
            style: AppText.body.copyWith(color: theme.foreground),
          ),
        ),
      ]),
    );
  }
}

class _SubmitNotice extends StatelessWidget {
  const _SubmitNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: AppColors.sunsetCoral.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(text, style: AppText.bodyMuted),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return XiguangEmptyState(
      icon: Icons.blur_off_rounded,
      title: '没有找到这束光',
      description: '这束光可能已经被轻轻收起。',
      action: XiguangButton(
        label: '返回',
        onPressed: onBack,
        leading: const Icon(Icons.chevron_left_rounded),
      ),
    );
  }
}
