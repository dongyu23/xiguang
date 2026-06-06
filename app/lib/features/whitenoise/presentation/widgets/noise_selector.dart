import 'package:flutter/material.dart';

class NoiseSelector extends StatelessWidget {
  const NoiseSelector({super.key, required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return ListView(
        scrollDirection: Axis.horizontal,
        children: names.map((name) => Chip(label: Text(name))).toList());
  }
}
