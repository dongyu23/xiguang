/// Relation 实体 — "织线"
class Relation {
  const Relation({required this.id, required this.publicId, required this.userId,
    required this.sourceFragmentId, required this.targetFragmentId, required this.relationType, this.note});

  final int id;
  final String publicId;
  final int userId;
  final int sourceFragmentId;
  final int targetFragmentId;
  final String relationType; // cause/inspiration/emotion_continue/same_phase/reminds_me/custom
  final String? note;
}
