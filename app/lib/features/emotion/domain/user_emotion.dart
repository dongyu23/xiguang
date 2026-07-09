import 'package:flutter/material.dart';

/// 用户情绪实体 — 默认 7 个 + 自定义。
///
/// 默认情绪 isDefault=true 不可删除（避免选择器变空）；
/// 自定义情绪可增删改。fragment.emotion 字段仍存情绪名 text，
/// 删除情绪时光片保留原文字，只是选择器不再显示该情绪。
class UserEmotion {
  const UserEmotion({
    required this.id,
    required this.name,
    required this.color,
    required this.description,
    required this.isDefault,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final Color color;
  final String description;
  final bool isDefault;
  final int sortOrder;

  UserEmotion copyWith({
    String? name,
    Color? color,
    String? description,
    int? sortOrder,
  }) {
    return UserEmotion(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      description: description ?? this.description,
      isDefault: isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
