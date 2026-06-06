import 'package:flutter/material.dart';

import '../../../../design/tokens/colors.dart';

class IslandCanvas extends StatelessWidget {
  const IslandCanvas({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.teaGreen.withValues(alpha: .14),
            AppColors.mistBlue.withValues(alpha: .12),
          ],
        ),
      ),
      child: child ?? const SizedBox.expand(),
    );
  }
}
