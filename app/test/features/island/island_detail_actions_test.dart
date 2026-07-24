import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/fragment/domain/fragment.dart';
import 'package:xiguang/features/island/application/island_detail_controller.dart';
import 'package:xiguang/features/island/application/island_providers.dart';
import 'package:xiguang/features/island/application/universe_overview_provider.dart';
import 'package:xiguang/features/island/domain/island_model.dart';
import 'package:xiguang/features/island/domain/island_repository.dart';
import 'package:xiguang/features/island/domain/universe_overview.dart';

void main() {
  test(
      'removing a member keeps the light and deleting an island uses island id',
      () async {
    final fragment = Fragment(
      id: 42,
      publicId: 'fragment-42',
      contentText: '仍然保留的光',
      createdAt: DateTime.utc(2026, 7, 14),
    );
    const island = IslandModel(
      islandId: 7,
      name: '手动小岛',
      status: 'star_point',
      fragmentCount: 1,
      description: '',
      manual: true,
    );
    final repository = _FakeIslandRepository(fragment);
    final container = ProviderContainer(overrides: [
      islandRepositoryProvider.overrideWithValue(repository),
      islandsProvider.overrideWith(_FakeIslandsNotifier.new),
      universeOverviewProvider.overrideWith((ref) async => UniverseOverview(
            islands: [
              IslandVisualNode(island: island, fragments: [fragment]),
            ],
            branches: const [],
            fragments: [fragment],
            relations: const [],
          )),
    ]);
    addTearDown(container.dispose);

    await container.read(islandDetailProvider('7').future);
    final updated = await container
        .read(islandDetailProvider('7').notifier)
        .removeFragments([fragment.id]);

    expect(repository.removedFragmentIds, [42]);
    expect(updated.fragments, isEmpty);
    expect(repository.fragmentStillExists, isTrue);

    await container.read(islandDetailProvider('7').notifier).deleteIsland();
    expect(repository.deletedIslandId, 7);
    expect(repository.fragmentStillExists, isTrue);
  });
}

class _FakeIslandsNotifier extends IslandsNotifier {
  @override
  Future<List<IslandModel>> build() async => const [];
}

class _FakeIslandRepository implements IslandRepositoryPort {
  _FakeIslandRepository(this.fragment);

  final Fragment fragment;
  List<int> removedFragmentIds = const [];
  int? deletedIslandId;
  bool fragmentStillExists = true;

  @override
  Future<IslandModel> removeFragments(
    int islandId,
    List<int> fragmentIds,
  ) async {
    removedFragmentIds = [...fragmentIds];
    return const IslandModel(
      islandId: 7,
      name: '手动小岛',
      status: 'star_point',
      fragmentCount: 0,
      description: '',
      manual: true,
    );
  }

  @override
  Future<void> deleteIsland(int islandId) async {
    deletedIslandId = islandId;
  }

  @override
  Future<List<Fragment>> listIslandFragments(
    String name, {
    int? islandId,
  }) async =>
      removedFragmentIds.isEmpty ? [fragment] : const [];

  @override
  Future<IslandModel> addFragments(int islandId, List<int> fragmentIds) =>
      throw UnimplementedError();

  @override
  List<IslandModel> computeIslandsFromFragments(List<Fragment> fragments) =>
      const [];

  @override
  Future<IslandModel> createIsland(String name, String description) =>
      throw UnimplementedError();

  @override
  Future<IslandModel?> getIsland(String name) async => const IslandModel(
        islandId: 7,
        name: '手动小岛',
        status: 'star_point',
        fragmentCount: 1,
        description: '',
        manual: true,
      );

  @override
  Future<List<IslandModel>> listIslands(
          {List<Fragment>? cachedFragments}) async =>
      const [];

  @override
  Future<List<IslandModel>?> tryListRemoteIslands() async => const [];
}
