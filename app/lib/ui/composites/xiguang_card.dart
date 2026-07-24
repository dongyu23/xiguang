import 'package:flutter/material.dart';

import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/motion.dart';
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
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.margin,
    this.selected = false,
    this.highlighted = false,
  });

  final Widget child;
  final XiguangCardVariant variant;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCancelCallback? onTapCancel;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;
  final EdgeInsetsGeometry? margin;
  final bool selected;
  final bool highlighted;

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
    final decoration = selected || highlighted
        ? baseDecoration.copyWith(
            border: Border.all(
              color: theme.accent.withValues(alpha: highlighted ? .92 : 1),
              width: highlighted ? 1.8 : 1.4,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: theme.accent.withValues(
                        alpha: theme.isNight ? .18 : .14,
                      ),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : baseDecoration.boxShadow,
          )
        : baseDecoration;
    final content = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: child,
    );
    if (onTap == null && onLongPress == null) return content;
    return GestureDetector(
      onLongPress: onLongPress,
      onLongPressStart: onLongPressStart,
      onLongPressEnd: onLongPressEnd,
      behavior: HitTestBehavior.translucent,
      child: InkWell(
        onTap: onTap,
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        onTapCancel: onTapCancel,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: content,
      ),
    );
  }
}
