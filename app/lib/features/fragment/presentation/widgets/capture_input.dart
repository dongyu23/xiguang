import 'package:flutter/material.dart';

class CaptureInput extends StatelessWidget {
  const CaptureInput({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 6,
      decoration: const InputDecoration(hintText: '把这一刻轻轻放在这里。'),
    );
  }
}
