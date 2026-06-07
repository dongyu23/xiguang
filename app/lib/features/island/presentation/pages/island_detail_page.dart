import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../features/fragment/data/fragment_repository.dart';
import '../../../../ui/composites/light_card.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../data/island_repository.dart';
import '../widgets/fragment_picker_sheet.dart';

class IslandDetailPage extends ConsumerStatefulWidget {
  const IslandDetailPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<IslandDetailPage> createState() => _IslandDetailPageState();
}

class _IslandDetailPageState extends ConsumerState<IslandDetailPage> {
  late String _idOrName;
  late Future<_IslandDetailData> _detail;

  @override
  void initState() {
    super.initState();
    _idOrName = widget.id;
    _detail = _load(ref.read(islandRepositoryProvider), _idOrName);
  }

  @override
  void didUpdateWidget(covariant IslandDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _idOrName = widget.id;
      _detail = _load(ref.read(islandRepositoryProvider), _idOrName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(islandRepositoryProvider);
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('小岛详情'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        floatingActionButton: FutureBuilder<_IslandDetailData>(
          future: _detail,
          builder: (context, snapshot) {
            final canAdd = snapshot.data?.island.manual ?? false;
            return FloatingActionButton.extended(
              onPressed: () => _showFragmentPicker(context, repository),
              icon: Icon(canAdd ? Icons.add_rounded : Icons.auto_awesome),
              label: Text(canAdd ? '添加光片' : '自动小岛'),
              backgroundColor: canAdd ? AppColors.teaGreen : AppColors.inkMuted,
              foregroundColor: Colors.white,
            );
          },
        ),
        body: SafeArea(
          top: false,
          child: FutureBuilder<_IslandDetailData>(
            future: _detail,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('暂时无法打开这座小岛',
                          style: AppText.body,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _detail = _load(
                                ref.read(islandRepositoryProvider), _idOrName);
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('重新加载'),
                      ),
                    ]),
                  ),
                );
              }
              final data = snapshot.data ??
                  _IslandDetailData(
                    island: IslandModel(
                      name: _idOrName,
                      status: 'star_point',
                      fragmentCount: 0,
                      description: '这些光因为同一个主题靠近。',
                      manual: false,
                    ),
                    fragments: const [],
                  );
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 104),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: softDecoration(AppColors.white),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ISLAND', style: AppText.eyebrow),
                              const SizedBox(height: 8),
                              Text(data.island.name,
                                  style: AppText.titleMedium),
                              const SizedBox(height: 8),
                              Text(data.island.description,
                                  style: AppText.body),
                              const SizedBox(height: 10),
                              Text(
                                '${data.fragments.length} 束光 · ${_statusLabel(data.island.status)}',
                                style: AppText.caption,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (data.fragments.isEmpty)
                          Text('这座小岛还没有可回看的光片。\n点右下角按钮添加第一束光。',
                              style: AppText.body)
                        else
                          ...data.fragments.map((fragment) => LightFragmentCard(
                                fragment: fragment.toLightFragment(),
                                dense: true,
                                showAttachmentBadge: true,
                                showTitle: false,
                                onTap: () =>
                                    context.push('/fragments/${fragment.id}'),
                              )),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }

  Future<void> _showFragmentPicker(
    BuildContext context,
    IslandRepository repository,
  ) async {
    final _IslandDetailData current;
    try {
      current = await _detail;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('小岛还没有加载完成，稍后再试。')),
      );
      return;
    }
    if (!context.mounted) return;
    if (!current.island.manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这座自动生长的小岛不能手动添加光片。')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FragmentPickerSheet(
        excludedFragmentIds: {
          for (final fragment in current.fragments) fragment.id,
        },
        onConfirm: (fragmentIds) async {
          final data = await _detail;
          final islandId = data.island.islandId;
          if (islandId <= 0) {
            if (!context.mounted) return false;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('这座自动生长的小岛暂时不能手动添加光片。')),
            );
            return false;
          }
          final IslandModel updated;
          try {
            updated = await repository.addFragments(islandId, fragmentIds);
          } on DioException catch (error) {
            if (_apiErrorCode(error) == 'island_not_manual') {
              if (!context.mounted) return false;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('这座自动生长的小岛不能手动添加光片。')),
              );
              return false;
            }
            rethrow;
          }
          final nextDetail = _load(repository, _idOrName, seed: updated);
          if (!mounted) return false;
          setState(() {
            _detail = nextDetail;
          });
          ref.invalidate(islandsProvider);
          await nextDetail;
          return true;
        },
      ),
    );
  }

  Future<_IslandDetailData> _load(IslandRepository repository, String idOrName,
      {IslandModel? seed}) async {
    final island = seed ?? await repository.getIsland(idOrName);
    final displayName = island?.name ?? idOrName;
    final fragments = await repository.listIslandFragments(
      displayName,
      islandId: island?.islandId,
    );
    return _IslandDetailData(
      island: island ??
          IslandModel(
            name: displayName,
            status: 'star_point',
            fragmentCount: 0,
            description: '这些光因为同一个主题靠近。',
            manual: false,
          ),
      fragments: fragments,
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'formed' => '已成岛',
      'growing' => '生长中',
      'dormant' => '休眠',
      'relit' => '重新亮起',
      _ => '主题星点',
    };
  }
}

String? _apiErrorCode(DioException error) {
  final apiError = error.error;
  if (apiError is Map && apiError['code'] is String) {
    return apiError['code'] as String;
  }
  final responseData = error.response?.data;
  if (responseData is Map) {
    final nested = responseData['error'];
    if (nested is Map && nested['code'] is String) {
      return nested['code'] as String;
    }
  }
  return null;
}

class _IslandDetailData {
  const _IslandDetailData({required this.island, required this.fragments});

  final IslandModel island;
  final List<LightFragmentModel> fragments;
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
