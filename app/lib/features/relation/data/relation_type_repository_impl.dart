import 'dart:ui' show Color;

import 'package:drift/drift.dart' show Value;

import '../../../features/shared/data/local/app_database.dart';
import '../domain/relation_type_color.dart';
import '../domain/relation_type_repository.dart';
import '../domain/user_relation_type.dart';

class RelationTypeRepository implements RelationTypeRepositoryPort {
  RelationTypeRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<UserRelationType>> getAll() async {
    final rows = await _db.getAllRelationTypes();
    return rows
        .map((e) => UserRelationType(
              id: e.id,
              name: e.name,
              color: Color(e.colorHex),
              iconKey: e.iconKey,
              description: e.description,
              isDefault: e.isDefault,
              sortOrder: e.sortOrder,
              hidden: e.hidden,
            ))
        .toList();
  }

  @override
  Future<int> addCustom(String name,
      {String? description, String? iconKey}) async {
    final order = await _db.maxRelationTypeSortOrder();
    return _db.insertRelationType(RelationTypesCompanion.insert(
      name: name,
      colorHex: autoColorForRelationTypeName(name).toARGB32(),
      iconKey: Value(iconKey ?? 'auto_awesome_rounded'),
      description: Value(description ?? ''),
      isDefault: const Value(false),
      sortOrder: Value(order + 1),
    ));
  }

  @override
  Future<void> update(UserRelationType type) async {
    await _db.updateRelationType(RelationTypesCompanion(
      id: Value(type.id),
      name: Value(type.name),
      colorHex: Value(type.color.toARGB32()),
      iconKey: Value(type.iconKey),
      description: Value(type.description),
      isDefault: Value(type.isDefault),
      sortOrder: Value(type.sortOrder),
      hidden: Value(type.hidden),
    ));
  }

  @override
  Future<int> delete(int id) {
    return _db.deleteRelationType(id);
  }

  @override
  Future<void> setHidden(int id, bool hidden) {
    return _db.setRelationTypeHidden(id, hidden);
  }
}
