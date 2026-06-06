import 'package:flutter/material.dart';

class TimelineFilterBar extends StatelessWidget {
  const TimelineFilterBar({super.key, this.onEmotionSelected});

  final ValueChanged<String>? onEmotionSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: ['平静', '开心', '说不清']
          .map((emotion) => FilterChip(
                label: Text(emotion),
                selected: false,
                onSelected: (_) => onEmotionSelected?.call(emotion),
              ))
          .toList(),
    );
  }
}
