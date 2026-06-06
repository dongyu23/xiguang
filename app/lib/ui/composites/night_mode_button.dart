import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../design/tokens/colors.dart';

class NightModeButton extends ConsumerWidget {
  const NightModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nightMode = ref.watch(nightModeProvider);
    return Material(
      color: (nightMode ? AppColors.ink : AppColors.white)
          .withValues(alpha: nightMode ? .92 : .86),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: nightMode ? '切回白天' : '夜间轻开',
        onPressed: () =>
            ref.read(nightModeProvider.notifier).state = !nightMode,
        icon: Icon(
          nightMode ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
        ),
        color: nightMode ? AppColors.emotionHappy : AppColors.ink,
      ),
    );
  }
}
