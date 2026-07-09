import 'package:flutter/material.dart';
import '../../design/tokens/spacing.dart';

class TimeRiverItem extends StatelessWidget {
  const TimeRiverItem({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: child);
  }
}
