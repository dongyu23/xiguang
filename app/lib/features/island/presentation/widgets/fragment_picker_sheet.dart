import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../fragment/presentation/providers/fragment_providers.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/composites/xiguang_bottom_sheet.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_chip.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/composites/xiguang_input.dart';

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
  String? _activeTag;
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
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return XiguangBottomSheet(
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.s12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(AppRadius.xs / 2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s22, vertical: AppSpacing.s12),
                child: Row(children: [
                  Expanded(
                    child: Text('选择光片',
                        style: AppText.titleMedium
                            .copyWith(color: theme.foreground)),
                  ),
                  Text('已选 ${_selected.length}',
                      style:
                          AppText.captionStrong.copyWith(color: theme.accent)),
                ]),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s22),
                child: XiguangInput(
                  controller: _searchController,
                  hint: '搜索光片...',
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Fragment list
              Expanded(
                child: fragmentsAsync.when(
                  data: (fragments) {
                    final available = fragments
                        .where((fragment) =>
                            !widget.excludedFragmentIds.contains(fragment.id))
                        .toList();
                    if (available.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: XiguangEmptyState(
                            title: '没有可继续添加的光片',
                            description: '这座小岛已经收好了当前可用的光。',
                          ),
                        ),
                      );
                    }
                    final allTags = available
                        .expand((f) => f.tags)
                        .toSet()
                        .toList()
                      ..sort();
                    var filtered = available;
                    if (_search.isNotEmpty) {
                      filtered = filtered
                          .where((f) =>
                              f.title.contains(_search) ||
                              f.contentText.contains(_search))
                          .toList();
                    }
                    if (_activeTag != null) {
                      filtered = filtered
                          .where((f) => f.tags.contains(_activeTag))
                          .toList();
                    }

                    return Column(children: [
                      // Tag filter chips
                      if (allTags.isNotEmpty)
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s22),
                            itemCount: allTags.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                final active = _activeTag == null;
                                return XiguangChip(
                                  label: '全部',
                                  selected: active,
                                  onSelected: (_) =>
                                      setState(() => _activeTag = null),
                                );
                              }
                              final tag = allTags[index - 1];
                              return XiguangChip(
                                label: '#$tag',
                                selected: _activeTag == tag,
                                onSelected: (v) =>
                                    setState(() => _activeTag = v ? tag : null),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      // Fragment list
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final fragment = filtered[index];
                            final isSelected = _selected.contains(fragment.id);
                            return ListTile(
                              leading: Checkbox(
                                value: isSelected,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selected.add(fragment.id);
                                    } else {
                                      _selected.remove(fragment.id);
                                    }
                                  });
                                },
                              ),
                              title: Text(
                                fragment.title.isEmpty
                                    ? '未命名光片'
                                    : fragment.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body
                                    .copyWith(color: theme.foreground),
                              ),
                              subtitle: Text(
                                fragment.contentText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption
                                    .copyWith(color: theme.foregroundMuted),
                              ),
                              trailing: fragment.tags.isNotEmpty
                                  ? SizedBox(
                                      width: 80,
                                      child: Text(
                                        fragment.tags
                                            .map((t) => '#$t')
                                            .join(' '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.caption.copyWith(
                                            color: theme.foregroundMuted),
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selected.remove(fragment.id);
                                  } else {
                                    _selected.add(fragment.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ]);
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                      child: Text('暂时无法加载光片。',
                          style:
                              AppText.body.copyWith(color: theme.foreground))),
                ),
              ),
              // Bottom bar
              if (_selected.isNotEmpty)
                XiguangCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  variant: XiguangCardVariant.outlined,
                  child: SafeArea(
                    top: false,
                    child: XiguangButton(
                      label: _submitting
                          ? '添加中...'
                          : '添加 ${_selected.length} 束光到小岛',
                      loading: _submitting,
                      leading: const Icon(Icons.add_rounded, size: 18),
                      onPressed: _submitting
                          ? null
                          : () async {
                              setState(() => _submitting = true);
                              var shouldClose = false;
                              try {
                                shouldClose =
                                    await widget.onConfirm(_selected.toList());
                              } catch (_) {
                                if (context.mounted) {
                                  showOverlaySnackBar(
                                    context,
                                    const SnackBar(
                                      content: Text('暂时无法添加这些光片。'),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _submitting = false);
                                }
                              }
                              if (!context.mounted || !shouldClose) return;
                              Navigator.of(context).pop();
                            },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
