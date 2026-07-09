import 'package:flutter/material.dart';

import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/spacing.dart';
import '../primitives/night_background.dart';

/// Shared page frame for product pages. New pages should not recreate their own
/// background, max-width and bottom-nav-safe padding.
class XiguangPage extends StatelessWidget {
  const XiguangPage({
    super.key,
    required this.child,
    this.scrollController,
    this.padding,
    this.scrollable = true,
    this.backgroundLayer,
  });

  final Widget child;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;
  final Widget? backgroundLayer;

  @override
  Widget build(BuildContext context) {
    final night = NightTheme.of(context);
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: child,
      ),
    );
    return ColoredBox(
      color: night.background,
      child: Stack(
        children: [
          const Positioned.fill(child: NightBackgroundPlaceholder()),
          if (backgroundLayer != null) Positioned.fill(child: backgroundLayer!),
          SafeArea(
            child: scrollable
                ? SingleChildScrollView(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: padding ??
                        EdgeInsets.fromLTRB(
                          AppSpacing.s22,
                          AppSpacing.s18,
                          AppSpacing.s22,
                          AppSpacing.pageBottomNav + bottomSafeArea,
                        ),
                    child: content,
                  )
                : Padding(
                    padding: padding ?? const EdgeInsets.all(AppSpacing.s22),
                    child: content,
                  ),
          ),
        ],
      ),
    );
  }
}
