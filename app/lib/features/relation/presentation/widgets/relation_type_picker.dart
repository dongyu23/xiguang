import 'package:flutter/material.dart';

import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';

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
      color: Color(0xFFB8C5B2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options
          .map((type) => _RelationChip(
                option: type,
                selected: selectedType == type.value,
                onTap: () => onSelected(type.value),
              ))
          .toList(),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.white.withValues(alpha: .96)
              : AppColors.white.withValues(alpha: .58),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected
                ? AppColors.lilac
                : Colors.white.withValues(alpha: .72),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.lilac.withValues(alpha: .34),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: option.color.withValues(alpha: selected ? .78 : .34),
              shape: BoxShape.circle,
            ),
            child: Icon(
              option.icon,
              color: selected ? AppColors.white : AppColors.inkMuted,
              size: 13,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            option.label,
            style: AppText.chip.copyWith(
              color: selected ? AppColors.ink : AppColors.inkMuted,
              fontSize: 13,
            ),
          ),
        ]),
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
