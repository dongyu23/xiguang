import 'package:flutter/material.dart';

/// 用户情绪实体 - 默认 7 个 + 自定义。
///
/// 默认情绪 isDefault=true 不可删除（避免选择器变空）；自定义情绪可增删改。
/// fragment.emotion 字段仍存情绪名 text，删情绪时光片保留原文字。
///
/// 三个独立维度：
/// - isDefault：系统内置（控制可删性，不可变）
/// - isUserDefault：用户选定的首选心情（全表至多一个），驱动选择器初始选中
/// - hidden：是否在选择器隐藏；隐藏后光片原文字保留（与删除同理）
class UserEmotion {
  const UserEmotion({
    required this.id,
    required this.name,
    required this.color,
    required this.description,
    required this.isDefault,
    required this.sortOrder,
    this.soundKey,
    this.isUserDefault = false,
    this.hidden = false,
  });

  final int id;
  final String name;
  final Color color;
  final String description;
  final bool isDefault;
  final int sortOrder;

  /// 绑定的声音 key（见 emotion_sounds.dart），null = 未绑定。
  final String? soundKey;

  /// 用户选定的首选心情，全表至多一个为 true。
  final bool isUserDefault;

  /// 是否在选择器隐藏；隐藏后光片原文字保留。
  final bool hidden;

  UserEmotion copyWith({
    String? name,
    Color? color,
    String? description,
    int? sortOrder,
    String? soundKey,
    bool clearSound = false,
    bool? isUserDefault,
    bool? hidden,
  }) {
    return UserEmotion(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      description: description ?? this.description,
      isDefault: isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
      soundKey: clearSound ? null : (soundKey ?? this.soundKey),
      isUserDefault: isUserDefault ?? this.isUserDefault,
      hidden: hidden ?? this.hidden,
    );
  }
}
