import '../../fragment/data/fragment_repository.dart';
import 'island.dart';

abstract class IslandRepositoryPort {
  Future<List<Island>> listIslands();

  Future<Island?> getIsland(String name);

  Future<List<LightFragmentModel>> listIslandFragments(String name);
}
