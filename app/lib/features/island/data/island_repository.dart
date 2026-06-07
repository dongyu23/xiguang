import '../../auth/data/auth_repository.dart';
import '../../fragment/data/fragment_repository.dart';
import '../../shared/data/api_client.dart';

class IslandModel {
  const IslandModel({
    required this.name,
    this.islandId = 0,
    required this.status,
    required this.fragmentCount,
    required this.description,
    this.manual = false,
  });

  final String name;
  final int islandId;
  final String status;
  final int fragmentCount;
  final String description;
  final bool manual;

  static IslandModel fromJson(Map<String, dynamic> json) {
    return IslandModel(
      name: json['name'] as String? ?? '未命名小岛',
      islandId: (json['island_id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'star_point',
      fragmentCount: json['fragment_count'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      manual: json['manual'] as bool? ?? false,
    );
  }
}

class IslandRepository {
  IslandRepository(this._api, this._auth, this._fragments);

  final ApiClient _api;
  final AuthRepository _auth;
  final FragmentRepository _fragments;

  Future<List<IslandModel>> listIslands() async {
    await _auth.ensureSession();
    if (_api.hasToken) {
      try {
        final body = await _api.get('/islands');
        final items = body['islands'] as List<dynamic>? ?? const [];
        final remote = items
            .map((item) => IslandModel.fromJson(item as Map<String, dynamic>))
            .toList();
        if (remote.isNotEmpty) return remote;
      } catch (_) {
        // Use local rule-based islands below.
      }
    }
    final fragments = await _fragments.listFragments();
    final counts = <String, int>{};
    for (final fragment in fragments) {
      for (final tag in fragment.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final islands =
        counts.entries.where((entry) => entry.value >= 3).map((entry) {
      final count = entry.value;
      final String status;
      if (count >= 5) {
        status = 'formed';
      } else if (count >= 4) {
        status = 'growing';
      } else {
        status = 'star_point';
      }
      return IslandModel(
        name: entry.key,
        status: status,
        fragmentCount: count,
        description: status == 'formed' ? '这座小岛已经成形。' : '这个主题星点正在靠近更多旧光。',
      );
    }).toList();
    islands.sort((a, b) => b.fragmentCount.compareTo(a.fragmentCount));
    return islands.take(6).toList();
  }

  Future<IslandModel?> getIsland(String name) async {
    await _auth.ensureSession();
    if (_api.hasToken) {
      try {
        final body = await _api.get('/islands/${Uri.encodeComponent(name)}');
        return IslandModel.fromJson(body);
      } catch (_) {
        // Use local rule-based islands below.
      }
    }
    final items = await listIslands();
    return items.where((item) => item.name == name).firstOrNull;
  }

  Future<IslandModel> createIsland(String name, String description) async {
    await _auth.ensureSession();
    final body = await _api.post('/islands', {
      'name': name,
      'description': description,
    });
    return IslandModel.fromJson(body);
  }

  Future<IslandModel> addFragments(int islandId, List<int> fragmentIds) async {
    await _auth.ensureSession();
    final body = await _api.post('/islands/$islandId/fragments', {
      'fragment_ids': fragmentIds,
    });
    return IslandModel.fromJson(body);
  }

  Future<IslandModel> removeFragments(
      int islandId, List<int> fragmentIds) async {
    await _auth.ensureSession();
    final body = await _api.delete('/islands/$islandId/fragments',
        body: {'fragment_ids': fragmentIds});
    return IslandModel.fromJson(body);
  }

  Future<List<LightFragmentModel>> listIslandFragments(
    String name, {
    int? islandId,
  }) async {
    await _auth.ensureSession();
    if (_api.hasToken) {
      try {
        final idOrName = islandId != null && islandId > 0
            ? '$islandId'
            : Uri.encodeComponent(name);
        final body = await _api.get('/islands/$idOrName/fragments');
        final items = body['fragments'] as List<dynamic>? ?? const [];
        return items
            .map((item) =>
                LightFragmentModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // Use local tag matching below.
      }
    }
    final fragments = await _fragments.listFragments();
    return fragments.where((fragment) => fragment.tags.contains(name)).toList();
  }
}
