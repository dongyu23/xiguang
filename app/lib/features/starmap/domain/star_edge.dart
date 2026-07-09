class StarEdge {
  const StarEdge({
    required this.sourceId,
    required this.targetId,
    required this.relationType,
  });

  final int sourceId;
  final int targetId;
  final String relationType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarEdge &&
          sourceId == other.sourceId &&
          targetId == other.targetId &&
          relationType == other.relationType;

  @override
  int get hashCode => Object.hash(sourceId, targetId, relationType);
}
