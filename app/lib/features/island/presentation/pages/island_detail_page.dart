// PAGE_SIZE_EXEMPT: migration in progress; detail header and fragment wall will be extracted.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';

import '../../application/island_detail_controller.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../features/fragment/domain/fragment.dart';
import '../../domain/island_repository.dart';
import '../../../../ui/composites/light_card.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../domain/universe_overview.dart';
import '../widgets/fragment_picker_sheet.dart';
import '../widgets/island_detail_hero.dart';

class IslandDetailPage extends ConsumerStatefulWidget {
  const IslandDetailPage({
    super.key,
    required this.id,
    this.initialIsland,
  });

  final String id;
  final IslandVisualNode? initialIsland;

  @override
  ConsumerState<IslandDetailPage> createState() => _IslandDetailPageState();
}

class _IslandDetailPageState extends ConsumerState<IslandDetailPage> {
  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(islandDetailProvider(widget.id));
    final data = detail.valueOrNull;
    final heroIsland = data == null
        ? widget.initialIsland
        : IslandVisualNode(
            island: data.island,
            fragments: data.fragments,
          );
    final theme = NightTheme.of(context);
    return XiguangPage(
      backgroundLayer: const AtmosphereBackground(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s22,
        AppSpacing.s12,
        AppSpacing.s22,
        AppSpacing.pageBottomNav + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IslandPageHeader(
            title: '岛上',
            onDelete: data != null && data.island.islandId > 0
                ? () => _confirmDeleteIsland(data)
                : null,
          ),
          const SizedBox(height: AppSpacing.s6),
          if (heroIsland != null)
            IslandDetailHero(
              key: const ValueKey('stable-island-detail-hero'),
              island: heroIsland,
              onAdd: data?.island.manual == true
                  ? () => _showFragmentPicker(context, data!)
                  : null,
            )
          else
            detail.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => XiguangEmptyState(
                title: '暂时无法打开这座小岛',
                description: '后端暂时没有回应，小岛内容不会丢失。',
                icon: Icons.wifi_off_rounded,
                action: XiguangButton(
                  label: '重新加载',
                  expand: false,
                  variant: XiguangButtonVariant.secondary,
                  leading: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: () =>
                      ref.invalidate(islandDetailProvider(widget.id)),
                ),
              ),
              data: (_) => const SizedBox.shrink(),
            ),
          if (data != null && data.fragments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s28),
            Row(
              children: [
                Text(
                  '岛上的光',
                  style: AppText.titleMedium.copyWith(color: theme.foreground),
                ),
                const Spacer(),
                Text(
                  '${data.fragments.length} 束',
                  style: AppText.caption.copyWith(color: theme.foregroundMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s14),
            ...data.fragments.map((fragment) => LightFragmentCard(
                  fragment: fragment.toLightFragment(),
                  dense: true,
                  showAttachmentBadge: true,
                  showTitle: false,
                  onTap: () => context.push(
                    _fragmentDetailPath(data, fragment),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _showFragmentPicker(
    BuildContext context,
    IslandDetailData current,
  ) async {
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
          final islandId = current.island.islandId;
          if (islandId <= 0) {
            if (!context.mounted) return false;
            showOverlaySnackBar(
              context,
              const SnackBar(content: Text('这座自动生长的小岛暂时不能手动添加光片。')),
            );
            return false;
          }
          try {
            await ref
                .read(islandDetailProvider(widget.id).notifier)
                .addFragments(fragmentIds);
          } on IslandNotManualException {
            if (!context.mounted) return false;
            showOverlaySnackBar(
              context,
              const SnackBar(content: Text('这座自动生长的小岛不能手动添加光片。')),
            );
            return false;
          }
          return true;
        },
      ),
    );
  }

  String _fragmentDetailPath(
    IslandDetailData current,
    Fragment fragment,
  ) {
    final island = current.island;
    return Uri(
      path: '/fragments/${fragment.id}',
      queryParameters: {
        'islandId': '${island.islandId}',
        'islandRouteId': widget.id,
        'islandName': island.name,
        'islandManual': island.manual ? '1' : '0',
      },
    ).toString();
  }

  Future<void> _confirmDeleteIsland(IslandDetailData current) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = NightTheme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.surfaceHigh,
          title: Text(
            '删除「${current.island.name}」？',
            style: AppText.titleMedium.copyWith(color: theme.foreground),
          ),
          content: Text(
            '只会删除这座小岛，岛内的光片仍会保留在线和其他小岛中。',
            style: AppText.body.copyWith(color: theme.foregroundMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除小岛'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(islandDetailProvider(widget.id).notifier).deleteIsland();
      if (mounted) context.go('/universe');
    } catch (_) {
      if (!mounted) return;
      showOverlaySnackBar(
        context,
        const SnackBar(content: Text('暂时无法删除这座小岛，请稍后再试。')),
      );
    }
  }
}

class _IslandPageHeader extends StatelessWidget {
  const _IslandPageHeader({required this.title, this.onDelete});

  final String title;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: '返回',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: theme.foreground),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            title,
            style: AppText.titleLarge.copyWith(color: theme.foreground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onDelete != null)
          Semantics(
            button: true,
            label: '删除小岛',
            child: ExcludeSemantics(
              child: SizedBox.square(
                dimension: 36,
                child: IconButton(
                  key: const ValueKey('delete-island-detail-button'),
                  tooltip: '删除小岛',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: theme.danger,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
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
