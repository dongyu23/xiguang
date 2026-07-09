import 'package:flutter/material.dart';

import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';

class XiguangSection extends StatelessWidget {
  const XiguangSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.action,
  });

  final String title;
  final String? description;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title,
                  style: AppText.titleMedium.copyWith(color: theme.foreground)),
            ),
            if (action != null) action!,
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            description!,
            style: AppText.caption.copyWith(color: theme.foregroundMuted),
          ),
        ],
        const SizedBox(height: AppSpacing.s10),
        child,
      ],
    );
  }
}
