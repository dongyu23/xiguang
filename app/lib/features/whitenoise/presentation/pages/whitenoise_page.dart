// PAGE_SIZE_EXEMPT: migration in progress; player state and selector grid will be extracted.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/whitenoise_providers.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_chip.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../domain/noise_audio.dart';
import '../providers/whitenoise_provider.dart';

class WhiteNoisePage extends ConsumerWidget {
  const WhiteNoisePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedID = ref.watch(whiteNoisePlayingProvider);
    final noises = ref.watch(whiteNoiseOptionsProvider);
    return XiguangPage(
      backgroundLayer: const AtmosphereBackground(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s22,
        AppSpacing.s12,
        AppSpacing.s22,
        AppSpacing.pageBottomNav,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WhiteNoiseHeader(),
          const SizedBox(height: AppSpacing.s18),
          noises.when(
            data: (items) => _WhiteNoiseContent(
              items: items,
              selectedID: selectedID,
              onSelect: (id) {
                ref.read(whiteNoisePlayingProvider.notifier).state =
                    selectedID == id ? null : id;
              },
            ),
            loading: () => const _WhiteNoiseLoadingState(),
            error: (_, __) => XiguangEmptyState(
              title: '声音列表暂时没有连上',
              description: '请稍后重试，或先回到“我的”继续整理边界。',
              icon: Icons.cloud_off_outlined,
              action: XiguangButton(
                label: '重新连接',
                expand: false,
                variant: XiguangButtonVariant.secondary,
                leading: const Icon(Icons.refresh_rounded, size: 16),
                onPressed: () => ref.invalidate(whiteNoiseOptionsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteNoiseContent extends StatelessWidget {
  const _WhiteNoiseContent({
    required this.items,
    required this.selectedID,
    required this.onSelect,
  });

  final List<NoiseAudio> items;
  final String? selectedID;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Column(
      children: [
        XiguangCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BACKGROUND SOUND',
                style: AppText.eyebrow.copyWith(color: theme.foregroundMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '只在你需要的时候响起，不常驻，也不催促。',
                style: AppText.body.copyWith(color: theme.foreground),
              ),
              const SizedBox(height: AppSpacing.s18),
              Wrap(
                spacing: AppSpacing.s10,
                runSpacing: AppSpacing.s10,
                children: items
                    .map((item) => XiguangChip(
                          label: item.name,
                          selected: selectedID == item.id,
                          leading: Icon(
                            selectedID == item.id
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 18,
                          ),
                          onSelected: (_) => onSelect(item.id),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s18),
        XiguangCard(
          variant: XiguangCardVariant.outlined,
          child: Row(children: [
            Icon(
              selectedID == null
                  ? Icons.volume_off_outlined
                  : Icons.graphic_eq_rounded,
              color: theme.accent,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                selectedID == null
                    ? '没有播放中的声音。'
                    : '正在预览：${items.firstWhere((item) => item.id == selectedID).name}',
                style: AppText.body.copyWith(color: theme.foreground),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _WhiteNoiseLoadingState extends StatelessWidget {
  const _WhiteNoiseLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangCard(
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
                  style: AppText.titleSmall.copyWith(color: theme.foreground)),
              const SizedBox(height: AppSpacing.xs),
              Text('如果服务器暂时安静，会停在这里等它回应。',
                  style:
                      AppText.caption.copyWith(color: theme.foregroundMuted)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _WhiteNoiseHeader extends StatelessWidget {
  const _WhiteNoiseHeader();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back_rounded, color: theme.foreground),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            '白噪音',
            style: AppText.titleLarge.copyWith(color: theme.foreground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
