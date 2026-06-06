import 'star_graph.dart';

abstract interface class StarMapRepositoryContract {
  Future<StarGraph> load({int? rootFragmentId, int depth = 2});
}
