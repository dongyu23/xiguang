import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../fragment/application/fragment_list_controller.dart';
import '../../fragment/domain/fragment.dart';
import '../../relation/domain/relation.dart';
import '../domain/island_model.dart';
import '../domain/universe_overview.dart';
import 'island_providers.dart';

final universeOverviewProvider = FutureProvider<UniverseOverview>((ref) async {
  final fragments = await ref.watch(fragmentsProvider.future);
  final islandRepository = ref.watch(islandRepositoryProvider);
  final relationRepository = ref.watch(relationRepositoryProvider);

  final results = await Future.wait([
    islandRepository.listIslands(cachedFragments: fragments),
    relationRepository.list(),
  ]);
  final islands = results[0] as List<IslandModel>;
  final relations = results[1] as List<Relation>;

  final visualIslands = await Future.wait(
    islands.map((island) async {
      final tagged = fragments
          .where((fragment) => fragment.tags.contains(island.name))
          .toList();
      if (tagged.isNotEmpty && tagged.length == island.fragmentCount) {
        return IslandVisualNode(island: island, fragments: tagged);
      }
      try {
        final exact = await islandRepository.listIslandFragments(
          island.name,
          islandId: island.islandId,
        );
        return IslandVisualNode(island: island, fragments: exact);
      } catch (_) {
        return IslandVisualNode(
          island: island,
          fragments: tagged.isNotEmpty ? tagged : const [],
        );
      }
    }),
  );

  return UniverseOverview(
    islands: visualIslands,
    branches: buildBranchVisualSummaries(relations, fragments),
    fragments: fragments,
    relations: relations,
  );
});

final universeActionsProvider = Provider<UniverseActions>((ref) {
  return UniverseActions(ref);
});

class UniverseActions {
  const UniverseActions(this._ref);

  final Ref _ref;

  Future<void> deleteIsland(int islandId) async {
    await _ref.read(islandRepositoryProvider).deleteIsland(islandId);
    _ref.invalidate(universeOverviewProvider);
    _ref.invalidate(islandsProvider);
  }
}

List<BranchVisualSummary> buildBranchVisualSummaries(
  List<Relation> relations,
  List<Fragment> fragments,
) {
  if (relations.isEmpty) return const [];
  final fragmentsById = {
    for (final fragment in fragments) fragment.id: fragment
  };
  final adjacency = <int, Set<int>>{};
  for (final relation in relations) {
    adjacency
        .putIfAbsent(relation.sourceFragmentId, () => <int>{})
        .add(relation.targetFragmentId);
    adjacency
        .putIfAbsent(relation.targetFragmentId, () => <int>{})
        .add(relation.sourceFragmentId);
  }

  final visited = <int>{};
  final branches = <BranchVisualSummary>[];
  for (final root in adjacency.keys) {
    if (!visited.add(root)) continue;
    final queue = <int>[root];
    final component = <int>{root};
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final next in adjacency[current] ?? const <int>{}) {
        if (visited.add(next)) {
          component.add(next);
          queue.add(next);
        }
      }
    }

    final branchFragments = component
        .map((id) => fragmentsById[id])
        .whereType<Fragment>()
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (branchFragments.isEmpty) continue;
    final componentRelations = relations
        .where((relation) =>
            component.contains(relation.sourceFragmentId) &&
            component.contains(relation.targetFragmentId))
        .toList();
    final stableParts = componentRelations
        .map((relation) => relation.publicId.isEmpty
            ? '${relation.sourceFragmentId}-${relation.targetFragmentId}'
            : relation.publicId)
        .toList()
      ..sort();
    final note = componentRelations
        .map((relation) => relation.note?.trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final seedTitle = branchFragments.first.title.replaceAll('\n', ' ').trim();
    branches.add(BranchVisualSummary(
      publicId: stableParts.join('|'),
      name: note.isNotEmpty
          ? note.split('\n').first
          : seedTitle.isEmpty
              ? '未命名支线'
              : '关于「$seedTitle」',
      fragments: branchFragments,
      edges: componentRelations
          .map((relation) => BranchVisualEdge(
                relation: relation,
                direction: _directionFor(relation.relationType),
              ))
          .toList(),
    ));
  }
  branches.sort((a, b) {
    final aTime = a.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  });
  return branches;
}

RelationDirection _directionFor(String relationType) {
  return switch (relationType) {
    'same_phase' || 'reminds_me' || 'custom' => RelationDirection.bidirectional,
    _ => RelationDirection.forward,
  };
}
