import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../design/tokens/colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../relation/domain/relation.dart';
import '../../shared/data/api_client.dart';
import '../../shared/data/local/app_database.dart' hide Fragment;
import '../domain/create_params.dart';
import '../domain/fragment.dart';
import '../domain/fragment_repository.dart';
import 'local/fragment_local_ds.dart';

/// 游标分页结果
class CursorPage<T> {
  const CursorPage({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
}

class LocalDraftException implements Exception {
  const LocalDraftException(this.fragment);

  final LightFragmentModel fragment;
}

class LightFragmentModel {
  const LightFragmentModel({
    required this.id,
    required this.contentText,
    required this.emotion,
    required this.tags,
    required this.createdAt,
    required this.status,
    this.mediaUrls = const [],
  });

  final int id;
  final String contentText;
  final String emotion;
  final List<String> tags;
  final List<String> mediaUrls;
  final DateTime createdAt;
  final String status;

  String get title {
    final firstLine = contentText.trim().split('\n').first;
    if (firstLine.length <= 16) return firstLine;
    return '${firstLine.substring(0, 16)}...';
  }

  String get time {
    final local = createdAt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String get dateLabel {
    final local = createdAt.toLocal();
    return '${local.year}年${local.month}月${local.day}日';
  }

  Color get color => AppColors.emotionColor(emotion);

  static LightFragmentModel fromJson(Map<String, dynamic> json) {
    return LightFragmentModel(
      id: json['id'] as int? ?? 0,
      contentText: json['content_text'] as String? ?? '',
      emotion: json['emotion'] as String? ?? '说不清',
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((e) => '$e')
          .toList(),
      mediaUrls: (json['media_urls'] as List<dynamic>? ?? const [])
          .map((e) => '$e')
          .toList(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'twilight',
    );
  }
}

/// H7: Active repository now implements the domain contract.
/// This makes FragmentRepositoryImpl (fragment_repository_impl.dart) redundant.
class FragmentRepository implements FragmentRepositoryContract {
  FragmentRepository(this._api, this._auth, {AppDatabase? db}) {
    _localDs = FragmentLocalDataSource(db ?? AppDatabase());
  }

  final ApiClient _api;
  final AuthRepository _auth;
  late final FragmentLocalDataSource _localDs;

  /// 每次本地 fragment 变更（create/update/delete）后调用，供 SyncEngine 入队 OpLog
  void Function(String entityType, String opType, int fragmentId,
      Map<String, dynamic> payload)? onFragmentChanged;

  Future<List<LightFragmentModel>> listFragments() async {
    final authSession = _auth.currentSession;
    if (authSession == null) {
      await _auth.restoreSession();
    }
    if (!_api.hasToken) return _localDs.getAll();
    try {
      final body = await _api.get('/fragments', query: {'limit': 100});
      final items = body['value'] is List
          ? body['value'] as List<dynamic>
          : body['items'] as List<dynamic>? ?? const [];
      final remote = items
          .map((item) =>
              LightFragmentModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return remote.isEmpty ? await _localDs.getAll() : remote;
    } catch (e) {
      developer.log('listFragments remote failed, using local', error: e);
      return _localDs.getAll();
    }
  }

  /// 只读取本地缓存，不联网。供本地优先的 provider 在 build 阶段立即拿数据。
  Future<List<LightFragmentModel>> listLocalFragments() => _localDs.getAll();

  /// 只尝试远端，不做本地兜底。失败/无 token 时返回 null，供后台刷新使用。
  Future<List<LightFragmentModel>?> tryListRemoteFragments() async {
    final authSession = _auth.currentSession;
    if (authSession == null) {
      await _auth.restoreSession();
    }
    if (!_api.hasToken) return null;
    try {
      final body = await _api.get('/fragments', query: {'limit': 100});
      final items = body['value'] is List
          ? body['value'] as List<dynamic>
          : body['items'] as List<dynamic>? ?? const [];
      return items
          .map((item) =>
              LightFragmentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('tryListRemoteFragments failed', error: e);
      return null;
    }
  }

  /// 游标分页加载光片 — 支持增量加载
  Future<CursorPage<LightFragmentModel>> listFragmentsPaged({
    String? cursor,
    int limit = 20,
  }) async {
    final authSession = _auth.currentSession;
    if (authSession == null) {
      await _auth.restoreSession();
    }
    if (!_api.hasToken) {
      final all = await _localDs.getAll();
      return CursorPage(items: all, hasMore: false);
    }
    try {
      final query = <String, dynamic>{'limit': limit};
      if (cursor != null && cursor.isNotEmpty) {
        query['cursor'] = cursor;
      }
      final body = await _api.get('/fragments', query: query);
      final items = (body['items'] as List<dynamic>? ?? const [])
          .map((item) =>
              LightFragmentModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return CursorPage(
        items: items,
        nextCursor: body['next_cursor'] as String?,
        hasMore: body['has_more'] as bool? ?? false,
      );
    } catch (e) {
      developer.log('listFragmentsPaged failed', error: e);
      final all = await _localDs.getAll();
      return CursorPage(items: all, hasMore: false);
    }
  }

  Future<LightFragmentModel> createFragment({
    required String text,
    required String emotion,
    required List<String> tags,
    List<String> mediaUrls = const [],
  }) async {
    await _auth.ensureSession();
    if (mediaUrls.isNotEmpty && mediaUrls.any(_isLocalOnlyMedia)) {
      final local = await _createLocalFragment(
        text: text,
        emotion: emotion,
        tags: tags,
        mediaUrls: mediaUrls,
      );
      throw LocalDraftException(local);
    }
    if (_api.hasToken) {
      final body = await _api.post('/fragments', {
        'content_text': text,
        'emotion': emotion,
        'tag_names': tags,
        'media_urls': mediaUrls,
        'client_op_id': 'flutter-${DateTime.now().microsecondsSinceEpoch}',
      });
      // INSERT 已通过 REST API 写入服务端，不需要再入队 sync
      return LightFragmentModel.fromJson(body);
    }
    // 离线创建：入队 OpLog，联网后通过 sync push 到服务端
    final local = await _createLocalFragment(
      text: text,
      emotion: emotion,
      tags: tags,
      mediaUrls: mediaUrls,
    );
    onFragmentChanged?.call('fragment', 'INSERT', local.id, {
      'content_text': text,
      'emotion': emotion,
      'tag_names': tags,
      'media_urls': mediaUrls,
    });
    return local;
  }

  Future<LightFragmentModel> _createLocalFragment({
    required String text,
    required String emotion,
    required List<String> tags,
    required List<String> mediaUrls,
  }) async {
    final now = DateTime.now();
    final model = LightFragmentModel(
      id: 0, // DB will assign
      contentText: text,
      emotion: emotion,
      tags: tags,
      mediaUrls: mediaUrls,
      createdAt: now,
      status: tags.length >= 3 ? 'island_core' : 'twilight',
    );
    final dbId = await _localDs.insert(model);
    return LightFragmentModel(
      id: dbId,
      contentText: text,
      emotion: emotion,
      tags: tags,
      mediaUrls: mediaUrls,
      createdAt: now,
      status: tags.length >= 3 ? 'island_core' : 'twilight',
    );
  }

  bool _isLocalOnlyMedia(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('data:image/')) return false;
    if (trimmed.startsWith('data:audio/')) return false;
    return !trimmed.startsWith('users/') ||
        trimmed.startsWith('/') ||
        trimmed.startsWith('file:') ||
        trimmed.contains('\\');
  }

  Future<LightFragmentModel?> getFragment(int id) async {
    final local = await _localDs.getById(id);
    await _auth.ensureSession();
    if (_api.hasToken) {
      try {
        final body = await _api.get('/fragments/$id');
        return LightFragmentModel.fromJson(body);
      } on DioException {
        return local;
      }
    }
    return local;
  }

  Future<void> updateFragmentText(
    int id,
    String newText, {
    String emotion = '说不清',
    List<String> tags = const [],
    List<String>? mediaUrls,
  }) async {
    await _auth.ensureSession();
    final local = await _localDs.getById(id);
    if (_api.hasToken) {
      final payload = {
        'content_text': newText,
        'emotion': emotion,
        'tag_names': tags,
        if (mediaUrls != null) 'media_urls': mediaUrls,
      };
      final body = await _api.put('/fragments/$id', payload);
      final updated = LightFragmentModel.fromJson(body);
      await _localDs.update(updated);
      onFragmentChanged?.call('fragment', 'UPDATE', id, payload);
      return;
    }
    if (local != null) {
      await _localDs.update(LightFragmentModel(
        id: local.id,
        contentText: newText,
        emotion: emotion,
        tags: tags,
        createdAt: local.createdAt,
        status: local.status,
        mediaUrls: mediaUrls ?? local.mediaUrls,
      ));
    }
  }

  Future<void> deleteFragment(int id) async {
    await _auth.ensureSession();
    if (_api.hasToken) {
      try {
        await _api.delete('/fragments/$id');
        onFragmentChanged?.call('fragment', 'DELETE', id, {'id': id});
      } on DioException {
        // Local fallback keeps the app operable while the backend is offline.
      }
    }
    await _localDs.delete(id);
  }

  Future<Relation?> weave({
    required int sourceFragmentId,
    required int targetFragmentId,
    String relationType = 'reminds_me',
    String? note,
  }) async {
    await _auth.ensureSession();
    if (!_api.hasToken) return null;
    try {
      final body = await _api.post('/fragments/$sourceFragmentId/weave', {
        'target_fragment_id': targetFragmentId,
        'relation_type': relationType,
        'note': note?.trim().isNotEmpty == true ? note!.trim() : '从光片详情轻轻织线',
      });
      return Relation(
        id: body['id'] as int? ?? 0,
        publicId: body['public_id'] as String? ?? '',
        userId: body['user_id'] as int? ?? 0,
        sourceFragmentId:
            body['source_fragment_id'] as int? ?? sourceFragmentId,
        targetFragmentId:
            body['target_fragment_id'] as int? ?? targetFragmentId,
        relationType: body['relation_type'] as String? ?? relationType,
        note: body['note'] as String?,
      );
    } on DioException {
      // Weaving is optional context; failing should not interrupt reading.
      return null;
    }
  }

  // ── H7: FragmentRepositoryContract interface adapters ──

  @override
  Future<List<Fragment>> list() async {
    final models = await listFragments();
    return models.map(_toFragment).toList();
  }

  @override
  Future<Fragment?> getById(int id) async {
    final model = await getFragment(id);
    return model != null ? _toFragment(model) : null;
  }

  @override
  Future<Fragment> create(CreateFragmentParams params) async {
    final model = await createFragment(
      text: params.contentText,
      emotion: params.emotion,
      tags: params.tagNames,
    );
    return _toFragment(model);
  }

  @override
  Future<Fragment> update(Fragment fragment) async {
    await updateFragmentText(
      fragment.id,
      fragment.contentText,
      emotion: fragment.emotion ?? '说不清',
      tags: fragment.tags,
    );
    return fragment;
  }

  @override
  Future<void> delete(int id) => deleteFragment(id);

  Fragment _toFragment(LightFragmentModel m) => Fragment(
        id: m.id,
        publicId: '',
        userId: 0,
        contentText: m.contentText,
        emotion: m.emotion,
        status: _statusFromText(m.status),
        mediaUrls: m.mediaUrls,
        tags: m.tags,
        createdAt: m.createdAt,
        updatedAt: m.createdAt,
      );

  static FragmentStatus _statusFromText(String value) {
    return switch (value) {
      'stardust' => FragmentStatus.stardust,
      'echo' => FragmentStatus.echo,
      'seed' => FragmentStatus.seed,
      'tide' => FragmentStatus.tide,
      'island_core' => FragmentStatus.islandCore,
      _ => FragmentStatus.twilight,
    };
  }
}
