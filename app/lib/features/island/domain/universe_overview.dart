import '../../fragment/domain/fragment.dart';
import '../../relation/domain/relation.dart';
import 'island_model.dart';

enum BranchOrderMode { chronological, development, custom }

enum RelationDirection { forward, bidirectional }

class IslandVisualNode {
  const IslandVisualNode({
    required this.island,
    required this.fragments,
  });

  final IslandModel island;
  final List<Fragment> fragments;

  int get fragmentCount => fragments.length;
  int get imageCount =>
      fragments.expand((fragment) => fragment.mediaUrls).where(_isImage).length;
  int get audioCount =>
      fragments.expand((fragment) => fragment.mediaUrls).where(_isAudio).length;
  int get textCount => fragments
      .where((fragment) => fragment.contentText.trim().isNotEmpty)
      .length;

  DateTime? get firstAt => fragments.isEmpty
      ? null
      : fragments
          .map((fragment) => fragment.createdAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);

  DateTime? get lastAt => fragments.isEmpty
      ? null
      : fragments
          .map((fragment) => fragment.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);

  static bool _isImage(String value) {
    final source = value.toLowerCase();
    return source.startsWith('data:image/') ||
        RegExp(r'\.(jpg|jpeg|png|webp|heic|gif)(\?|$)').hasMatch(source);
  }

  static bool _isAudio(String value) {
    final source = value.toLowerCase();
    return source.startsWith('data:audio/') ||
        RegExp(r'\.(m4a|mp3|wav|aac|ogg|opus)(\?|$)').hasMatch(source);
  }
}

class BranchVisualEdge {
  const BranchVisualEdge({
    required this.relation,
    required this.direction,
  });

  final Relation relation;
  final RelationDirection direction;
}

class BranchVisualSummary {
  const BranchVisualSummary({
    required this.publicId,
    required this.name,
    required this.fragments,
    required this.edges,
    this.orderMode = BranchOrderMode.chronological,
  });

  final String publicId;
  final String name;
  final List<Fragment> fragments;
  final List<BranchVisualEdge> edges;
  final BranchOrderMode orderMode;

  int get fragmentCount => fragments.length;
  int get edgeCount => edges.length;
  bool get hasBidirectional =>
      edges.any((edge) => edge.direction == RelationDirection.bidirectional);
  DateTime? get firstAt => fragments.isEmpty ? null : fragments.first.createdAt;
  DateTime? get lastAt => fragments.isEmpty ? null : fragments.last.createdAt;
}

class UniverseOverview {
  const UniverseOverview({
    required this.islands,
    required this.branches,
    required this.fragments,
    required this.relations,
  });

  final List<IslandVisualNode> islands;
  final List<BranchVisualSummary> branches;
  final List<Fragment> fragments;
  final List<Relation> relations;

  int get islandCount => islands.length;
  int get branchCount => branches.length;
  int get fragmentCount => fragments.length;
  int get edgeCount => relations.length;
}
