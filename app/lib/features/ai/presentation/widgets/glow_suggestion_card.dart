import 'package:flutter/material.dart';

class GlowSuggestionCard extends StatelessWidget {
  const GlowSuggestionCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(child: ListTile(title: Text(text)));
  }
}
