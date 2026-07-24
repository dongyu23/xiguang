import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/fragment/domain/fragment.dart';
import 'package:xiguang/features/island/application/island_create_controller.dart';
import 'package:xiguang/features/island/application/island_providers.dart';
import 'package:xiguang/features/island/application/universe_overview_provider.dart';
import 'package:xiguang/features/island/domain/island_model.dart';
import 'package:xiguang/features/island/domain/island_repository.dart';
import 'package:xiguang/features/island/domain/universe_overview.dart';

void main() {
  test('creating an empty island immediately invalidates universe overview',
      () async {
    var overviewBuilds = 0;
    final container = ProviderContainer(overrides: [
      islandRepositoryProvider.overrideWithValue(_FakeIslandRepository()),
      islandsProvider.overrideWith(_FakeIslandsNotifier.new),
      universeOverviewProvider.overrideWith((ref) async {
        overviewBuilds++;
        return const UniverseOverview(
          islands: [],
          branches: [],
          fragments: [],
          relations: [],
        );
      }),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(
      islandCreateControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(universeOverviewProvider.future);
    expect(overviewBuilds, 1);

    await container.read(islandCreateControllerProvider.notifier).create(
          name: '没有光的小岛',
          description: '',
        );
    await container.read(universeOverviewProvider.future);

    expect(overviewBuilds, 2);
  });
}

class _FakeIslandsNotifier extends IslandsNotifier {
  @override
  Future<List<IslandModel>> build() async => const [];
}

class _FakeIslandRepository implements IslandRepositoryPort {
  @override
  Future<IslandModel> createIsland(String name, String description) async {
    return IslandModel(
      name: name,
      islandId: 1,
      status: 'star_point',
      fragmentCount: 0,
      description: description,
      manual: true,
    );
  }

  @override
  Future<void> deleteIsland(int islandId) async {}

  @override
  Future<IslandModel> addFragments(int islandId, List<int> fragmentIds) =>
      throw UnimplementedError();

  @override
  List<IslandModel> computeIslandsFromFragments(List<Fragment> fragments) =>
      const [];

  @override
  Future<IslandModel?> getIsland(String name) async => null;

  @override
  Future<List<IslandModel>> listIslands(
          {List<Fragment>? cachedFragments}) async =>
      const [];

  @override
  Future<List<Fragment>> listIslandFragments(String name,
          {int? islandId}) async =>
      const [];

  @override
  Future<IslandModel> removeFragments(int islandId, List<int> fragmentIds) =>
      throw UnimplementedError();

  @override
  Future<List<IslandModel>?> tryListRemoteIslands() async => const [];
}
