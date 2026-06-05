import 'package:flutter/material.dart';

import '../../design/tokens/colors.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/typography.dart';

/// 标签芯片
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.filled = false,
    this.onTap,
    this.onDeleted,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? AppColors.ink : AppColors.paper,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: filled ? AppColors.ink : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.chip.copyWith(
                color: filled ? Colors.white : AppColors.inkMuted,
              ),
            ),
            if (onDeleted != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDeleted,
                child: Icon(Icons.close, size: 14,
                  color: filled ? Colors.white70 : AppColors.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 迷你标签 — 光片卡片内使用
class MiniTag extends StatelessWidget {
  const MiniTag({super.key, required this.label, this.filled = false});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? AppColors.ink : AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          color: filled ? Colors.white : AppColors.inkMuted,
        ),
      ),
    );
  }
}
