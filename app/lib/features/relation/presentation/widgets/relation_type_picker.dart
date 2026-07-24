import 'package:flutter/material.dart';

import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';

class RelationTypePicker extends StatelessWidget {
  const RelationTypePicker({
    super.key,
    required this.onSelected,
    this.selectedType = 'reminds_me',
  });

  final ValueChanged<String> onSelected;
  final String selectedType;

  static const options = [
    RelationTypeOption(
      value: 'reminds_me',
      label: '回声',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.lilac,
    ),
    RelationTypeOption(
      value: 'inspiration',
      label: '伏笔',
      icon: Icons.edit_note_rounded,
      color: AppColors.mistBlue,
    ),
    RelationTypeOption(
      value: 'emotion_continue',
      label: '余震',
      icon: Icons.trip_origin_rounded,
      color: AppColors.teaGreen,
    ),
    RelationTypeOption(
      value: 'same_phase',
      label: '平行宇宙',
      icon: Icons.grain_rounded,
      color: AppColors.inkMuted,
    ),
    RelationTypeOption(
      value: 'cause',
      label: '小小救命',
      icon: Icons.favorite_border_rounded,
      color: AppColors.sunsetCoral,
    ),
    RelationTypeOption(
      value: 'custom',
      label: '旧光',
      icon: Icons.circle_rounded,
      color: AppColors.emotionUnclear,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 40,
      ),
      itemBuilder: (context, index) => _RelationChip(
        option: options[index],
        selected: selectedType == options[index].value,
        onTap: () => onSelected(options[index].value),
      ),
    );
  }
}

class _RelationChip extends StatelessWidget {
  const _RelationChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final RelationTypeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: SizedBox.expand(
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: AppMotion.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s9),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.white.withValues(alpha: .96)
                : AppColors.white.withValues(alpha: .58),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? AppColors.lilac
                  : AppColors.white.withValues(alpha: .72),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: option.color.withValues(alpha: selected ? .78 : .34),
                shape: BoxShape.circle,
              ),
              child: Icon(
                option.icon,
                color: selected ? AppColors.white : AppColors.inkMuted,
                size: 11,
              ),
            ),
            const SizedBox(width: AppSpacing.s6),
            Flexible(
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.chip.copyWith(
                  color: selected ? AppColors.ink : AppColors.inkMuted,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class RelationTypeOption {
  const RelationTypeOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
}
