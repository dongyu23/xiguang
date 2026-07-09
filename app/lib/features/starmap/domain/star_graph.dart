import 'package:flutter/foundation.dart';

import 'star_edge.dart';
import 'star_node.dart';

class StarGraph {
  const StarGraph({required this.nodes, required this.edges});

  final List<StarNode> nodes;
  final List<StarEdge> edges;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarGraph &&
          listEquals(nodes, other.nodes) &&
          listEquals(edges, other.edges);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(nodes),
        Object.hashAll(edges),
      );
}
