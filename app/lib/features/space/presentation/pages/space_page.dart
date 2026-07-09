import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/primitives/night_background.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../domain/space_theme.dart';
import '../providers/space_provider.dart';

class SpacePage extends ConsumerWidget {
  const SpacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(spaceThemeProvider);
    final nightMode = ref.watch(nightModeProvider);
    return Stack(children: [
      const Positioned.fill(child: NightBackgroundPlaceholder()),
      const Positioned.fill(child: AtmosphereBackground()),
      SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.s22, AppSpacing.s18,
              AppSpacing.s22, AppSpacing.pageBottomNav),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SpaceHeader(nightMode: nightMode),
                  const SizedBox(height: AppSpacing.s20),
                  theme.when(
                    data: (space) => _SpaceThemeCard(
                      space: space,
                      nightMode: nightMode,
                    ),
                    loading: () => _SpaceLoadingCard(nightMode: nightMode),
                    error: (_, __) => _SpaceErrorCard(nightMode: nightMode),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _SpaceHeader extends StatelessWidget {
  const _SpaceHeader({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child:
              Text('SPACE', style: AppText.onNight(AppText.eyebrow, nightMode)),
        ),
        _BackButton(nightMode: nightMode),
      ]),
      const SizedBox(height: AppSpacing.sm),
      Text('空间', style: AppText.onNight(AppText.hero, nightMode)),
      const SizedBox(height: AppSpacing.sm),
      Text('当前空间的底色，只轻轻托住记录，不打断你。',
          style: AppText.onNight(AppText.body, nightMode)),
    ]);
  }
}

class _SpaceThemeCard extends StatelessWidget {
  const _SpaceThemeCard({
    required this.space,
    required this.nightMode,
  });

  final SpaceTheme space;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    final color = _parseHexColor(space.primaryColorHex);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s18),
      decoration:
          nightMode ? nightDecoration() : softDecoration(AppColors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 132,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: nightMode ? .72 : .62),
                AppColors.paper.withValues(alpha: nightMode ? .12 : .82),
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: nightMode ? .34 : .28),
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
            style: AppText.onNight(AppText.titleMedium, nightMode)),
        const SizedBox(height: AppSpacing.sm),
        Text(space.description,
            style: AppText.onNight(AppText.bodyMuted, nightMode)),
        const SizedBox(height: AppSpacing.md),
        Text('来自当前后端空间主题。', style: AppText.onNight(AppText.caption, nightMode)),
      ]),
    );
  }
}

class _SpaceLoadingCard extends StatelessWidget {
  const _SpaceLoadingCard({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 188,
      alignment: Alignment.center,
      decoration:
          nightMode ? nightDecoration() : softDecoration(AppColors.white),
      child: const CircularProgressIndicator(),
    );
  }
}

class _SpaceErrorCard extends StatelessWidget {
  const _SpaceErrorCard({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s18),
      decoration:
          nightMode ? nightDecoration() : softDecoration(AppColors.white),
      child:
          Text('空间主题暂时不可用。', style: AppText.onNight(AppText.body, nightMode)),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return PageBackButton(
      onTap: () => _goBack(context),
      nightMode: nightMode,
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/mine');
  }
}

Color _parseHexColor(String value) {
  final normalized = value.trim().replaceFirst('#', '');
  if (normalized.length != 6) return AppColors.teaGreen;
  final parsed = int.tryParse('FF$normalized', radix: 16);
  return parsed == null ? AppColors.teaGreen : Color(parsed);
}

// nightDecoration() 已移除，使用 shadows.dart 中的 nightDecoration()
