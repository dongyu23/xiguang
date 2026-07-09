import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/primitives/night_background.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../domain/noise_audio.dart';
import '../providers/whitenoise_provider.dart';

class WhiteNoisePage extends ConsumerWidget {
  const WhiteNoisePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedID = ref.watch(whiteNoisePlayingProvider);
    final noises = ref.watch(_whiteNoiseOptionsProvider);
    final nightMode = ref.watch(nightModeProvider);
    return Stack(children: [
      const Positioned.fill(child: NightBackgroundPlaceholder()),
      const Positioned.fill(child: AtmosphereBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.s22,
                    AppSpacing.s12, AppSpacing.s22, AppSpacing.pageBottomNav),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WhiteNoiseHeader(nightMode: nightMode),
                    const SizedBox(height: AppSpacing.s18),
                    noises.when(
                      data: (items) => _WhiteNoiseContent(
                        items: items,
                        selectedID: selectedID,
                        nightMode: nightMode,
                        onSelect: (id) {
                          ref.read(whiteNoisePlayingProvider.notifier).state =
                              selectedID == id ? null : id;
                        },
                      ),
                      loading: () =>
                          _WhiteNoiseLoadingState(nightMode: nightMode),
                      error: (_, __) => _WhiteNoiseErrorState(
                        nightMode: nightMode,
                        onRetry: () =>
                            ref.invalidate(_whiteNoiseOptionsProvider),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

final _whiteNoiseOptionsProvider = FutureProvider<List<NoiseAudio>>((ref) {
  return ref.watch(whiteNoiseRepositoryProvider).list();
});

class _WhiteNoiseContent extends StatelessWidget {
  const _WhiteNoiseContent({
    required this.items,
    required this.selectedID,
    required this.nightMode,
    required this.onSelect,
  });

  final List<NoiseAudio> items;
  final String? selectedID;
  final bool nightMode;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s18),
          decoration: softDecoration(
            nightMode ? AppColors.ink.withValues(alpha: .72) : AppColors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BACKGROUND SOUND',
                style: AppText.onNight(AppText.eyebrow, nightMode),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '只在你需要的时候响起，不常驻，也不催促。',
                style: AppText.onNight(AppText.body, nightMode),
              ),
              const SizedBox(height: AppSpacing.s18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: items
                    .map((item) => _NoiseChip(
                          audio: item,
                          selected: selectedID == item.id,
                          nightMode: nightMode,
                          onTap: () => onSelect(item.id),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s18),
          decoration: softDecoration(
            nightMode ? AppColors.nightSurfaceHigh : AppColors.white,
          ),
          child: Row(children: [
            Icon(
              selectedID == null
                  ? Icons.volume_off_outlined
                  : Icons.graphic_eq_rounded,
              color: nightMode ? AppText.nightAccent : AppColors.ink,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                selectedID == null
                    ? '没有播放中的声音。'
                    : '正在预览：${items.firstWhere((item) => item.id == selectedID).name}',
                style: AppText.onNight(AppText.body, nightMode),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _WhiteNoiseLoadingState extends StatelessWidget {
  const _WhiteNoiseLoadingState({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s18),
      decoration: softDecoration(
        nightMode ? AppColors.ink.withValues(alpha: .72) : AppColors.white,
      ),
      child: Row(children: [
        const SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('正在调出声音',
                  style: AppText.onNight(AppText.titleSmall, nightMode)),
              const SizedBox(height: AppSpacing.xs),
              Text('如果服务器暂时安静，会停在这里等它回应。',
                  style: AppText.onNight(AppText.caption, nightMode)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _WhiteNoiseErrorState extends StatelessWidget {
  const _WhiteNoiseErrorState({
    required this.nightMode,
    required this.onRetry,
  });

  final bool nightMode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s18),
      decoration: softDecoration(
        nightMode ? AppColors.ink.withValues(alpha: .72) : AppColors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              Icons.cloud_off_outlined,
              color: nightMode ? AppText.nightAccent : AppColors.teaGreen,
            ),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: Text(
                '声音列表暂时没有连上',
                style: AppText.onNight(AppText.titleSmall, nightMode),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '请稍后重试，或先回到“我的”继续整理边界。',
            style: AppText.onNight(AppText.caption, nightMode),
          ),
          const SizedBox(height: AppSpacing.s14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('重新连接'),
          ),
        ],
      ),
    );
  }
}

class _WhiteNoiseHeader extends StatelessWidget {
  const _WhiteNoiseHeader({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PageBackButton(
          onTap: () => Navigator.of(context).maybePop(),
          nightMode: nightMode,
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            '白噪音',
            style: AppText.onNight(
              AppText.titleLarge,
              nightMode,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _NoiseChip extends StatelessWidget {
  const _NoiseChip({
    required this.audio,
    required this.selected,
    required this.nightMode,
    required this.onTap,
  });

  final NoiseAudio audio;
  final bool selected;
  final bool nightMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.white
        : nightMode
            ? AppText.nightInk
            : AppColors.ink;
    final background = selected
        ? AppColors.ink
        : nightMode
            ? AppColors.white.withValues(alpha: .08)
            : AppColors.paper.withValues(alpha: .66);
    return Material(
      color: background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected
              ? AppColors.ink
              : AppColors.line.withValues(alpha: nightMode ? .18 : .86),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: foreground,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.s6),
              Text(
                audio.name,
                style: AppText.chip.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
