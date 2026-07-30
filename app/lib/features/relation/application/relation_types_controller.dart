import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/relation_type_color.dart';
import '../domain/user_relation_type.dart';

export '../../../app/providers.dart' show relationTypeRepositoryProvider;
export '../domain/relation_type_color.dart' show autoColorForRelationTypeName;

/// 选择器首屏最多展示的关系类型数（与情绪一致：7 个 + 1 个"更多"按钮）。
const maxShownRelationTypes = 7;

final relationTypesProvider =
    AsyncNotifierProvider<RelationTypesController, List<UserRelationType>>(
  RelationTypesController.new,
);

class DuplicateRelationTypeNameException implements Exception {
  const DuplicateRelationTypeNameException();
}

class RelationTypesController extends AsyncNotifier<List<UserRelationType>> {
  @override
  Future<List<UserRelationType>> build() {
    return ref.watch(relationTypeRepositoryProvider).getAll();
  }

  Future<UserRelationType> addCustom(String name,
      {String? description, String? iconKey}) async {
    final types = await future;
    _ensureUnique(types, name);
    state =
        const AsyncLoading<List<UserRelationType>>().copyWithPrevious(state);
    try {
      final repository = ref.read(relationTypeRepositoryProvider);
      final id = await repository.addCustom(name,
          description: description, iconKey: iconKey);
      final type = UserRelationType(
        id: id,
        name: name,
        color: autoColorForRelationTypeName(name),
        iconKey: iconKey ?? 'auto_awesome_rounded',
        description: description ?? '',
        isDefault: false,
        sortOrder: types.length,
      );
      state = AsyncData([...types, type]);
      return type;
    } catch (error, stackTrace) {
      state = AsyncError<List<UserRelationType>>(error, stackTrace)
          .copyWithPrevious(AsyncData(types));
      rethrow;
    }
  }

  Future<void> save({
    required UserRelationType existing,
    required String name,
    required String iconKey,
    required String description,
  }) async {
    final types = await future;
    _ensureUnique(types, name, excludingId: existing.id);
    final updated = existing.copyWith(
      name: name,
      iconKey: iconKey,
      description: description,
    );
    state =
        const AsyncLoading<List<UserRelationType>>().copyWithPrevious(state);
    try {
      await ref.read(relationTypeRepositoryProvider).update(updated);
      state = AsyncData([
        for (final type in types)
          if (type.id == updated.id) updated else type,
      ]);
    } catch (error, stackTrace) {
      state = AsyncError<List<UserRelationType>>(error, stackTrace)
          .copyWithPrevious(AsyncData(types));
      rethrow;
    }
  }

  Future<void> setHidden(int id, bool hidden) async {
    final types = await future;
    state =
        const AsyncLoading<List<UserRelationType>>().copyWithPrevious(state);
    try {
      await ref.read(relationTypeRepositoryProvider).setHidden(id, hidden);
      state = AsyncData([
        for (final type in types)
          if (type.id == id) type.copyWith(hidden: hidden) else type,
      ]);
    } catch (error, stackTrace) {
      state = AsyncError<List<UserRelationType>>(error, stackTrace)
          .copyWithPrevious(AsyncData(types));
      rethrow;
    }
  }

  /// 切换隐藏状态（供 MoreSheet 勾选用）。
  Future<void> toggleHidden(UserRelationType type) async {
    await setHidden(type.id, !type.hidden);
  }

  Future<void> delete(int id) async {
    final types = await future;
    final target = types.where((t) => t.id == id).firstOrNull;
    if (target == null || target.isDefault) return;
    state =
        const AsyncLoading<List<UserRelationType>>().copyWithPrevious(state);
    try {
      await ref.read(relationTypeRepositoryProvider).delete(id);
      state = AsyncData(types.where((t) => t.id != id).toList());
    } catch (error, stackTrace) {
      state = AsyncError<List<UserRelationType>>(error, stackTrace)
          .copyWithPrevious(AsyncData(types));
      rethrow;
    }
  }

  void _ensureUnique(List<UserRelationType> types, String name,
      {int? excludingId}) {
    for (final type in types) {
      if (type.id == excludingId) continue;
      if (type.name == name) {
        throw const DuplicateRelationTypeNameException();
      }
    }
  }
}
