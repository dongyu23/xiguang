import 'package:flutter/material.dart';

class DateGroupWidget extends StatelessWidget {
  const DateGroupWidget({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.titleMedium),
      child,
    ]);
  }
}
