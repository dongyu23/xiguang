import 'package:flutter/material.dart';

import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/shadows.dart';
import '../../design/tokens/spacing.dart';

enum XiguangCardVariant { soft, raised, outlined }

class XiguangCard extends StatelessWidget {
  const XiguangCard({
    super.key,
    required this.child,
    this.variant = XiguangCardVariant.soft,
    this.padding = const EdgeInsets.all(AppSpacing.s18),
    this.onTap,
    this.onLongPress,
    this.margin,
    this.selected = false,
  });

  final Widget child;
  final XiguangCardVariant variant;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? margin;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final baseDecoration = switch (variant) {
      XiguangCardVariant.soft => BoxDecoration(
          color: theme.surface.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: theme.border.withValues(alpha: .72)),
        ),
      XiguangCardVariant.raised => BoxDecoration(
          color: theme.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: softShadow,
        ),
      XiguangCardVariant.outlined => BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: theme.border),
        ),
    };
    final decoration = selected
        ? baseDecoration.copyWith(
            border: Border.all(color: theme.accent, width: 1.4),
          )
        : baseDecoration;
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: child,
    );
    if (onTap == null && onLongPress == null) return content;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: content,
    );
  }
}
