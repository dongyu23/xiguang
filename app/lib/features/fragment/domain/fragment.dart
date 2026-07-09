import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../design/tokens/colors.dart';

part 'fragment.freezed.dart';
part 'fragment.g.dart';

/// Fragment 实体 — "光片"
@freezed
class Fragment with _$Fragment {
  const Fragment._();

  const factory Fragment({
    required int id,
    @Default('') String publicId,
    @Default(0) int userId,
    @Default('') String contentText,
    @Default('说不清') String emotion,
    @Default('twilight') String status,
    @Default([]) List<String> mediaUrls,
    @Default([]) List<String> tags,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Fragment;

  factory Fragment.fromJson(Map<String, dynamic> json) =>
      _$FragmentFromJson(json);

  /// Transitional display helpers. New UI code should use FragmentView instead.
  String get title {
    final firstLine = contentText.trim().split('\n').first;
    if (firstLine.length <= 16) return firstLine;
    return '${firstLine.substring(0, 16)}...';
  }

  String get time {
    final local = createdAt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String get dateLabel {
    final local = createdAt.toLocal();
    return '${local.year}年${local.month}月${local.day}日';
  }

  Color get color => AppColors.emotionColor(emotion);
}
