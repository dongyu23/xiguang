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
    this.nightMode = false,
    this.onTap,
    this.onDeleted,
  });

  final String label;
  final bool filled;
  final bool nightMode;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: nightMode
              ? (filled
                  ? AppColors.teaGreen.withValues(alpha: .82)
                  : AppColors.white.withValues(alpha: .10))
              : (filled ? AppColors.ink : AppColors.paper),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: nightMode
                ? (filled
                    ? AppColors.teaGreen.withValues(alpha: .72)
                    : AppColors.white.withValues(alpha: .16))
                : (filled ? AppColors.ink : AppColors.line),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.chip.copyWith(
                color: nightMode
                    ? (filled ? AppColors.ink : AppText.nightInkMuted)
                    : (filled ? Colors.white : AppColors.inkMuted),
              ),
            ),
            if (onDeleted != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDeleted,
                child: Icon(Icons.close,
                    size: 14,
                    color: nightMode
                        ? (filled
                            ? AppColors.ink.withValues(alpha: .72)
                            : AppText.nightInkMuted)
                        : (filled ? Colors.white70 : AppColors.inkMuted)),
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
  const MiniTag({
    super.key,
    required this.label,
    this.filled = false,
    this.nightMode = false,
    this.compact = false,
  });

  final String label;
  final bool filled;
  final bool nightMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: nightMode
            ? (filled
                ? AppColors.teaGreen.withValues(alpha: .72)
                : AppColors.white.withValues(alpha: .10))
            : (filled
                ? AppColors.ink
                : (compact
                    ? AppColors.ink.withValues(alpha: .08)
                    : AppColors.paper)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          fontSize: compact ? 10 : null,
          fontWeight: compact ? FontWeight.w600 : null,
          color: nightMode
              ? (filled ? AppColors.ink : AppText.nightInkMuted)
              : (filled ? Colors.white : AppColors.inkMuted),
        ),
      ),
    );
  }
}
