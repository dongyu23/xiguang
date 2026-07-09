import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../domain/space_theme.dart';
import '../../application/space_providers.dart';

class SpacePage extends ConsumerWidget {
  const SpacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(spaceThemeProvider);
    return XiguangPage(
      backgroundLayer: const AtmosphereBackground(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SpaceHeader(),
          const SizedBox(height: AppSpacing.s20),
          theme.when(
            data: (space) => _SpaceThemeCard(space: space),
            loading: () => const _SpaceLoadingCard(),
            error: (_, __) => const XiguangEmptyState(
              title: '空间暂时沉入雾里',
              description: '当前无法读取空间主题，稍后再回来看看。',
              icon: Icons.cloud_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceHeader extends StatelessWidget {
  const _SpaceHeader();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(
            'SPACE',
            style: AppText.eyebrow.copyWith(color: theme.foregroundMuted),
          ),
        ),
        IconButton(
          tooltip: '返回',
          onPressed: () => _goBack(context),
          icon: Icon(Icons.arrow_back_rounded, color: theme.foreground),
        ),
      ]),
      const SizedBox(height: AppSpacing.sm),
      Text('空间', style: AppText.hero.copyWith(color: theme.foreground)),
      const SizedBox(height: AppSpacing.sm),
      Text(
        '当前空间的底色，只轻轻托住记录，不打断你。',
        style: AppText.body.copyWith(color: theme.foregroundMuted),
      ),
    ]);
  }

  void _goBack(BuildContext context) {
    context.canPop() ? context.pop() : context.go('/mine');
  }
}

class _SpaceThemeCard extends StatelessWidget {
  const _SpaceThemeCard({required this.space});

  final SpaceTheme space;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final color = _parseHexColor(space.primaryColorHex);
    return XiguangCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 132,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: theme.isNight ? .72 : .62),
                theme.background.withValues(alpha: theme.isNight ? .12 : .82),
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: theme.isNight ? .34 : .28),
            ),
          ),
          child: Stack(children: [
            Positioned(
              left: 18,
              top: 18,
              child: Text(
                '当前底色',
                style: AppText.captionStrong.copyWith(color: Colors.white),
              ),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: .62),
                  ),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.s18),
        Text(space.name,
            style: AppText.titleMedium.copyWith(color: theme.foreground)),
        const SizedBox(height: AppSpacing.sm),
        Text(space.description,
            style: AppText.bodyMuted.copyWith(color: theme.foregroundMuted)),
        const SizedBox(height: AppSpacing.md),
        Text(
          '来自当前后端空间主题。',
          style: AppText.caption.copyWith(color: theme.foregroundMuted),
        ),
      ]),
    );
  }
}

class _SpaceLoadingCard extends StatelessWidget {
  const _SpaceLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const XiguangCard(
      child: SizedBox(
        height: 152,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

Color _parseHexColor(String value) {
  final normalized = value.trim().replaceFirst('#', '');
  if (normalized.length != 6) return AppColors.teaGreen;
  final parsed = int.tryParse('FF$normalized', radix: 16);
  return parsed == null ? AppColors.teaGreen : Color(parsed);
}

// nightDecoration() 已移除，使用 shadows.dart 中的 nightDecoration()
