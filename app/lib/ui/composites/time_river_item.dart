import 'package:flutter/material.dart';

class TimeRiverItem extends StatelessWidget {
  const TimeRiverItem({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8), child: child);
  }
}
