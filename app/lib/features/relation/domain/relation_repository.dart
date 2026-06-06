import 'relation.dart';

abstract interface class RelationRepositoryContract {
  Future<Relation> create({
    required int sourceFragmentId,
    required int targetFragmentId,
    required String relationType,
    String? note,
  });

  Future<void> delete(int id);
}
