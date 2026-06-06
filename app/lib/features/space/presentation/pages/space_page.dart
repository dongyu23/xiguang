import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../providers/space_provider.dart';

class SpacePage extends ConsumerWidget {
  const SpacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(spaceThemeProvider);
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 104),
          child: theme.when(
            data: (space) => Container(
              padding: const EdgeInsets.all(18),
              decoration: softDecoration(AppColors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SPACE', style: AppText.eyebrow),
                  const SizedBox(height: 8),
                  Text(space.name, style: AppText.titleMedium),
                  const SizedBox(height: 8),
                  Text(space.description, style: AppText.body),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Text('空间主题暂时不可用。', style: AppText.body),
          ),
        ),
      ),
    ]);
  }
}
