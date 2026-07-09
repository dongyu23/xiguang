import 'package:flutter/material.dart';

import '../../../design/tokens/colors.dart';
import '../domain/fragment.dart';

/// Presentation-only derivations for a Fragment.
/// Domain entities intentionally do not depend on Flutter or design tokens.
extension FragmentView on Fragment {
  String get displayTitle {
    final firstLine = contentText.trim().split('\n').first;
    if (firstLine.length <= 16) return firstLine;
    return '${firstLine.substring(0, 16)}...';
  }

  String get displayTime {
    final local = createdAt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String get displayDateLabel {
    final local = createdAt.toLocal();
    return '${local.year}年${local.month}月${local.day}日';
  }

  String get displayEmotion => emotion;

  Color get emotionColor => AppColors.emotionColor(displayEmotion);
}
