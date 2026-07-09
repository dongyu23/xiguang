import 'package:flutter/material.dart';

import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/spacing.dart';
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
    final theme = NightTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.widgetPadding,
            vertical: AppSpacing.tagPadding),
        decoration: BoxDecoration(
          color: filled ? theme.accent.withValues(alpha: .82) : theme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: filled ? theme.accent : theme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.chip.copyWith(
                color: filled ? theme.background : theme.foregroundMuted,
              ),
            ),
            if (onDeleted != null) ...[
              const SizedBox(width: AppSpacing.xs),
              GestureDetector(
                onTap: onDeleted,
                child: Icon(Icons.close,
                    size: 14,
                    color: filled
                        ? theme.background.withValues(alpha: .72)
                        : theme.foregroundMuted),
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
    this.compact = false,
  });

  final String label;
  final bool filled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.s7 : AppSpacing.sm,
        vertical: compact ? AppSpacing.s3 : AppSpacing.s5,
      ),
      decoration: BoxDecoration(
        color: filled
            ? theme.accent.withValues(alpha: .72)
            : theme.surface.withValues(alpha: compact ? .74 : 1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppText.chip.copyWith(
          color: filled ? theme.background : theme.foregroundMuted,
        ),
      ),
    );
  }
}
