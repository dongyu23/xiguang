import 'package:freezed_annotation/freezed_annotation.dart';

part 'relation.freezed.dart';
part 'relation.g.dart';

/// Relation 实体 — "织线"
@freezed
class Relation with _$Relation {
  const factory Relation({
    required int id,
    @Default('') String publicId,
    @Default(0) int userId,
    required int sourceFragmentId,
    required int targetFragmentId,
    @Default('reminds_me') String relationType,
    String? note,
  }) = _Relation;

  factory Relation.fromJson(Map<String, dynamic> json) =>
      _$RelationFromJson(json);
}
