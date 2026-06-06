import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/typography.dart';

class FragmentPickerSheet extends ConsumerStatefulWidget {
  const FragmentPickerSheet({super.key, required this.onConfirm});

  final FutureOr<void> Function(List<int> fragmentIds) onConfirm;

  @override
  ConsumerState<FragmentPickerSheet> createState() =>
      _FragmentPickerSheetState();
}

class _FragmentPickerSheetState extends ConsumerState<FragmentPickerSheet> {
  final _selected = <int>{};
  String _search = '';
  String? _activeTag;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final fragmentsAsync = ref.watch(fragmentsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                child: Row(children: [
                  Expanded(
                    child: Text('选择光片', style: AppText.titleMedium),
                  ),
                  Text('已选 ${_selected.length}',
                      style: AppText.caption.copyWith(
                          color: AppColors.teaGreen,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '搜索光片...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
              const SizedBox(height: 8),
              // Fragment list
              Expanded(
                child: fragmentsAsync.when(
                  data: (fragments) {
                    final allTags = fragments
                        .expand((f) => f.tags)
                        .toSet()
                        .toList()
                      ..sort();
                    var filtered = fragments;
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
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            itemCount: allTags.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                final active = _activeTag == null;
                                return FilterChip(
                                  label: const Text('全部'),
                                  selected: active,
                                  onSelected: (_) =>
                                      setState(() => _activeTag = null),
                                  visualDensity: VisualDensity.compact,
                                );
                              }
                              final tag = allTags[index - 1];
                              return FilterChip(
                                label: Text('#$tag'),
                                selected: _activeTag == tag,
                                onSelected: (v) =>
                                    setState(() => _activeTag = v ? tag : null),
                                visualDensity: VisualDensity.compact,
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 8),
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
                                style: AppText.body,
                              ),
                              subtitle: Text(
                                fragment.contentText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption,
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
                                            color: AppColors.inkMuted),
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
                  error: (_, __) =>
                      Center(child: Text('暂时无法加载光片。', style: AppText.body)),
                ),
              ),
              // Bottom bar
              if (_selected.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border(
                        top: BorderSide(color: AppColors.line, width: 0.5)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting
                            ? null
                            : () async {
                                setState(() => _submitting = true);
                                try {
                                  await widget.onConfirm(_selected.toList());
                                } finally {
                                  if (mounted) {
                                    setState(() => _submitting = false);
                                  }
                                }
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                              },
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_rounded, size: 18),
                        label: Text(_submitting
                            ? '添加中...'
                            : '添加 ${_selected.length} 束光到小岛'),
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
}
