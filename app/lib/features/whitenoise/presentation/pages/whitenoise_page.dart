import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
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
      const Positioned.fill(child: AtmosphereBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('白噪音'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: nightMode ? AppText.nightInk : AppColors.ink,
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 104),
                child: noises.when(
                  data: (items) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BACKGROUND SOUND',
                          style: AppText.onNight(AppText.eyebrow, nightMode)),
                      const SizedBox(height: 8),
                      Text('只在你需要的时候响起。',
                          style: AppText.onNight(AppText.body, nightMode)),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: items
                            .map((item) => _NoiseChip(
                                  audio: item,
                                  selected: selectedID == item.id,
                                  onTap: () {
                                    ref
                                            .read(whiteNoisePlayingProvider
                                                .notifier)
                                            .state =
                                        selectedID == item.id ? null : item.id;
                                  },
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: softDecoration(AppColors.white),
                        child: Row(children: [
                          Icon(
                            selectedID == null
                                ? Icons.volume_off_outlined
                                : Icons.graphic_eq_rounded,
                            color: AppColors.ink,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedID == null
                                  ? '没有播放中的声音。'
                                  : '正在预览：${items.firstWhere((item) => item.id == selectedID).name}',
                              style: AppText.body,
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      Text('暂时无法读取白噪音：$error',
                          style: AppText.onNight(AppText.body, nightMode)),
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

class _NoiseChip extends StatelessWidget {
  const _NoiseChip({
    required this.audio,
    required this.selected,
    required this.onTap,
  });

  final NoiseAudio audio;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(selected ? Icons.pause_rounded : Icons.play_arrow_rounded),
      label: Text(audio.name),
    );
  }
}
