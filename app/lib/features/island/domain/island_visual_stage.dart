import 'universe_overview.dart';

enum IslandVisualStage {
  shoal,
  sprouting,
  growing,
  formed,
  dormant,
  relit,
}

extension IslandVisualStageX on IslandVisualNode {
  IslandVisualStage get visualStage {
    return switch (island.status) {
      'dormant' => IslandVisualStage.dormant,
      'relit' => IslandVisualStage.relit,
      'formed' => IslandVisualStage.formed,
      'growing' => IslandVisualStage.growing,
      _ when fragmentCount == 0 => IslandVisualStage.shoal,
      _ => IslandVisualStage.sprouting,
    };
  }

  String get visualKey =>
      island.islandId > 0 ? 'island-${island.islandId}' : 'name-${island.name}';

  int get visualFamily => island.islandId > 0
      ? (island.islandId - 1) % 6
      : _stableHash(visualKey) % 6;
}

int islandStageRank(IslandVisualStage stage) {
  return switch (stage) {
    IslandVisualStage.shoal => 0,
    IslandVisualStage.sprouting => 1,
    IslandVisualStage.growing => 2,
    IslandVisualStage.formed => 3,
    IslandVisualStage.dormant => 3,
    IslandVisualStage.relit => 4,
  };
}

int _stableHash(String value) {
  var hash = 0x811C9DC5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}
