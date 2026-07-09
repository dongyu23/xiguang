// PAGE_SIZE_EXEMPT: migration in progress; selection workflow and timeline sections remain to be extracted.
import 'package:flutter/material.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xiguang/app/app_state.dart';
import '../../../fragment/presentation/providers/fragment_providers.dart';
import '../../../relation/presentation/providers/relation_providers.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../features/fragment/domain/fragment.dart';
import '../../../../features/relation/domain/relation.dart';
import '../../../../features/timeline/domain/date_group.dart';
import '../../application/timeline_actions_controller.dart';
import '../../../../features/timeline/presentation/providers/timeline_provider.dart';
import '../../../../ui/composites/light_card.dart';
import '../../../../ui/primitives/scroll_to_top.dart';
import '../widgets/timeline_month_picker.dart';

/// 时间河流页 — 按时间自然铺展的光片流
///
/// "这些碎片不用被整理成答案，它们先按时间流动。"
class TimeRiverPage extends ConsumerStatefulWidget {
  const TimeRiverPage({super.key});

  @override
  ConsumerState<TimeRiverPage> createState() => _TimeRiverPageState();
}

class _TimeRiverPageState extends ConsumerState<TimeRiverPage> {
  DateTime? _selectedMonth;
  final Set<int> _selectedIds = {};
  bool _deleting = false;

  bool get _selectionMode => _selectedIds.isNotEmpty;
  bool get _busy =>
      _deleting || ref.read(timelineActionsControllerProvider).isLoading;

  // 缓存上一次的 items，避免同一帧内重复 expand+map 计算
  List<Fragment>? _cachedItems;
  AsyncValue? _cachedTimeline;
  AsyncValue? _cachedRelations;
  Map<int, String>? _cachedRelationMap;
  // C1: Cache flattened sliver items for virtualized list
  List<Object>? _cachedSliverItems;
  List<Fragment>? _cachedFilteredItems;
  DateTime? _cachedSelectedMonth;

  List<Fragment> _buildItems(
      AsyncValue timeline, Map<int, String> relationByFragment) {
    if (_cachedItems != null &&
        identical(_cachedTimeline, timeline) &&
        identical(_cachedRelations, ref.read(relationsProvider))) {
      return _cachedItems!;
    }
    _cachedTimeline = timeline;
    _cachedRelations = ref.read(relationsProvider);
    _cachedItems = timeline.when(
      data: (groups) => (groups as List<DateGroup>)
          .expand((group) => group.fragments)
          .map(_fromDomainFragment)
          .map((f) => _withRelation(f, relationByFragment[f.id]))
          .toList(),
      loading: () => const <Fragment>[],
      error: (_, __) => const <Fragment>[],
    );
    return _cachedItems!;
  }

  Map<int, String> _buildRelationMap(AsyncValue relations) {
    if (_cachedRelationMap != null && identical(_cachedRelations, relations)) {
      return _cachedRelationMap!;
    }
    final result = <int, String>{};
    for (final relation in relations.valueOrNull ?? const <Relation>[]) {
      result[relation.sourceFragmentId] ??= relation.relationType;
      result[relation.targetFragmentId] ??= relation.relationType;
    }
    _cachedRelationMap = result;
    return result;
  }

  /// C1: Flatten grouped items into a list for SliverList.builder.
  /// Each entry is either a _DateRailItem (header) or Fragment (card).
  List<Object> _buildSliverItems(List<Fragment> allItems) {
    if (_cachedSliverItems != null &&
        identical(_cachedFilteredItems, allItems) &&
        _cachedSelectedMonth == _selectedMonth) {
      return _cachedSliverItems!;
    }
    _cachedFilteredItems = allItems;
    _cachedSelectedMonth = _selectedMonth;
    final filtered = allItems.where(_passesFilters).toList();
    final visibleGroups = _groupVisibleItems(filtered);
    final items = <Object>[];
    for (final group in visibleGroups) {
      items.add(_DateRailItem(
        label: group.label,
        count: group.items.length,
      ));
      items.addAll(group.items);
    }
    _cachedSliverItems = items;
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final fragments = ref.watch(fragmentsProvider);
    final timeline = ref.watch(timelineGroupsProvider);
    final theme = NightTheme.of(context);
    final polishEnabled = ref.watch(aiPolishEnabledProvider);
    final polishing = ref.watch(timelineActionsControllerProvider).isLoading;
    final relations = ref.watch(relationsProvider);
    final relationByFragment = _buildRelationMap(relations);
    // 统一计算一次 items，timeline 和 fallback 共用
    final allItems = timeline.when(
      data: (_) => _buildItems(timeline, relationByFragment),
      loading: () => fragments.when(
        data: (items) => items
            .map((f) => _withRelation(f, relationByFragment[f.id]))
            .toList(),
        loading: () => const <Fragment>[],
        error: (_, __) => const <Fragment>[],
      ),
      error: (_, __) => fragments.when(
        data: (items) => items
            .map((f) => _withRelation(f, relationByFragment[f.id]))
            .toList(),
        loading: () => const <Fragment>[],
        error: (_, __) => const <Fragment>[],
      ),
    );
    return Stack(children: [
      // C2: Background now provided by _AppShell in router.dart
      // C1: Use CustomScrollView + SliverList.builder for virtualized rendering
      SafeArea(
        child: ScrollToTop(
          builder: (context, controller) {
            final sliverItems = _buildSliverItems(allItems);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: CustomScrollView(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s22, AppSpacing.s18, AppSpacing.s22, 0),
                      sliver: SliverToBoxAdapter(
                        child: const _Header(),
                      ),
                    ),
                    // Controls
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s22, AppSpacing.s10, AppSpacing.s22, 0),
                      sliver: SliverToBoxAdapter(
                        child: allItems.isNotEmpty
                            ? _TimelineControls(
                                selectedMonth: _selectedMonth,
                                onSelected: (month) =>
                                    setState(() => _selectedMonth = month),
                                onOpenPicker: () => _showMonthPicker(allItems),
                              )
                            : const SizedBox(height: AppSpacing.xl),
                      ),
                    ),
                    // Fragment list (virtualized) or loading/empty state
                    if (allItems.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.s22, AppSpacing.md, AppSpacing.s22, 0),
                        sliver: SliverToBoxAdapter(
                          child: const _TimelineLoadingState(),
                        ),
                      )
                    else if (sliverItems.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.s22, AppSpacing.lg, AppSpacing.s22, 0),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            '还没有这样的旧光。',
                            style:
                                AppText.body.copyWith(color: theme.foreground),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.s22,
                          AppSpacing.md,
                          AppSpacing.s22,
                          _selectionMode
                              ? AppSpacing.selectionToolbarClearance
                              : AppSpacing.pageBottomNav +
                                  MediaQuery.paddingOf(context).bottom,
                        ),
                        sliver: SliverList.builder(
                          itemCount: sliverItems.length,
                          itemBuilder: (context, index) {
                            final item = sliverItems[index];
                            if (item is _DateRailItem) {
                              return _DateRail(
                                label: item.label,
                                count: '${item.count} 束光',
                              );
                            }
                            final f = item as Fragment;
                            return LightFragmentCard(
                              tapKey: ValueKey('timeline-card-${f.id}'),
                              fragment: f.toLightFragment(),
                              dense: true,
                              showAttachmentBadge: true,
                              showTitle: false,
                              selectionMode: _selectionMode,
                              showSelectionControl: _selectionMode,
                              selected: _selectedIds.contains(f.id),
                              onSelectionTap: () => _toggleSelection(f.id),
                              onTap: () => _selectionMode
                                  ? _toggleSelection(f.id)
                                  : context.push('/fragments/${f.id}'),
                              onLongPress: () => _startSelection(f.id),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      if (_selectionMode)
        _SelectionActionBar(
          count: _selectedIds.length,
          deleting: _deleting,
          polishing: polishing,
          polishEnabled: polishEnabled,
          onCancel: _busy ? null : _clearSelection,
          onPolish: _busy ? null : () => _polishSelected(timeline, fragments),
          onDelete: _busy ? null : _deleteSelected,
        ),
    ]);
  }

  void _startSelection(int id) {
    setState(() => _selectedIds.add(id));
  }

  void _toggleSelection(int id) {
    setState(() {
      if (!_selectedIds.remove(id)) {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(_selectedIds.clear);
  }

  Future<void> _deleteSelected() async {
    if (_busy || _selectedIds.isEmpty) return;
    final ids = Set<int>.from(_selectedIds);
    setState(() => _deleting = true);
    try {
      await ref.read(fragmentsProvider.notifier).deleteMany(ids);
      ref.invalidate(timelineGroupsProvider);
      if (!mounted) return;
      setState(() {
        _selectedIds.removeAll(ids);
        _deleting = false;
      });
      showOverlaySnackBar(
        context,
        SnackBar(
          content: Text('已删除 ${ids.length} 束光。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showOverlaySnackBar(
        context,
        const SnackBar(
          content: Text('删除失败，请稍后再试。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _polishSelected(
    AsyncValue<List<DateGroup>> timeline,
    AsyncValue<List<Fragment>> fragments,
  ) async {
    if (_busy || _selectedIds.isEmpty) return;
    final selected = _selectedFragments(timeline, fragments);
    if (selected.isEmpty) {
      showOverlaySnackBar(
        context,
        const SnackBar(
          content: Text('没有找到可润色的光。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final result = await ref
        .read(timelineActionsControllerProvider.notifier)
        .polish(selected);
    if (!mounted) return;
    setState(_selectedIds.clear);
    final msg = StringBuffer();
    if (result.success > 0) msg.write('已润色 ${result.success} 束光');
    if (result.failed > 0) {
      if (msg.isNotEmpty) msg.write('，');
      msg.write('${result.failed} 束润色失败');
    }
    if (msg.isEmpty) msg.write('没有生成新的润色内容。');
    showOverlaySnackBar(
      context,
      SnackBar(
        content: Text(msg.toString()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Fragment> _selectedFragments(
    AsyncValue<List<DateGroup>> timeline,
    AsyncValue<List<Fragment>> fragments,
  ) {
    final byId = <int, Fragment>{};
    for (final group in timeline.valueOrNull ?? const []) {
      for (final item in group.fragments) {
        final fragment = _fromDomainFragment(item);
        byId[fragment.id] = fragment;
      }
    }
    for (final fragment in fragments.valueOrNull ?? const []) {
      byId[fragment.id] = fragment;
    }
    return _selectedIds
        .map((id) => byId[id])
        .whereType<Fragment>()
        .where((fragment) => fragment.contentText.trim().isNotEmpty)
        .toList();
  }

  bool _passesFilters(Fragment item) {
    final selected = _selectedMonth;
    if (selected == null) return true;
    final local = item.createdAt.toLocal();
    return local.year == selected.year && local.month == selected.month;
  }

  List<DateTime> _availableMonths(List<Fragment> items) {
    final keys = <String, DateTime>{};
    for (final item in items) {
      final local = item.createdAt.toLocal();
      final month = DateTime(local.year, local.month);
      keys['${month.year}-${month.month}'] = month;
    }
    final months = keys.values.toList()..sort((a, b) => b.compareTo(a));
    return months;
  }

  List<({String label, List<Fragment> items})> _groupVisibleItems(
      List<Fragment> items) {
    final sorted = [...items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final groups = <String, List<Fragment>>{};
    for (final item in sorted) {
      groups.putIfAbsent(_fullDateLabel(item.createdAt), () => []).add(item);
    }
    return groups.entries
        .map((entry) => (label: entry.key, items: entry.value))
        .toList();
  }

  Future<void> _showMonthPicker(List<Fragment> items) async {
    final months = _availableMonths(items);
    final initial = _selectedMonth ?? (months.isNotEmpty ? months.first : null);
    final picked = await showModalBottomSheet<MonthPickerResult>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MonthPickerSheet(
        months: months,
        selectedMonth: initial,
      ),
    );
    if (!mounted || picked == null) return;
    final month = picked.month;
    final sameSelection = month == null && _selectedMonth == null ||
        month != null &&
            _selectedMonth != null &&
            month.year == _selectedMonth!.year &&
            month.month == _selectedMonth!.month;
    if (sameSelection) return;
    if (month != null && !months.any((item) => _sameMonth(item, month))) {
      showOverlaySnackBar(
        context,
        SnackBar(
          content: Text('${month.year}年${month.month}月还没有光片。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _selectedMonth = month);
  }
}

String _fullDateLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.year}年${local.month}月${local.day}日';
}

bool _sameMonth(DateTime value, DateTime month) {
  final local = value.toLocal();
  return local.year == month.year && local.month == month.month;
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('TIME RIVER', style: AppText.eyebrow.copyWith(color: theme.accent)),
      const SizedBox(height: AppSpacing.sm),
      Text('线', style: AppText.hero.copyWith(color: theme.foreground)),
      const SizedBox(height: AppSpacing.s12),
      Text(
        '人心绪随时间自流。',
        style: AppText.body.copyWith(color: theme.foreground),
      ),
    ]);
  }
}

extension _LightFragmentAdapter on Fragment {
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
      mediaUrls: mediaUrls,
    );
  }
}

Fragment _fromDomainFragment(Fragment fragment) => fragment;

Fragment _withRelation(Fragment fragment, String? relation) {
  if (relation == null || relation.isEmpty) return fragment;
  return fragment.copyWith(status: relation);
}

class _TimelineLoadingState extends StatelessWidget {
  const _TimelineLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final background = theme.surfaceHigh.withValues(alpha: .72);
    final border = theme.border.withValues(alpha: .88);
    final shimmer = theme.accent.withValues(alpha: .10);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.s15, AppSpacing.md, AppSpacing.s15),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border),
          ),
          child: Row(children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: theme.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '正在捞取旧光',
                    style: AppText.titleSmall.copyWith(color: theme.foreground),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '如果河面暂时安静，会先保留本地已经落下的光。',
                    style:
                        AppText.caption.copyWith(color: theme.foregroundMuted),
                  ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.s12),
        for (var i = 0; i < 2; i++) ...[
          Container(
            height: 74,
            margin: const EdgeInsets.only(bottom: AppSpacing.s9),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: border),
            ),
            padding: const EdgeInsets.all(AppSpacing.s14),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: shimmer,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LoadingBar(widthFactor: i == 0 ? .76 : .62),
                    const SizedBox(height: AppSpacing.s9),
                    _LoadingBar(widthFactor: i == 0 ? .46 : .54),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.teaGreen.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.count,
    required this.deleting,
    required this.polishing,
    required this.polishEnabled,
    required this.onCancel,
    required this.onPolish,
    required this.onDelete,
  });

  final int count;
  final bool deleting;
  final bool polishing;
  final bool polishEnabled;
  final VoidCallback? onCancel;
  final VoidCallback? onPolish;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);

    return Positioned(
      left: 18,
      right: 18,
      // 抬到浮岛导航上方，避免与底部功能岛重叠（§9.4 pageBottomNav）
      bottom: AppSpacing.pageBottomNav,
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.s14,
                    AppSpacing.s12, AppSpacing.s12, AppSpacing.s12),
                decoration: BoxDecoration(
                  color: theme.surfaceHigh.withValues(
                    alpha: theme.isNight ? .96 : .98,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: theme.border.withValues(alpha: .95),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: theme.isNight ? .24 : .12,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(
                        alpha: theme.isNight ? .18 : .14,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      Icons.checklist_rounded,
                      size: 19,
                      color: theme.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Text(
                      '已选 $count 束光',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppText.titleSmall.copyWith(color: theme.foreground),
                    ),
                  ),
                  TextButton(
                    onPressed: onCancel,
                    child: Text(
                      '取消',
                      style:
                          AppText.chip.copyWith(color: theme.foregroundMuted),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s6),
                  if (polishEnabled) ...[
                    OutlinedButton.icon(
                      onPressed: onPolish,
                      icon: polishing
                          ? SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.teaGreen,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_outlined, size: 17),
                      label: Text(polishing ? '润色中' : 'AI 润色'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(96, 40),
                        foregroundColor: theme.accent,
                        side: BorderSide(
                          color: AppColors.teaGreen.withValues(alpha: .58),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s6),
                  ],
                  FilledButton.icon(
                    onPressed: onDelete,
                    icon: deleting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white.withValues(alpha: .78),
                            ),
                          )
                        : const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(deleting ? '删除中' : '删除'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(86, 40),
                      backgroundColor: AppColors.sunsetCoral,
                      foregroundColor: AppColors.white,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineControls extends StatelessWidget {
  const _TimelineControls({
    required this.selectedMonth,
    required this.onSelected,
    required this.onOpenPicker,
  });

  final DateTime? selectedMonth;
  final ValueChanged<DateTime?> onSelected;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context) {
    return _DateNavigationBar(
      selectedMonth: selectedMonth,
      onSelected: onSelected,
      onOpenPicker: onOpenPicker,
    );
  }
}

class _DateNavigationBar extends StatelessWidget {
  const _DateNavigationBar({
    required this.selectedMonth,
    required this.onSelected,
    required this.onOpenPicker,
  });

  final DateTime? selectedMonth;
  final ValueChanged<DateTime?> onSelected;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final border = theme.border.withValues(alpha: .92);
    final monthLabel = selectedMonth == null
        ? '全部旧光'
        : '${selectedMonth!.year}年${selectedMonth!.month}月';

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.surfaceHigh.withValues(alpha: .56),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        _DateNavigationItem(
          label: '全部',
          selected: selectedMonth == null,
          onTap: () => onSelected(null),
        ),
        if (selectedMonth != null) ...[
          Container(width: 1, height: 22, color: border),
          _DateNavigationItem(
            label: monthLabel,
            selected: true,
            onTap: onOpenPicker,
          ),
        ],
        const Spacer(),
        Container(width: 1, height: 22, color: border),
        IconButton(
          tooltip: '选择月份',
          onPressed: onOpenPicker,
          icon: Icon(
            Icons.calendar_month_outlined,
            size: 17,
            color: theme.foregroundMuted,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        ),
      ]),
    );
  }
}

class _DateNavigationItem extends StatelessWidget {
  const _DateNavigationItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: AppMotion.quick,
          height: 38,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? theme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            label,
            style: AppText.chip.copyWith(
              color: selected ? AppColors.white : theme.foregroundMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateRail extends StatelessWidget {
  const _DateRail({
    required this.label,
    required this.count,
  });
  final String label, count;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Padding(
      padding:
          const EdgeInsets.only(bottom: AppSpacing.s10, top: AppSpacing.sm),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.accent.withValues(
              alpha: theme.isNight ? .18 : .12,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: theme.accent.withValues(
                alpha: theme.isNight ? .28 : .22,
              ),
            ),
          ),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: theme.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s9),
        Text(
          label,
          style: AppText.bodyStrong.copyWith(color: theme.foregroundMuted),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s7, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: theme.surfaceHigh.withValues(alpha: .64),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            count,
            style: AppText.caption
                .copyWith(color: theme.foregroundMuted, height: 1),
          ),
        ),
      ]),
    );
  }
}

/// C1: Lightweight data class for date rail headers in the virtualized list.
class _DateRailItem {
  const _DateRailItem({required this.label, required this.count});
  final String label;
  final int count;
}
