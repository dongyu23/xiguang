import 'package:flutter/material.dart';

import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/spacing.dart';

class XiguangBottomSheet extends StatelessWidget {
  const XiguangBottomSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        padding: const EdgeInsets.all(AppSpacing.s18),
        decoration: BoxDecoration(
          color: theme.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: theme.border),
        ),
        child: child,
      ),
    );
  }
}
