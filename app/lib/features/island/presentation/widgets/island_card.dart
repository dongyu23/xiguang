import 'package:flutter/material.dart';

import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../data/island_repository.dart';

class IslandCard extends StatelessWidget {
  const IslandCard({
    super.key,
    required this.island,
    this.nightMode = false,
    this.onTap,
  });

  final IslandModel island;
  final bool nightMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s14),
        decoration: nightMode
            ? nightDecoration(radius: 8)
            : softDecoration(AppColors.white, radius: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(island.name,
              style: AppText.onNight(AppText.titleSmall, nightMode)),
          const SizedBox(height: AppSpacing.s6),
          Text('${island.fragmentCount} 束光 · ${island.status}',
              style: AppText.onNight(AppText.caption, nightMode)),
        ]),
      ),
    );
  }
}
