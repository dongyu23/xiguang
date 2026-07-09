import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../features/fragment/data/fragment_repository.dart';
import '../../../../ui/composites/light_card.dart';
import '../../../../ui/primitives/night_background.dart';
import '../../../../ui/primitives/page_back_button.dart';
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
  bool _nightMode = false;
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
    _nightMode = ref.watch(nightModeProvider);
    return Stack(children: [
      const Positioned.fill(child: NightBackgroundPlaceholder()),
      const Positioned.fill(child: AtmosphereBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: FutureBuilder<_IslandDetailData>(
            future: _detail,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _IslandPageShell(
                  nightMode: _nightMode,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              if (snapshot.hasError) {
                return _IslandPageShell(
                  nightMode: _nightMode,
                  child: _IslandErrorCard(
                    nightMode: _nightMode,
                    onRetry: () {
                      setState(() {
                        _detail = _load(
                            ref.read(islandRepositoryProvider), _idOrName);
                      });
                    },
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
              return _IslandPageShell(
                nightMode: _nightMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.s18),
                      decoration: softDecoration(AppColors.white,
                          nightMode: _nightMode),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ISLAND',
                              style:
                                  AppText.onNight(AppText.eyebrow, _nightMode)),
                          const SizedBox(height: AppSpacing.sm),
                          Text(data.island.name,
                              style: AppText.onNight(
                                  AppText.titleMedium, _nightMode)),
                          const SizedBox(height: AppSpacing.sm),
                          Text(data.island.description,
                              style: AppText.onNight(AppText.body, _nightMode)),
                          const SizedBox(height: AppSpacing.s10),
                          Text(
                            '${data.fragments.length} 束光 · ${_statusLabel(data.island.status)}',
                            style: AppText.onNight(AppText.caption, _nightMode),
                          ),
                          const SizedBox(height: AppSpacing.s14),
                          if (data.island.manual)
                            FilledButton.icon(
                              onPressed: () =>
                                  _showFragmentPicker(context, repository),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('添加光片'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.s14),
                                textStyle: AppText.chip,
                              ),
                            )
                          else
                            const _AutoIslandPill(),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s14),
                    if (data.fragments.isEmpty)
                      Text(
                        data.island.manual
                            ? '这座小岛还没有可回看的光片。可以先添加第一束光。'
                            : '这座小岛还在等更多同主题的光靠近。',
                        style: AppText.onNight(AppText.bodyMuted, _nightMode),
                      )
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
      showOverlaySnackBar(
        context,
        const SnackBar(content: Text('小岛还没有加载完成，稍后再试。')),
      );
      return;
    }
    if (!context.mounted) return;
    if (!current.island.manual) {
      showOverlaySnackBar(
        context,
        const SnackBar(content: Text('这座自动生长的小岛不能手动添加光片。')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
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
            showOverlaySnackBar(
              context,
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
              showOverlaySnackBar(
                context,
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

class _IslandPageShell extends StatelessWidget {
  const _IslandPageShell({required this.child, required this.nightMode});

  final Widget child;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          22, 12, 22, 64 + 10 + MediaQuery.paddingOf(context).bottom + 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IslandPageHeader(title: '小岛详情', nightMode: nightMode),
              const SizedBox(height: AppSpacing.s18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _IslandPageHeader extends StatelessWidget {
  const _IslandPageHeader({required this.title, required this.nightMode});

  final String title;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PageBackButton(
          onTap: () => context.pop(),
          nightMode: nightMode,
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            title,
            style: AppText.onNight(AppText.titleLarge, nightMode),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _IslandErrorCard extends StatelessWidget {
  const _IslandErrorCard({required this.onRetry, required this.nightMode});

  final VoidCallback onRetry;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s18),
      decoration: softDecoration(AppColors.white, nightMode: nightMode),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.sunsetCoral.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.sunsetCoral.withValues(alpha: .22),
              ),
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              color: AppColors.sunsetCoral.withValues(alpha: .92),
              size: 19,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('暂时无法打开这座小岛',
                    style: AppText.onNight(AppText.titleSmall, nightMode)),
                const SizedBox(height: AppSpacing.s7),
                Text(
                  '后端暂时没有回应，小岛内容不会丢失。',
                  style: AppText.onNight(AppText.bodyMuted, nightMode),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.s14),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('重新加载'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: const BorderSide(color: AppColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ]),
    );
  }
}

// _InlineActionButton 已删除，统一使用 FilledButton.icon（§10.2 默认色，§10.6 不再保留装饰白名单）。


class _AutoIslandPill extends StatelessWidget {
  const _AutoIslandPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.teaGreen.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.teaGreen.withValues(alpha: .26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: AppColors.teaGreen.withValues(alpha: .92),
          ),
          const SizedBox(width: AppSpacing.s6),
          Text(
            '自动生长',
            style: AppText.chip.copyWith(color: AppColors.teaGreen),
          ),
        ],
      ),
    );
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
