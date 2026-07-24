import 'package:drift/drift.dart';

import '../../shared/data/local/app_database.dart';
import '../domain/relation.dart';
import '../domain/relation_repository.dart';
import 'relation_api.dart';

class RelationRepositoryImpl implements RelationRepositoryContract {
  const RelationRepositoryImpl(this._api, this._db);

  final RelationApi _api;
  final AppDatabase _db;

  @override
  Future<Relation> create({
    required int sourceFragmentId,
    required int targetFragmentId,
    required String relationType,
    String? note,
  }) async {
    final body = await _api.create({
      'source_fragment_id': sourceFragmentId,
      'target_fragment_id': targetFragmentId,
      'relation_type': relationType,
      if (note != null) 'note': note,
    });
    final relation = Relation(
      id: body['id'] as int? ?? 0,
      publicId: body['public_id'] as String? ?? '',
      userId: body['user_id'] as int? ?? 0,
      sourceFragmentId: sourceFragmentId,
      targetFragmentId: targetFragmentId,
      relationType: relationType,
      note: note,
    );
    await _mirror(relation);
    return relation;
  }

  @override
  Future<void> delete(int id) async {
    await _api.delete(id);
    await (_db.delete(_db.localRelations)
          ..where((table) => table.serverId.equals(id)))
        .go();
  }

  @override
  Future<List<Relation>> list({int? fragmentId}) async {
    try {
      final body = await _api.list(fragmentId: fragmentId);
      final remote = (body['relations'] as List<dynamic>? ?? const [])
          .map((item) => _fromJson(item as Map<String, dynamic>))
          .toList();
      for (final relation in remote) {
        await _mirror(relation);
      }
      return remote;
    } catch (_) {
      return _readLocal(fragmentId: fragmentId);
    }
  }

  Relation _fromJson(Map<String, dynamic> body) {
    return Relation(
      id: body['id'] as int? ?? 0,
      publicId: body['public_id'] as String? ?? '',
      userId: body['user_id'] as int? ?? 0,
      sourceFragmentId: body['source_fragment_id'] as int? ?? 0,
      targetFragmentId: body['target_fragment_id'] as int? ?? 0,
      relationType: body['relation_type'] as String? ?? 'reminds_me',
      note: body['note'] as String?,
    );
  }

  Future<void> _mirror(Relation relation) async {
    final source = await _db.getFragmentById(relation.sourceFragmentId);
    final target = await _db.getFragmentById(relation.targetFragmentId);
    if (source == null || target == null || relation.publicId.isEmpty) return;
    await _db.into(_db.localRelations).insert(
          LocalRelationsCompanion.insert(
            serverId: Value(relation.id),
            publicId: relation.publicId,
            sourcePublicId: source.publicId,
            targetPublicId: target.publicId,
            relationType: relation.relationType,
            note: Value(relation.note),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<List<Relation>> _readLocal({int? fragmentId}) async {
    final rows = await _db.select(_db.localRelations).get();
    final fragments = await _db.getAllFragments();
    final ids = {
      for (final fragment in fragments) fragment.publicId: fragment.id
    };
    return rows
        .map((row) => Relation(
              id: row.serverId ?? row.id,
              publicId: row.publicId,
              sourceFragmentId: ids[row.sourcePublicId] ?? 0,
              targetFragmentId: ids[row.targetPublicId] ?? 0,
              relationType: row.relationType,
              note: row.note,
            ))
        .where((relation) =>
            fragmentId == null ||
            relation.sourceFragmentId == fragmentId ||
            relation.targetFragmentId == fragmentId)
        .toList();
  }
}
