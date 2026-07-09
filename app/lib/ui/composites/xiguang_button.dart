import 'package:flutter/material.dart';

import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/spacing.dart';

enum XiguangButtonVariant { primary, secondary, destructive }

class XiguangButton extends StatelessWidget {
  const XiguangButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = XiguangButtonVariant.primary,
    this.leading,
    this.loading = false,
    this.expand = true,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final XiguangButtonVariant variant;
  final Widget? leading;
  final bool loading;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final enabled = loading ? null : onPressed;
    final child = loading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.s6)
              ],
              Text(label),
            ],
          );
    final button = switch (variant) {
      XiguangButtonVariant.primary => FilledButton(
          onPressed: enabled,
          style: FilledButton.styleFrom(
            backgroundColor: theme.isNight ? theme.accent : theme.foreground,
            foregroundColor: theme.isNight ? theme.background : theme.surface,
            minimumSize: Size(0, height),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          child: child,
        ),
      XiguangButtonVariant.secondary => OutlinedButton(
          onPressed: enabled,
          style: OutlinedButton.styleFrom(minimumSize: Size(0, height)),
          child: child,
        ),
      XiguangButtonVariant.destructive => FilledButton(
          onPressed: enabled,
          style: FilledButton.styleFrom(
            backgroundColor: theme.danger,
            minimumSize: Size(0, height),
          ),
          child: child,
        ),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
