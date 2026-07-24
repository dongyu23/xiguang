import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../shared/data/local/app_database.dart' as local_db;
import '../../domain/fragment.dart';
import '../mappers/fragment_mapper.dart';

/// 本地数据源 — 封装 drift DAO，供 FragmentRepository 离线模式使用
class FragmentLocalDataSource {
  FragmentLocalDataSource(this._db);

  final local_db.AppDatabase _db;

  Future<List<Fragment>> getAll() async {
    final rows = await _db.getAllFragments();
    return rows.map(_toModel).toList();
  }

  Future<List<Fragment>> search(String query) async {
    final rows = await _db.searchFragments(query);
    return rows.map(_toModel).toList();
  }

  Future<List<Fragment>> getDeleted() async {
    final rows = await _db.getDeletedFragments();
    return rows.map(_toModel).toList();
  }

  Future<Fragment?> getById(int id) async {
    final row = await _db.getFragmentById(id);
    return row == null ? null : _toModel(row);
  }

  Future<int> insert(Fragment fragment) async {
    return _db.insertFragment(local_db.FragmentsCompanion.insert(
      contentText: Value(fragment.contentText),
      emotion: Value(fragment.emotion),
      status: Value(FragmentMapper.statusToStorage(fragment.status)),
      tags: Value(jsonEncode(fragment.tags)),
      mediaUrls: Value(jsonEncode(fragment.mediaUrls)),
      createdAt: Value(fragment.createdAt),
      updatedAt: Value(fragment.updatedAt ?? fragment.createdAt),
      publicId: Value(fragment.publicId),
    ));
  }

  /// 在线 REST 写入成功后的本地镜像。相同服务端 id 重复写入时覆盖旧缓存。
  Future<void> mirrorInsert(Fragment fragment) async {
    await _db.into(_db.fragments).insert(
          local_db.FragmentsCompanion.insert(
            id: Value(fragment.id),
            publicId: Value(fragment.publicId),
            contentText: Value(fragment.contentText),
            emotion: Value(fragment.emotion),
            status: Value(FragmentMapper.statusToStorage(fragment.status)),
            tags: Value(jsonEncode(fragment.tags)),
            mediaUrls: Value(jsonEncode(fragment.mediaUrls)),
            createdAt: Value(fragment.createdAt),
            updatedAt: Value(fragment.updatedAt ?? fragment.createdAt),
            isSynced: const Value(true),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> update(Fragment fragment) async {
    await _db.updateFragment(local_db.FragmentsCompanion(
      id: Value(fragment.id),
      publicId: Value(fragment.publicId),
      contentText: Value(fragment.contentText),
      emotion: Value(fragment.emotion),
      status: Value(FragmentMapper.statusToStorage(fragment.status)),
      tags: Value(jsonEncode(fragment.tags)),
      mediaUrls: Value(jsonEncode(fragment.mediaUrls)),
      createdAt: Value(fragment.createdAt),
      updatedAt: Value(fragment.updatedAt ?? fragment.createdAt),
    ));
  }

  Future<void> delete(int id) async {
    await _db.deleteFragment(id);
  }

  Future<void> restore(int id) async {
    await _db.restoreFragment(id);
  }

  Future<void> permanentlyDelete(int id) async {
    await _db.permanentlyDeleteFragment(id);
  }

  Fragment _toModel(local_db.Fragment row) {
    return Fragment(
      id: row.id,
      publicId: row.publicId,
      contentText: row.contentText,
      emotion: row.emotion,
      tags: _decodeJsonList(row.tags),
      mediaUrls: _decodeJsonList(row.mediaUrls),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt ?? row.createdAt,
      status: FragmentMapper.statusFromStorage(row.status),
    );
  }

  List<String> _decodeJsonList(String json) {
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => '$e').toList();
    } catch (_) {
      return const [];
    }
  }
}
