import 'package:flutter/material.dart';

import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import 'xiguang_card.dart';

class XiguangEmptyState extends StatelessWidget {
  const XiguangEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.wb_sunny_outlined,
    this.action,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangCard(
      child: Column(
        children: [
          Icon(icon, size: 30, color: theme.accent),
          const SizedBox(height: AppSpacing.s10),
          Text(title,
              style: AppText.titleMedium.copyWith(color: theme.foreground)),
          const SizedBox(height: AppSpacing.s6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: theme.foregroundMuted),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.s14),
            action!
          ],
        ],
      ),
    );
  }
}
