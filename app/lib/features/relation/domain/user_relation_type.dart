import 'package:flutter/material.dart';

/// 用户关系类型实体 - 默认 7 个 + 自定义。
///
/// 与 [UserEmotion] 同构：默认类型 isDefault=true 不可删除；自定义类型可增删改。
/// relation.relation_type 字段仍存类型名 text，删类型时织线保留原文字。
///
/// 关系类型名即存储值（如"回声"），与情绪选择器一致——后端 relation_type
/// 列为 TEXT，不接受枚举约束，用户自定义类型直接以中文名入库。
class UserRelationType {
  const UserRelationType({
    required this.id,
    required this.name,
    required this.color,
    required this.iconKey,
    required this.description,
    required this.isDefault,
    required this.sortOrder,
    this.hidden = false,
  });

  final int id;
  final String name;
  final Color color;
  final String iconKey;
  final String description;
  final bool isDefault;
  final int sortOrder;

  /// 是否在选择器隐藏；隐藏后织线原文字保留。
  final bool hidden;

  UserRelationType copyWith({
    String? name,
    Color? color,
    String? iconKey,
    String? description,
    int? sortOrder,
    bool? hidden,
  }) {
    return UserRelationType(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      iconKey: iconKey ?? this.iconKey,
      description: description ?? this.description,
      isDefault: isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
      hidden: hidden ?? this.hidden,
    );
  }
}
