import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../design/tokens/colors.dart';
import '../../shared/data/local/app_database.dart';
import '../domain/user_emotion.dart';

/// 根据情绪名确定性分配一个莫兰迪色（自定义情绪用）。
/// 必须与 AppColors.emotionColor() 的 hash 兜底逻辑保持一致——
/// DB 存的颜色 = emotionColor(name) 算出的颜色，保证全 app 同名情绪同色。
Color autoColorForName(String name) {
  if (name.isEmpty) return AppColors.emotionUnclear;
  var hash = 0;
  for (final c in name.codeUnits) {
    hash = (hash * 31 + c) & 0x7FFFFFFF;
  }
  // 复用 AppColors 里的兜底色板，单一信息来源。
  const palette = <int>[
    0xFFB8C5B2, 0xFFC9B8D4, 0xFFD4C5B8, 0xFFB8C9D4,
    0xFFD4B8C0, 0xFFC0D4B8, 0xFFB8D4C9, 0xFFD4CBB8,
  ];
  return Color(palette[hash % palette.length]);
}

class EmotionRepository {
  EmotionRepository(this._db);

  final AppDatabase _db;

  Future<List<UserEmotion>> getAll() async {
    final rows = await _db.getAllEmotions();
    return rows
        .map((e) => UserEmotion(
              id: e.id,
              name: e.name,
              color: Color(e.colorHex),
              description: e.description,
              isDefault: e.isDefault,
              sortOrder: e.sortOrder,
            ))
        .toList();
  }

  Future<int> addCustom(String name, {String? description}) async {
    final order = await _db.maxEmotionSortOrder();
    return _db.insertEmotion(EmotionsCompanion.insert(
      name: name,
      colorHex: autoColorForName(name).toARGB32(),
      description: Value(description ?? ''),
      isDefault: const Value(false),
      sortOrder: Value(order + 1),
    ));
  }

  Future<void> update(UserEmotion emotion) async {
    await _db.updateEmotion(EmotionsCompanion(
      id: Value(emotion.id),
      name: Value(emotion.name),
      colorHex: Value(emotion.color.toARGB32()),
      description: Value(emotion.description),
      isDefault: Value(emotion.isDefault),
      sortOrder: Value(emotion.sortOrder),
    ));
  }

  Future<void> delete(int id) async {
    await _db.deleteEmotion(id);
  }
}

final emotionRepositoryProvider = Provider<EmotionRepository>((ref) {
  // 复用全局 appDatabaseProvider 单例，避免多 AppDatabase 实例
  return EmotionRepository(ref.read(appDatabaseProvider));
});

/// 全部情绪（默认+自定义），按 sortOrder 排序。捕光选择器与管理页共用。
final emotionsProvider =
    FutureProvider<List<UserEmotion>>((ref) async {
  return ref.read(emotionRepositoryProvider).getAll();
});
