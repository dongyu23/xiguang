import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../shared/data/local/app_database.dart';
import '../fragment_repository.dart';

/// 本地数据源 — 封装 drift DAO，供 FragmentRepository 离线模式使用
class FragmentLocalDataSource {
  FragmentLocalDataSource(this._db);

  final AppDatabase _db;

  Future<List<LightFragmentModel>> getAll() async {
    final rows = await _db.getAllFragments();
    return rows.map(_toModel).toList();
  }

  Future<LightFragmentModel?> getById(int id) async {
    final row = await _db.getFragmentById(id);
    return row == null ? null : _toModel(row);
  }

  Future<int> insert(LightFragmentModel fragment) async {
    return _db.insertFragment(FragmentsCompanion.insert(
      contentText: Value(fragment.contentText),
      emotion: Value(fragment.emotion),
      status: Value(fragment.status),
      tags: Value(jsonEncode(fragment.tags)),
      mediaUrls: Value(jsonEncode(fragment.mediaUrls)),
      createdAt: Value(fragment.createdAt),
    ));
  }

  Future<void> update(LightFragmentModel fragment) async {
    await _db.updateFragment(FragmentsCompanion(
      id: Value(fragment.id),
      contentText: Value(fragment.contentText),
      emotion: Value(fragment.emotion),
      status: Value(fragment.status),
      tags: Value(jsonEncode(fragment.tags)),
      mediaUrls: Value(jsonEncode(fragment.mediaUrls)),
    ));
  }

  Future<void> delete(int id) async {
    await _db.deleteFragment(id);
  }

  LightFragmentModel _toModel(Fragment row) {
    return LightFragmentModel(
      id: row.id,
      contentText: row.contentText,
      emotion: row.emotion,
      tags: _decodeJsonList(row.tags),
      mediaUrls: _decodeJsonList(row.mediaUrls),
      createdAt: row.createdAt,
      status: row.status,
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
