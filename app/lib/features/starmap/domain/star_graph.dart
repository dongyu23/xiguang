import 'star_edge.dart';
import 'star_node.dart';

class StarGraph {
  const StarGraph({required this.nodes, required this.edges});

  final List<StarNode> nodes;
  final List<StarEdge> edges;
}
