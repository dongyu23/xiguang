import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../features/fragment/domain/fragment.dart';
import '../../../fragment/presentation/providers/fragment_providers.dart';
import '../../../../ui/composites/xiguang_bottom_sheet.dart';
import '../../../../ui/composites/xiguang_chip.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';

class FragmentPickerSheet extends ConsumerStatefulWidget {
  const FragmentPickerSheet({
    super.key,
    required this.onConfirm,
    this.excludedFragmentIds = const {},
  });

  final FutureOr<bool> Function(List<int> fragmentIds) onConfirm;
  final Set<int> excludedFragmentIds;

  @override
  ConsumerState<FragmentPickerSheet> createState() =>
      _FragmentPickerSheetState();
}

class _FragmentPickerSheetState extends ConsumerState<FragmentPickerSheet> {
  final _selected = <int>{};
  final _searchController = TextEditingController();
  String _search = '';
  final _activeTags = <String>{};
  final _activeEmotions = <String>{};
  final _activeMedia = <_MediaFilter>{};
  _TimeFilter _timeFilter = _TimeFilter.any;
  _SortOrder _sortOrder = _SortOrder.newest;
  bool _filtersExpanded = false;
  bool _submitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fragmentsAsync = ref.watch(fragmentsProvider);
    final theme = NightTheme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: .82,
      minChildSize: .56,
      maxChildSize: .94,
      expand: false,
      builder: (context, scrollController) {
        return XiguangBottomSheet(
          child: Column(
            children: [
              _SheetHandle(color: theme.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s6,
                  AppSpacing.s14,
                  0,
                  AppSpacing.s14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '把光放进小岛',
                            style: AppText.titleLarge
                                .copyWith(color: theme.foreground),
                          ),
                          const SizedBox(height: AppSpacing.s5),
                          Text(
                            '轻点光片，可以同时选择多束',
                            style: AppText.caption
                                .copyWith(color: theme.foregroundMuted),
                          ),
                        ],
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: AppMotion.selection,
                      child: _selected.isEmpty
                          ? const SizedBox(width: 36)
                          : Container(
                              key: ValueKey(_selected.length),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s10,
                                vertical: AppSpacing.s6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.accent.withValues(alpha: .13),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                '已选 ${_selected.length}',
                                style: AppText.captionStrong
                                    .copyWith(color: theme.accent),
                              ),
                            ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded,
                          color: theme.foregroundMuted),
                    ),
                  ],
                ),
              ),
              _SearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value.trim()),
              ),
              const SizedBox(height: AppSpacing.s10),
              Expanded(
                child: fragmentsAsync.when(
                  data: (fragments) => _buildContent(
                    fragments,
                    scrollController,
                    theme,
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => Center(
                    child: Text(
                      '暂时无法加载光片。',
                      style: AppText.body.copyWith(color: theme.foreground),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s10),
              SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    key: const ValueKey('fragment-picker-confirm'),
                    onPressed: _selected.isEmpty || _submitting
                        ? null
                        : _confirmSelection,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.accent,
                      foregroundColor: theme.background,
                      disabledBackgroundColor:
                          theme.foregroundMuted.withValues(alpha: .10),
                      disabledForegroundColor:
                          theme.foregroundMuted.withValues(alpha: .65),
                      shape: const StadiumBorder(),
                    ),
                    child: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _selected.isEmpty
                                ? '选择想放入的光片'
                                : '放入小岛 · ${_selected.length} 束',
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(
    List<Fragment> fragments,
    ScrollController scrollController,
    NightTheme theme,
  ) {
    final available = fragments
        .where((fragment) => !widget.excludedFragmentIds.contains(fragment.id))
        .toList();
    if (available.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: XiguangEmptyState(
            title: '没有可继续添加的光片',
            description: '这座小岛已经收好了当前可用的光。',
          ),
        ),
      );
    }

    final allTags =
        available.expand((fragment) => fragment.tags).toSet().toList()..sort();
    final allEmotions =
        available.map((fragment) => fragment.emotion).toSet().toList()..sort();
    final filtered = available.where((fragment) {
      final matchesSearch = _search.isEmpty ||
          fragment.contentText.toLowerCase().contains(_search.toLowerCase());
      final matchesTags =
          _activeTags.isEmpty || fragment.tags.any(_activeTags.contains);
      final matchesEmotion =
          _activeEmotions.isEmpty || _activeEmotions.contains(fragment.emotion);
      final matchesTime = _matchesTime(fragment.createdAt);
      final matchesMedia = _matchesMedia(fragment);
      return matchesSearch &&
          matchesTags &&
          matchesEmotion &&
          matchesTime &&
          matchesMedia;
    }).toList()
      ..sort((a, b) => _sortOrder == _SortOrder.newest
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt));

    return Column(
      children: [
        Row(
          children: [
            TextButton.icon(
              key: const ValueKey('fragment-picker-filter-toggle'),
              onPressed: () =>
                  setState(() => _filtersExpanded = !_filtersExpanded),
              icon: Icon(
                _filtersExpanded ? Icons.tune_rounded : Icons.tune_outlined,
                size: 18,
              ),
              label: Text(
                _activeFilterCount == 0 ? '筛选' : '筛选 · $_activeFilterCount',
              ),
            ),
            const Spacer(),
            Text(
              '找到 ${filtered.length} 束',
              style: AppText.caption.copyWith(color: theme.foregroundMuted),
            ),
            if (_activeFilterCount > 0) ...[
              const SizedBox(width: AppSpacing.s6),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('清空'),
              ),
            ],
          ],
        ),
        AnimatedSize(
          duration: AppMotion.normal,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_filtersExpanded
              ? const SizedBox.shrink()
              : _FilterPanel(
                  emotions: allEmotions,
                  tags: allTags,
                  selectedEmotions: _activeEmotions,
                  selectedTags: _activeTags,
                  selectedMedia: _activeMedia,
                  timeFilter: _timeFilter,
                  sortOrder: _sortOrder,
                  onEmotion: (emotion) =>
                      setState(() => _toggleValue(_activeEmotions, emotion)),
                  onTag: (tag) =>
                      setState(() => _toggleValue(_activeTags, tag)),
                  onMedia: (media) =>
                      setState(() => _toggleValue(_activeMedia, media)),
                  onTime: (time) => setState(() => _timeFilter = time),
                  onSort: (sort) => setState(() => _sortOrder = sort),
                ),
        ),
        const SizedBox(height: AppSpacing.s6),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    '没有找到这样的光。',
                    style: AppText.bodyMuted
                        .copyWith(color: theme.foregroundMuted),
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: AppSpacing.s6),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.s6),
                  itemBuilder: (context, index) {
                    final fragment = filtered[index];
                    return _SelectableFragmentRow(
                      fragment: fragment,
                      selected: _selected.contains(fragment.id),
                      onTap: () => _toggle(fragment.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _toggle(int id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  int get _activeFilterCount =>
      _activeTags.length +
      _activeEmotions.length +
      _activeMedia.length +
      (_timeFilter == _TimeFilter.any ? 0 : 1) +
      (_sortOrder == _SortOrder.newest ? 0 : 1);

  void _toggleValue<T>(Set<T> values, T value) {
    if (!values.add(value)) values.remove(value);
  }

  bool _matchesTime(DateTime createdAt) {
    final now = DateTime.now();
    final local = createdAt.toLocal();
    return switch (_timeFilter) {
      _TimeFilter.any => true,
      _TimeFilter.today => local.year == now.year &&
          local.month == now.month &&
          local.day == now.day,
      _TimeFilter.week => local.isAfter(now.subtract(AppTiming.recentWeek)),
      _TimeFilter.month => local.isAfter(now.subtract(AppTiming.recentMonth)),
      _TimeFilter.year => local.year == now.year,
    };
  }

  bool _matchesMedia(Fragment fragment) {
    if (_activeMedia.isEmpty) return true;
    final hasImage = fragment.mediaUrls.any(_isImageSource);
    final hasAudio = fragment.mediaUrls.any(_isAudioSource);
    return (_activeMedia.contains(_MediaFilter.text) &&
            fragment.contentText.trim().isNotEmpty) ||
        (_activeMedia.contains(_MediaFilter.image) && hasImage) ||
        (_activeMedia.contains(_MediaFilter.audio) && hasAudio);
  }

  void _clearFilters() {
    setState(() {
      _activeTags.clear();
      _activeEmotions.clear();
      _activeMedia.clear();
      _timeFilter = _TimeFilter.any;
      _sortOrder = _SortOrder.newest;
    });
  }

  Future<void> _confirmSelection() async {
    setState(() => _submitting = true);
    var shouldClose = false;
    try {
      shouldClose = await widget.onConfirm(_selected.toList());
    } catch (_) {
      if (mounted) {
        showOverlaySnackBar(
          context,
          const SnackBar(content: Text('暂时无法添加这些光片。')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted || !shouldClose) return;
    Navigator.of(context).pop();
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return SizedBox(
      height: 46,
      child: TextField(
        key: const ValueKey('fragment-picker-search'),
        controller: controller,
        onChanged: onChanged,
        style: AppText.body.copyWith(color: theme.foreground),
        decoration: InputDecoration(
          hintText: '找一束光',
          prefixIcon: Icon(Icons.search_rounded,
              size: 20, color: theme.foregroundMuted),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除搜索',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          filled: true,
          fillColor: theme.foreground.withValues(alpha: .045),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            borderSide: BorderSide(
              color: theme.accent.withValues(alpha: .55),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
      ),
    );
  }
}

enum _TimeFilter { any, today, week, month, year }

enum _MediaFilter { text, image, audio }

enum _SortOrder { newest, oldest }

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.emotions,
    required this.tags,
    required this.selectedEmotions,
    required this.selectedTags,
    required this.selectedMedia,
    required this.timeFilter,
    required this.sortOrder,
    required this.onEmotion,
    required this.onTag,
    required this.onMedia,
    required this.onTime,
    required this.onSort,
  });

  final List<String> emotions;
  final List<String> tags;
  final Set<String> selectedEmotions;
  final Set<String> selectedTags;
  final Set<_MediaFilter> selectedMedia;
  final _TimeFilter timeFilter;
  final _SortOrder sortOrder;
  final ValueChanged<String> onEmotion;
  final ValueChanged<String> onTag;
  final ValueChanged<_MediaFilter> onMedia;
  final ValueChanged<_TimeFilter> onTime;
  final ValueChanged<_SortOrder> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Container(
      key: const ValueKey('fragment-picker-filter-panel'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s12,
        AppSpacing.s10,
        AppSpacing.s12,
        AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: theme.foreground.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: theme.border.withValues(alpha: .55)),
      ),
      child: Column(
        children: [
          _FilterSection(
            label: '情绪',
            children: [
              for (final emotion in emotions)
                XiguangChip(
                  label: emotion,
                  selected: selectedEmotions.contains(emotion),
                  onSelected: (_) => onEmotion(emotion),
                ),
            ],
          ),
          _FilterSection(
            label: '时间',
            children: [
              for (final entry in const {
                _TimeFilter.any: '不限',
                _TimeFilter.today: '今天',
                _TimeFilter.week: '近 7 天',
                _TimeFilter.month: '近 30 天',
                _TimeFilter.year: '今年',
              }.entries)
                XiguangChip(
                  label: entry.value,
                  selected: timeFilter == entry.key,
                  onSelected: (_) => onTime(entry.key),
                ),
            ],
          ),
          _FilterSection(
            label: '媒介',
            children: [
              for (final entry in const {
                _MediaFilter.text: '文字',
                _MediaFilter.image: '图片',
                _MediaFilter.audio: '声音',
              }.entries)
                XiguangChip(
                  label: entry.value,
                  selected: selectedMedia.contains(entry.key),
                  onSelected: (_) => onMedia(entry.key),
                ),
            ],
          ),
          if (tags.isNotEmpty)
            _FilterSection(
              label: '标签',
              children: [
                for (final tag in tags)
                  XiguangChip(
                    label: '#$tag',
                    selected: selectedTags.contains(tag),
                    onSelected: (_) => onTag(tag),
                  ),
              ],
            ),
          _FilterSection(
            label: '顺序',
            bottomPadding: 0,
            children: [
              XiguangChip(
                label: '新光在前',
                selected: sortOrder == _SortOrder.newest,
                onSelected: (_) => onSort(_SortOrder.newest),
              ),
              XiguangChip(
                label: '旧光在前',
                selected: sortOrder == _SortOrder.oldest,
                onSelected: (_) => onSort(_SortOrder.oldest),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.label,
    required this.children,
    this.bottomPadding = AppSpacing.s9,
  });

  final String label;
  final List<Widget> children;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 38,
            child: Text(
              label,
              style: AppText.microLabel.copyWith(color: theme.foregroundMuted),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: children.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.s6),
                itemBuilder: (_, index) => children[index],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isImageSource(String value) => RegExp(
      r'(^data:image/|\.(jpg|jpeg|png|webp|heic|gif)(\?|$))',
      caseSensitive: false,
    ).hasMatch(value);

bool _isAudioSource(String value) => RegExp(
      r'(^data:audio/|\.(m4a|mp3|wav|aac|ogg|opus)(\?|$))',
      caseSensitive: false,
    ).hasMatch(value);

class _SelectableFragmentRow extends StatelessWidget {
  const _SelectableFragmentRow({
    required this.fragment,
    required this.selected,
    required this.onTap,
  });

  final Fragment fragment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final emotionColor = fragment.color;
    final title = fragment.title.isEmpty ? '未命名光片' : fragment.title;
    final hasImage = fragment.mediaUrls.any(_isImageSource);
    final hasAudio = fragment.mediaUrls.any(_isAudioSource);

    return Semantics(
      button: true,
      selected: selected,
      label: '$title，${fragment.emotion}，${fragment.dateLabel}',
      child: AnimatedContainer(
        key: ValueKey('fragment-picker-row-${fragment.id}'),
        duration: AppMotion.selection,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? theme.accent.withValues(alpha: .11)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: selected
                ? theme.accent.withValues(alpha: .42)
                : theme.border.withValues(alpha: .42),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: emotionColor.withValues(alpha: .24),
                  ),
                  child: Icon(
                    hasImage
                        ? Icons.image_outlined
                        : hasAudio
                            ? Icons.graphic_eq_rounded
                            : Icons.blur_on_rounded,
                    size: 19,
                    color: emotionColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong
                            .copyWith(color: theme.foreground),
                      ),
                      const SizedBox(height: AppSpacing.s5),
                      Text(
                        _metadata(fragment),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption
                            .copyWith(color: theme.foregroundMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s10),
                AnimatedContainer(
                  duration: AppMotion.quick,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? theme.accent : Colors.transparent,
                    border: Border.all(
                      color: selected ? theme.accent : theme.foregroundMuted,
                      width: 1.4,
                    ),
                  ),
                  child: selected
                      ? Icon(Icons.check_rounded,
                          size: 16, color: theme.background)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _metadata(Fragment fragment) {
    final parts = <String>[
      '${fragment.dateLabel} ${fragment.time}',
      fragment.emotion,
      if (fragment.tags.isNotEmpty) '#${fragment.tags.first}',
    ];
    return parts.join(' · ');
  }
}
