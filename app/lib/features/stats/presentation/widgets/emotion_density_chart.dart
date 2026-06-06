import 'package:flutter/material.dart';

class EmotionDensityChart extends StatelessWidget {
  const EmotionDensityChart({super.key, required this.values});

  final Map<String, double> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: values.entries
          .map((entry) => LinearProgressIndicator(value: entry.value))
          .toList(),
    );
  }
}
