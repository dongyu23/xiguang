import 'package:flutter/material.dart';

import '../../../../ui/composites/emotion_picker.dart';

class EmotionPickerSheet extends StatelessWidget {
  const EmotionPickerSheet({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return EmotionPicker(selected: selected, onSelected: onSelected);
  }
}
