import 'package:flutter/material.dart';

class FreqWordsCloud extends StatelessWidget {
  const FreqWordsCloud({super.key, required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return Wrap(
        spacing: 8,
        children: words.map((word) => Chip(label: Text(word))).toList());
  }
}
