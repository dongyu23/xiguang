import 'package:flutter/material.dart';

class NoisePlayer extends StatelessWidget {
  const NoisePlayer({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(children: [const Icon(Icons.play_arrow), Text(name)]);
  }
}
