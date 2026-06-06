import '../../auth/data/auth_repository.dart';
import '../../fragment/data/fragment_repository.dart';
import '../../shared/data/api_client.dart';

class IslandModel {
  const IslandModel({
    required this.name,
    required this.status,
    required this.fragmentCount,
    required this.description,
  });

  final String name;
  final String status;
  final int fragmentCount;
  final String description;

  static IslandModel fromJson(Map<String, dynamic> json) {
    return IslandModel(
      name: json['name'] as String? ?? '未命名小岛',
      status: json['status'] as String? ?? 'star_point',
      fragmentCount: json['fragment_count'] as int? ?? 0,
      description: json['description'] as String? ?? '',
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
    final islands = counts.entries.map((entry) {
      final formed = entry.value >= 5;
      return IslandModel(
        name: entry.key,
        status: formed ? 'formed' : 'star_point',
        fragmentCount: entry.value,
        description: formed ? '这座小岛已经成形。' : '这个主题星点正在靠近更多旧光。',
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

  Future<List<LightFragmentModel>> listIslandFragments(String name) async {
    await _auth.ensureSession();
    if (_api.hasToken) {
      try {
        final body =
            await _api.get('/islands/${Uri.encodeComponent(name)}/fragments');
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
