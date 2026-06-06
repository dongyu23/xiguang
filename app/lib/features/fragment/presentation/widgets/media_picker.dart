import 'package:flutter/material.dart';

class MediaPicker extends StatelessWidget {
  const MediaPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
        children: [Icon(Icons.photo_outlined), Icon(Icons.mic_none)]);
  }
}
