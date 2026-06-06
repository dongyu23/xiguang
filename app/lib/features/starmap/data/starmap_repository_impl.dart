import '../domain/star_edge.dart';
import '../domain/star_graph.dart';
import '../domain/star_node.dart';
import '../domain/starmap_repository.dart';
import 'starmap_api.dart';

class StarMapRepositoryImpl implements StarMapRepositoryContract {
  const StarMapRepositoryImpl(this._api);

  final StarMapApi _api;

  @override
  Future<StarGraph> load({int? rootFragmentId, int depth = 2}) async {
    final body = await _api.load(rootFragmentId: rootFragmentId, depth: depth);
    final nodes = (body['nodes'] as List<dynamic>? ?? const [])
        .map((item) => item as Map<String, dynamic>)
        .map((item) => StarNode(
              fragmentId: item['fragment_id'] as int? ?? 0,
              x: (item['x'] as num?)?.toDouble() ?? 0,
              y: (item['y'] as num?)?.toDouble() ?? 0,
              label: item['label'] as String? ?? '',
            ))
        .toList();
    final edges = (body['edges'] as List<dynamic>? ?? const [])
        .map((item) => item as Map<String, dynamic>)
        .map((item) => StarEdge(
              sourceId: item['source_id'] as int? ?? 0,
              targetId: item['target_id'] as int? ?? 0,
              relationType: item['relation_type'] as String? ?? 'reminds_me',
            ))
        .toList();
    return StarGraph(nodes: nodes, edges: edges);
  }
}
