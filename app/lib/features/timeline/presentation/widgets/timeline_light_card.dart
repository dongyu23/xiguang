import 'package:flutter/material.dart';

class TimelineLightCard extends StatelessWidget {
  const TimelineLightCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(text));
  }
}
