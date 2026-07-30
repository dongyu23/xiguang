import 'user_relation_type.dart';

/// 关系类型仓库契约（与 emotion_repository.dart 的 EmotionRepositoryPort 同构）。
abstract class RelationTypeRepositoryPort {
  Future<List<UserRelationType>> getAll();

  Future<int> addCustom(String name, {String? description, String? iconKey});

  Future<void> update(UserRelationType type);

  Future<void> delete(int id);

  Future<void> setHidden(int id, bool hidden);
}
