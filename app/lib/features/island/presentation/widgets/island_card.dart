import 'package:flutter/material.dart';

import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../data/island_repository.dart';

class IslandCard extends StatelessWidget {
  const IslandCard({super.key, required this.island, this.onTap});

  final IslandModel island;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: softDecoration(AppColors.white, radius: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(island.name, style: AppText.titleSmall),
          const SizedBox(height: 6),
          Text('${island.fragmentCount} 束光 · ${island.status}',
              style: AppText.caption),
        ]),
      ),
    );
  }
}
