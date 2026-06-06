import '../domain/relation.dart';
import '../domain/relation_repository.dart';
import 'relation_api.dart';

class RelationRepositoryImpl implements RelationRepositoryContract {
  const RelationRepositoryImpl(this._api);

  final RelationApi _api;

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
    return Relation(
      id: body['id'] as int? ?? 0,
      publicId: body['public_id'] as String? ?? '',
      userId: body['user_id'] as int? ?? 0,
      sourceFragmentId: sourceFragmentId,
      targetFragmentId: targetFragmentId,
      relationType: relationType,
      note: note,
    );
  }

  @override
  Future<void> delete(int id) => _api.delete(id);
}
