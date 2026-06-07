import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../features/ai/data/ai_api.dart';
import '../../../../features/fragment/data/fragment_repository.dart';
import '../../../../features/relation/domain/relation.dart';
import '../../../../features/timeline/domain/date_group.dart';
import '../../../../features/timeline/presentation/providers/timeline_provider.dart';
import '../../../../ui/composites/light_card.dart';
import '../../../../ui/composites/night_mode_button.dart';
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
  DateTime? _selectedMonth;
  final Set<int> _selectedIds = {};
  bool _deleting = false;
  bool _polishing = false;

  bool get _selectionMode => _selectedIds.isNotEmpty;
  bool get _busy => _deleting || _polishing;

  @override
  Widget build(BuildContext context) {
    final fragments = ref.watch(fragmentsProvider);
    final timeline = ref.watch(timelineGroupsProvider);
    final nightMode = ref.watch(nightModeProvider);
    final polishEnabled = ref.watch(aiPolishEnabledProvider);
    final relationByFragment =
        _relationByFragment(ref.watch(relationsProvider));
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(22, 18, 22, _selectionMode ? 156 : 104),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(nightMode: nightMode),
                    const SizedBox(height: 10),
                    timeline.when(
                      data: (groups) {
                        final items = groups
                            .expand((group) => group.fragments)
                            .map(_fromDomainFragment)
                            .map((fragment) => _withRelation(
                                  fragment,
                                  relationByFragment[fragment.id],
                                ))
                            .toList();
                        final months = _availableMonths(items);
                        return _DateNavigationBar(
                          selectedMonth: _selectedMonth,
                          availableMonths: months,
                          nightMode: nightMode,
                          onSelected: (month) =>
                              setState(() => _selectedMonth = month),
                          onOpenPicker: () =>
                              _showMonthPicker(items, nightMode),
                        );
                      },
                      loading: () => const SizedBox(height: 32),
                      error: (_, __) => fragments.when(
                        data: (items) => _DateNavigationBar(
                          selectedMonth: _selectedMonth,
                          availableMonths: _availableMonths(items),
                          nightMode: nightMode,
                          onSelected: (month) =>
                              setState(() => _selectedMonth = month),
                          onOpenPicker: () =>
                              _showMonthPicker(items, nightMode),
                        ),
                        loading: () => const SizedBox(height: 32),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    timeline.when(
                      data: (groups) {
                        final visibleGroups = _groupVisibleItems(groups
                            .expand((group) => group.fragments)
                            .map(_fromDomainFragment)
                            .map((fragment) => _withRelation(
                                  fragment,
                                  relationByFragment[fragment.id],
                                ))
                            .where(_passesFilters)
                            .toList());
                        if (visibleGroups.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Text(
                              '还没有这样的旧光。',
                              style: AppText.onNight(AppText.body, nightMode),
                            ),
                          );
                        }
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final group in visibleGroups) ...[
                                _DateRail(
                                    label: group.label,
                                    count: '${group.items.length} 束光',
                                    nightMode: nightMode),
                                ...group.items.map((f) => LightFragmentCard(
                                      tapKey: ValueKey('timeline-card-${f.id}'),
                                      fragment: f.toLightFragment(),
                                      dense: true,
                                      showAttachmentBadge: true,
                                      showTitle: false,
                                      selectionMode: _selectionMode,
                                      showSelectionControl: true,
                                      selected: _selectedIds.contains(f.id),
                                      onSelectionTap: () =>
                                          _toggleSelection(f.id),
                                      onTap: () => _selectionMode
                                          ? _toggleSelection(f.id)
                                          : context.push('/fragments/${f.id}'),
                                      onLongPress: () => _startSelection(f.id),
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
                          relationByFragment: relationByFragment,
                          selectedMonth: _selectedMonth,
                          nightMode: nightMode,
                          selectionMode: _selectionMode,
                          selectedIds: _selectedIds,
                          onToggleSelection: _toggleSelection,
                          onStartSelection: _startSelection,
                        ),
                        loading: () => Text('时间河暂时变浅了：$error',
                            style: AppText.onNight(AppText.body, nightMode)),
                        error: (_, __) => Text('时间河暂时变浅了：$error',
                            style: AppText.onNight(AppText.body, nightMode)),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      ),
      if (_selectionMode)
        _SelectionActionBar(
          count: _selectedIds.length,
          nightMode: nightMode,
          deleting: _deleting,
          polishing: _polishing,
          polishEnabled: polishEnabled,
          onCancel: _busy ? null : _clearSelection,
          onPolish: _busy ? null : () => _polishSelected(timeline, fragments),
          onDelete: _busy ? null : _deleteSelected,
        ),
    ]);
  }

  Map<int, String> _relationByFragment(AsyncValue<List<Relation>> relations) {
    final result = <int, String>{};
    for (final relation in relations.valueOrNull ?? const <Relation>[]) {
      result[relation.sourceFragmentId] ??= relation.relationType;
      result[relation.targetFragmentId] ??= relation.relationType;
    }
    return result;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除 ${ids.length} 束光。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('删除失败，请稍后再试。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _polishSelected(
    AsyncValue<List<DateGroup>> timeline,
    AsyncValue<List<LightFragmentModel>> fragments,
  ) async {
    if (_busy || _selectedIds.isEmpty) return;
    final selected = _selectedFragments(timeline, fragments);
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有找到可润色的光。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _polishing = true);
    var success = 0;
    var failed = 0;
    final api = AIApi(ref.read(apiClientProvider));
    final repository = ref.read(fragmentRepositoryProvider);
    for (final fragment in selected) {
      if (fragment.contentText.trim().isEmpty) continue;
      try {
        final result =
            await api.polishFragment(fragment.contentText, fragment.emotion);
        if (result['status'] == 'error') {
          failed++;
          continue;
        }
        final polished = (result['polished_text'] as String? ?? '').trim();
        if (polished.isEmpty) continue;
        await repository.updateFragmentText(
          fragment.id,
          polished,
          emotion: fragment.emotion,
          tags: fragment.tags,
        );
        success++;
      } catch (_) {
        failed++;
      }
    }
    ref.invalidate(fragmentsProvider);
    ref.invalidate(timelineGroupsProvider);
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _polishing = false;
    });
    final msg = StringBuffer();
    if (success > 0) msg.write('已润色 $success 束光');
    if (failed > 0) {
      if (msg.isNotEmpty) msg.write('，');
      msg.write('$failed 束润色失败');
    }
    if (msg.isEmpty) msg.write('没有生成新的润色内容。');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.toString()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<LightFragmentModel> _selectedFragments(
    AsyncValue<List<DateGroup>> timeline,
    AsyncValue<List<LightFragmentModel>> fragments,
  ) {
    final byId = <int, LightFragmentModel>{};
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
        .whereType<LightFragmentModel>()
        .where((fragment) => fragment.contentText.trim().isNotEmpty)
        .toList();
  }

  bool _passesFilters(LightFragmentModel item) {
    final selected = _selectedMonth;
    if (selected == null) return true;
    final local = item.createdAt.toLocal();
    return local.year == selected.year && local.month == selected.month;
  }

  List<DateTime> _availableMonths(List<LightFragmentModel> items) {
    final keys = <String, DateTime>{};
    for (final item in items) {
      final local = item.createdAt.toLocal();
      final month = DateTime(local.year, local.month);
      keys['${month.year}-${month.month}'] = month;
    }
    final months = keys.values.toList()..sort((a, b) => b.compareTo(a));
    return months;
  }

  List<({String label, List<LightFragmentModel> items})> _groupVisibleItems(
      List<LightFragmentModel> items) {
    final sorted = [...items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final groups = <String, List<LightFragmentModel>>{};
    for (final item in sorted) {
      groups.putIfAbsent(_fullDateLabel(item.createdAt), () => []).add(item);
    }
    return groups.entries
        .map((entry) => (label: entry.key, items: entry.value))
        .toList();
  }

  Future<void> _showMonthPicker(
      List<LightFragmentModel> items, bool nightMode) async {
    final months = _availableMonths(items);
    final initial = _selectedMonth ?? (months.isNotEmpty ? months.first : null);
    final picked = await showModalBottomSheet<_MonthPickerResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MonthPickerSheet(
        months: months,
        selectedMonth: initial,
        nightMode: nightMode,
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
      ScaffoldMessenger.of(context).showSnackBar(
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

class _MonthPickerResult {
  const _MonthPickerResult(this.month);

  final DateTime? month;
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
  const _Header({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('TIME RIVER', style: AppText.onNight(AppText.eyebrow, nightMode)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: Text('线', style: AppText.onNight(AppText.hero, nightMode)),
        ),
        const NightModeButton(),
      ]),
      const SizedBox(height: 12),
      Text('人心绪随时间自流。', style: AppText.onNight(AppText.body, nightMode)),
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
      mediaUrls: mediaUrls,
    );
  }
}

LightFragmentModel _fromDomainFragment(dynamic fragment) {
  int safeId(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);
  String safeStr(dynamic v) => v is String ? v : (v?.toString() ?? '');
  List<String> safeStrList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }
  DateTime safeDateTime(dynamic v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
  return LightFragmentModel(
    id: safeId(fragment.id),
    contentText: safeStr(fragment.contentText),
    emotion: safeStr(fragment.emotion).isEmpty ? '说不清' : safeStr(fragment.emotion),
    tags: safeStrList(fragment.tags),
    mediaUrls: safeStrList(fragment.mediaUrls),
    createdAt: safeDateTime(fragment.createdAt),
    status: safeStr(fragment.status).isEmpty ? 'twilight' : safeStr(fragment.status),
  );
}

LightFragmentModel _withRelation(
    LightFragmentModel fragment, String? relation) {
  if (relation == null || relation.isEmpty) return fragment;
  return LightFragmentModel(
    id: fragment.id,
    contentText: fragment.contentText,
    emotion: fragment.emotion,
    tags: fragment.tags,
    mediaUrls: fragment.mediaUrls,
    createdAt: fragment.createdAt,
    status: relation,
  );
}

class _FallbackTimeline extends StatelessWidget {
  const _FallbackTimeline({
    required this.items,
    required this.relationByFragment,
    required this.selectedMonth,
    required this.nightMode,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onStartSelection,
  });

  final List<LightFragmentModel> items;
  final Map<int, String> relationByFragment;
  final DateTime? selectedMonth;
  final bool nightMode;
  final bool selectionMode;
  final Set<int> selectedIds;
  final ValueChanged<int> onToggleSelection;
  final ValueChanged<int> onStartSelection;

  @override
  Widget build(BuildContext context) {
    final visible = items.where((item) {
      final month = selectedMonth;
      return month == null || _sameMonth(item.createdAt, month);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child:
            Text('还没有这样的旧光。', style: AppText.onNight(AppText.body, nightMode)),
      );
    }
    final labels =
        visible.map((item) => _fullDateLabel(item.createdAt)).toSet().toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final label in labels) ...[
        _DateRail(
          label: label,
          count:
              '${visible.where((f) => _fullDateLabel(f.createdAt) == label).length} 束光',
          nightMode: nightMode,
        ),
        ...visible.where((f) => _fullDateLabel(f.createdAt) == label).map(
              (f) => LightFragmentCard(
                tapKey: ValueKey('timeline-card-${f.id}'),
                fragment: _withRelation(f, relationByFragment[f.id])
                    .toLightFragment(),
                dense: true,
                showAttachmentBadge: true,
                showTitle: false,
                selectionMode: selectionMode,
                showSelectionControl: true,
                selected: selectedIds.contains(f.id),
                onSelectionTap: () => onToggleSelection(f.id),
                onTap: () => selectionMode
                    ? onToggleSelection(f.id)
                    : context.push('/fragments/${f.id}'),
                onLongPress: () => onStartSelection(f.id),
              ),
            ),
        const SizedBox(height: 8),
      ],
    ]);
  }
}

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.count,
    required this.nightMode,
    required this.deleting,
    required this.polishing,
    required this.polishEnabled,
    required this.onCancel,
    required this.onPolish,
    required this.onDelete,
  });

  final int count;
  final bool nightMode;
  final bool deleting;
  final bool polishing;
  final bool polishEnabled;
  final VoidCallback? onCancel;
  final VoidCallback? onPolish;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final background = nightMode ? const Color(0xFF203437) : AppColors.white;
    final foreground = nightMode ? AppText.nightInk : AppColors.ink;
    final muted = nightMode ? AppText.nightInkMuted : AppColors.inkMuted;
    final border = nightMode
        ? Colors.white.withValues(alpha: .14)
        : AppColors.line.withValues(alpha: .95);

    return Positioned(
      left: 18,
      right: 18,
      bottom: 18,
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                decoration: BoxDecoration(
                  color: background.withValues(alpha: nightMode ? .96 : .98),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: nightMode ? .24 : .12,
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
                      color: AppColors.teaGreen.withValues(
                        alpha: nightMode ? .18 : .14,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.checklist_rounded,
                      size: 19,
                      color: nightMode ? AppColors.teaGreen : AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '已选 $count 束光',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.titleSmall.copyWith(color: foreground),
                    ),
                  ),
                  TextButton(
                    onPressed: onCancel,
                    child: Text(
                      '取消',
                      style: AppText.chip.copyWith(color: muted),
                    ),
                  ),
                  const SizedBox(width: 6),
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
                        foregroundColor:
                            nightMode ? AppColors.teaGreen : AppColors.ink,
                        side: BorderSide(
                          color: AppColors.teaGreen.withValues(alpha: .58),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  FilledButton.icon(
                    onPressed: onDelete,
                    icon: deleting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.ink.withValues(alpha: .78),
                            ),
                          )
                        : const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(deleting ? '删除中' : '删除'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(86, 40),
                      backgroundColor: AppColors.sunsetCoral,
                      foregroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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

class _DateNavigationBar extends StatelessWidget {
  const _DateNavigationBar({
    required this.selectedMonth,
    required this.availableMonths,
    required this.nightMode,
    required this.onSelected,
    required this.onOpenPicker,
  });

  final DateTime? selectedMonth;
  final List<DateTime> availableMonths;
  final bool nightMode;
  final ValueChanged<DateTime?> onSelected;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context) {
    final muted = nightMode ? AppText.nightInkMuted : AppColors.inkMuted;
    final border = nightMode
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.line.withValues(alpha: 0.92);
    final visibleMonths = availableMonths.take(3).toList();

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: nightMode
            ? Colors.white.withValues(alpha: .07)
            : AppColors.white.withValues(alpha: .56),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _DateNavigationItem(
                label: '全部',
                selected: selectedMonth == null,
                nightMode: nightMode,
                onTap: () => onSelected(null),
              ),
              for (final month in visibleMonths)
                _DateNavigationItem(
                  label: '${month.month}月',
                  selected: selectedMonth != null &&
                      _sameMonth(month, selectedMonth!),
                  nightMode: nightMode,
                  onTap: () => onSelected(month),
                ),
            ]),
          ),
        ),
        Container(width: 1, height: 22, color: border),
        IconButton(
          tooltip: '选择月份',
          onPressed: onOpenPicker,
          icon: Icon(Icons.calendar_month_outlined, size: 17, color: muted),
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
    required this.nightMode,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool nightMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 38,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected
                ? (nightMode ? AppColors.teaGreen : AppColors.ink)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: AppText.chip.copyWith(
              fontSize: 11,
              color: selected
                  ? Colors.white
                  : (nightMode ? AppText.nightInkMuted : AppColors.inkMuted),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({
    required this.months,
    required this.selectedMonth,
    required this.nightMode,
  });

  final List<DateTime> months;
  final DateTime? selectedMonth;
  final bool nightMode;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final initial = widget.selectedMonth ?? DateTime(now.year, now.month);
    _year = initial.year;
    _month = initial.month;
  }

  List<int> get _years {
    final years = widget.months.map((month) => month.year).toList();
    years.add(DateTime.now().year);
    years.add(_year);
    final minYear = years.reduce((a, b) => a < b ? a : b) - 2;
    final maxYear = years.reduce((a, b) => a > b ? a : b) + 2;
    return [for (var year = maxYear; year >= minYear; year--) year];
  }

  List<int> get _monthsForYear {
    return const [12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1];
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.nightMode ? AppText.nightInk : AppColors.ink;
    final muted = widget.nightMode ? AppText.nightInkMuted : AppColors.inkMuted;
    final sheetColor =
        widget.nightMode ? const Color(0xFF203437) : AppColors.white;
    final lineColor = widget.nightMode
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.line;
    final selected = DateTime(_year, _month);

    final maxHeight = MediaQuery.sizeOf(context).height * .72;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pickerHeight =
                (constraints.maxHeight - 154).clamp(76.0, 128.0);
            return Container(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: Text(
                        '按日期筛选',
                        style: AppText.onNight(
                            AppText.titleMedium, widget.nightMode),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(72, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.of(context)
                          .pop(const _MonthPickerResult(null)),
                      child: Text(
                        '全部日期',
                        style: AppText.chip.copyWith(color: AppColors.teaGreen),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Divider(color: lineColor, height: 1),
                  SizedBox(
                    height: pickerHeight,
                    child: Row(children: [
                      Expanded(
                        child: _PickerColumn(
                          values: _years,
                          selectedValue: _year,
                          suffix: '年',
                          foreground: foreground,
                          muted: muted,
                          nightMode: widget.nightMode,
                          onSelected: (value) => setState(() => _year = value),
                        ),
                      ),
                      Container(
                          width: 1,
                          height: (pickerHeight - 28).clamp(44.0, 82.0),
                          color: lineColor),
                      Expanded(
                        child: _PickerColumn(
                          values: _monthsForYear,
                          selectedValue: _month,
                          suffix: '月',
                          foreground: foreground,
                          muted: muted,
                          nightMode: widget.nightMode,
                          onSelected: (value) => setState(() => _month = value),
                        ),
                      ),
                    ]),
                  ),
                  Divider(color: lineColor, height: 1),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(color: lineColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          '取消',
                          style: AppText.chip.copyWith(color: muted),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context)
                            .pop(_MonthPickerResult(selected)),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: AppColors.teaGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('确定'),
                      ),
                    ),
                  ]),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PickerColumn extends StatelessWidget {
  const _PickerColumn({
    required this.values,
    required this.selectedValue,
    required this.suffix,
    required this.foreground,
    required this.muted,
    required this.nightMode,
    required this.onSelected,
  });

  final List<int> values;
  final int selectedValue;
  final String suffix;
  final Color foreground;
  final Color muted;
  final bool nightMode;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      itemCount: values.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final value = values[index];
        final selected = value == selectedValue;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onSelected(value),
            child: Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.teaGreen
                        .withValues(alpha: nightMode ? 0.18 : 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$value$suffix',
                style: AppText.titleSmall.copyWith(
                  color: selected ? foreground : muted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DateRail extends StatelessWidget {
  const _DateRail({
    required this.label,
    required this.count,
    required this.nightMode,
  });
  final String label, count;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 5),
      child: Row(children: [
        Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: AppColors.teaGreen, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(
          label,
          style: AppText.onNight(AppText.titleSmall, nightMode).copyWith(
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 7),
        Text(count, style: AppText.onNight(AppText.caption, nightMode)),
      ]),
    );
  }
}
