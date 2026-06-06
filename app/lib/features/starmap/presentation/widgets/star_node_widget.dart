import 'package:flutter/material.dart';

class StarNodeWidget extends StatelessWidget {
  const StarNodeWidget({super.key, required this.label, this.onPanUpdate});

  final String label;
  final GestureDragUpdateCallback? onPanUpdate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onPanUpdate: onPanUpdate, child: Chip(label: Text(label)));
  }
}
