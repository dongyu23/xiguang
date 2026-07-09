import 'package:flutter/material.dart';

import '../../../design/tokens/colors.dart';

/// Assigns a stable Morandi color to a custom emotion name.
Color autoColorForEmotionName(String name) {
  if (name.isEmpty) return AppColors.emotionUnclear;
  var hash = 0;
  for (final codeUnit in name.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7FFFFFFF;
  }
  const palette = <int>[
    0xFFB8C5B2,
    0xFFC9B8D4,
    0xFFD4C5B8,
    0xFFB8C9D4,
    0xFFD4B8C0,
    0xFFC0D4B8,
    0xFFB8D4C9,
    0xFFD4CBB8,
  ];
  return Color(palette[hash % palette.length]);
}
