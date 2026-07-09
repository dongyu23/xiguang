import '../../fragment/domain/fragment.dart';
import 'island_model.dart';

class IslandNotManualException implements Exception {
  const IslandNotManualException();
}

abstract class IslandRepositoryPort {
  Future<List<IslandModel>> listIslands({List<Fragment>? cachedFragments});
  Future<List<IslandModel>?> tryListRemoteIslands();
  List<IslandModel> computeIslandsFromFragments(List<Fragment> fragments);
  Future<IslandModel?> getIsland(String name);
  Future<IslandModel> createIsland(String name, String description);
  Future<IslandModel> addFragments(int islandId, List<int> fragmentIds);
  Future<IslandModel> removeFragments(int islandId, List<int> fragmentIds);
  Future<List<Fragment>> listIslandFragments(String name, {int? islandId});
}
