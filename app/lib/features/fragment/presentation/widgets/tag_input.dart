import 'package:flutter/material.dart';

class TagInput extends StatelessWidget {
  const TagInput({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: '标签'));
  }
}
