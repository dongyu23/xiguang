import 'package:flutter/material.dart';

class StarmapCanvas extends StatelessWidget {
  const StarmapCanvas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(child: child);
  }
}
