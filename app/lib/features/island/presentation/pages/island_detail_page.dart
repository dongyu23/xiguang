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
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_chip.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../widgets/fragment_picker_sheet.dart';

class IslandDetailPage extends ConsumerStatefulWidget {
  const IslandDetailPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<IslandDetailPage> createState() => _IslandDetailPageState();
}

class _IslandDetailPageState extends ConsumerState<IslandDetailPage> {
  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(islandDetailProvider(widget.id));
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
          const _IslandPageHeader(title: '小岛详情'),
          const SizedBox(height: AppSpacing.s18),
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
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                XiguangCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ISLAND',
                          style: AppText.eyebrow
                              .copyWith(color: theme.foregroundMuted)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(data.island.name,
                          style: AppText.titleMedium
                              .copyWith(color: theme.foreground)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(data.island.description,
                          style:
                              AppText.body.copyWith(color: theme.foreground)),
                      const SizedBox(height: AppSpacing.s10),
                      Text(
                        '${data.fragments.length} 束光 · ${_statusLabel(data.island.status)}',
                        style: AppText.caption
                            .copyWith(color: theme.foregroundMuted),
                      ),
                      const SizedBox(height: AppSpacing.s14),
                      if (data.island.manual)
                        XiguangButton(
                          label: '添加光片',
                          expand: false,
                          onPressed: () => _showFragmentPicker(context, data),
                          leading: const Icon(Icons.add_rounded, size: 18),
                        )
                      else
                        const _AutoIslandPill(),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s14),
                if (data.fragments.isEmpty)
                  XiguangEmptyState(
                    title: data.island.manual ? '这座小岛还没有光' : '它还在慢慢生长',
                    description:
                        data.island.manual ? '可以先添加第一束光。' : '这座小岛还在等更多同主题的光靠近。',
                  )
                else
                  ...data.fragments.map((fragment) => LightFragmentCard(
                        fragment: fragment.toLightFragment(),
                        dense: true,
                        showAttachmentBadge: true,
                        showTitle: false,
                        onTap: () => context.push('/fragments/${fragment.id}'),
                      )),
              ],
            ),
          ),
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

class _IslandPageHeader extends StatelessWidget {
  const _IslandPageHeader({required this.title});

  final String title;

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
      ],
    );
  }
}

// _InlineActionButton 已删除，统一使用 FilledButton.icon（§10.2 默认色，§10.6 不再保留装饰白名单）。

class _AutoIslandPill extends StatelessWidget {
  const _AutoIslandPill();

  @override
  Widget build(BuildContext context) {
    return const XiguangChip(
      label: '自动生长',
      selected: true,
      leading: Icon(Icons.auto_awesome_rounded, size: 16),
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
