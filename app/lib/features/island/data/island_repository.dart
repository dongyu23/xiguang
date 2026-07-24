import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../auth/domain/auth_repository.dart';
import '../../fragment/data/mappers/fragment_mapper.dart';
import '../../fragment/domain/fragment.dart';
import '../../fragment/domain/fragment_repository.dart';
import '../../shared/data/api_client.dart';
import '../../shared/data/local/app_database.dart' hide Fragment;
import '../domain/island_model.dart';
import '../domain/island_repository.dart';
import 'mappers/island_mapper.dart';

class IslandRepository implements IslandRepositoryPort {
  IslandRepository(this._api, this._auth, this._fragments, this._db);

  final ApiClient _api;
  final AuthRepositoryContract _auth;
  final FragmentRepositoryContract _fragments;
  final AppDatabase _db;

  @override
  Future<List<IslandModel>> listIslands(
      {List<Fragment>? cachedFragments}) async {
    await _auth.ensureSession();
    if (_api.hasToken) {
      try {
        final body = await _api.get('/islands');
        final items = body['islands'] as List<dynamic>? ?? const [];
        final remote = items
            .map((item) => IslandMapper.fromApi(item as Map<String, dynamic>))
            .toList();
        if (remote.isNotEmpty) {
          await _mirrorIslands(remote);
          return remote;
        }
      } catch (e) {
        developer.log('listIslands remote failed, using local rules', error: e);
      }
    }
    final fragments = cachedFragments ?? await _fragments.listFragments();
    return computeIslandsFromFragments(fragments);
  }

  /// 仅尝试远端 /islands，失败/无 token 返回 null。供本地优先 provider 后台刷新。
  @override
  Future<List<IslandModel>?> tryListRemoteIslands() async {
    if (_auth.currentSession == null) {
      await _auth.restoreSession();
    }
    if (!_api.hasToken) return null;
    try {
      final body = await _api.get('/islands');
      final items = body['islands'] as List<dynamic>? ?? const [];
      final remote = items
          .map((item) => IslandMapper.fromApi(item as Map<String, dynamic>))
          .toList();
      await _mirrorIslands(remote);
      return remote;
    } catch (e) {
      developer.log('tryListRemoteIslands failed', error: e);
      return null;
    }
  }

  /// 从本地光片按标签出现次数推导主题岛。无网或新装时首屏就有内容可显示。
  @override
  List<IslandModel> computeIslandsFromFragments(
    List<Fragment> fragments,
  ) {
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

  @override
  Future<IslandModel?> getIsland(String name) async {
    await _auth.ensureSession();
    if (_api.hasToken) {
      try {
        final body = await _api.get('/islands/${Uri.encodeComponent(name)}');
        return IslandMapper.fromApi(body);
      } catch (e) {
        developer.log('getIsland remote failed, using local', error: e);
      }
    }
    final items = await listIslands();
    return items.where((item) => item.name == name).firstOrNull;
  }

  @override
  Future<IslandModel> createIsland(String name, String description) async {
    await _auth.ensureSession();
    final body = await _api.post('/islands', {
      'name': name,
      'description': description,
    });
    final island = IslandMapper.fromApi(body);
    await _mirrorIslands([island]);
    return island;
  }

  @override
  Future<void> deleteIsland(int islandId) async {
    await _auth.ensureSession();
    await _api.delete('/islands/$islandId');
    final local = await (_db.select(_db.localIslands)
          ..where((table) => table.serverId.equals(islandId)))
        .getSingleOrNull();
    if (local == null) return;
    await _db.transaction(() async {
      await (_db.delete(_db.localIslandMembers)
            ..where(
              (table) => table.islandPublicId.equals(local.publicId),
            ))
          .go();
      await (_db.delete(_db.localIslands)
            ..where((table) => table.publicId.equals(local.publicId)))
          .go();
    });
  }

  @override
  Future<IslandModel> addFragments(int islandId, List<int> fragmentIds) async {
    await _auth.ensureSession();
    try {
      final body = await _api.post('/islands/$islandId/fragments', {
        'fragment_ids': fragmentIds,
      });
      final island = IslandMapper.fromApi(body);
      await _mirrorIslands([island]);
      await _mirrorMembers(islandId, fragmentIds, remove: false);
      return island;
    } on DioException catch (error) {
      if (_apiErrorCode(error) == 'island_not_manual') {
        throw const IslandNotManualException();
      }
      rethrow;
    }
  }

  @override
  Future<IslandModel> removeFragments(
      int islandId, List<int> fragmentIds) async {
    await _auth.ensureSession();
    try {
      final body = await _api.delete('/islands/$islandId/fragments',
          body: {'fragment_ids': fragmentIds});
      final island = IslandMapper.fromApi(body);
      await _mirrorIslands([island]);
      await _mirrorMembers(islandId, fragmentIds, remove: true);
      return island;
    } on DioException catch (error) {
      if (_apiErrorCode(error) == 'island_not_manual') {
        throw const IslandNotManualException();
      }
      rethrow;
    }
  }

  @override
  Future<List<Fragment>> listIslandFragments(
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
        final remote = items
            .map((item) => FragmentMapper.fromApi(item as Map<String, dynamic>))
            .toList();
        if (islandId != null) {
          await _replaceMembers(islandId, remote);
        }
        return remote;
      } catch (e) {
        developer.log('listIslandFragments remote failed, using local tags',
            error: e);
      }
    }
    final fragments = await _fragments.listFragments();
    return fragments.where((fragment) => fragment.tags.contains(name)).toList();
  }

  Future<void> _mirrorIslands(List<IslandModel> islands) async {
    for (final island in islands) {
      if (island.islandId <= 0) continue;
      final existing = await (_db.select(_db.localIslands)
            ..where((table) => table.serverId.equals(island.islandId)))
          .getSingleOrNull();
      final publicId = existing?.publicId ??
          const Uuid()
              .v5(Namespace.url.value, 'xiguang:island:${island.islandId}');
      await _db.into(_db.localIslands).insert(
            LocalIslandsCompanion.insert(
              serverId: Value(island.islandId),
              publicId: publicId,
              name: island.name,
              description: Value(island.description),
              status: Value(island.status),
              isManual: Value(island.manual),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  Future<void> _mirrorMembers(int islandId, List<int> fragmentIds,
      {required bool remove}) async {
    final island = await (_db.select(_db.localIslands)
          ..where((table) => table.serverId.equals(islandId)))
        .getSingleOrNull();
    if (island == null) return;
    for (final id in fragmentIds) {
      final fragment = await _db.getFragmentById(id);
      if (fragment == null) continue;
      final predicate =
          _db.localIslandMembers.islandPublicId.equals(island.publicId) &
              _db.localIslandMembers.fragmentPublicId.equals(fragment.publicId);
      if (remove) {
        await (_db.delete(_db.localIslandMembers)..where((_) => predicate))
            .go();
      } else {
        await _db.into(_db.localIslandMembers).insert(
              LocalIslandMembersCompanion.insert(
                islandPublicId: island.publicId,
                fragmentPublicId: fragment.publicId,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    }
  }

  Future<void> _replaceMembers(int islandId, List<Fragment> fragments) async {
    final island = await (_db.select(_db.localIslands)
          ..where((table) => table.serverId.equals(islandId)))
        .getSingleOrNull();
    if (island == null || !island.isManual) return;
    await (_db.delete(_db.localIslandMembers)
          ..where((table) => table.islandPublicId.equals(island.publicId)))
        .go();
    for (final fragment in fragments) {
      if (fragment.publicId.isEmpty) continue;
      await _db.into(_db.localIslandMembers).insert(
            LocalIslandMembersCompanion.insert(
              islandPublicId: island.publicId,
              fragmentPublicId: fragment.publicId,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }
}

String? _apiErrorCode(DioException error) {
  final apiError = error.error;
  if (apiError is Map && apiError['code'] is String) {
    return apiError['code'] as String;
  }
  final responseData = error.response?.data;
  if (responseData is Map) {
    final nested = responseData['error'];
    if (nested is Map && nested['code'] is String) {
      return nested['code'] as String;
    }
  }
  return null;
}
