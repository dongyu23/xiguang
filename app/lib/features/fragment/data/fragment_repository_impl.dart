import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../../auth/domain/auth_repository.dart';
import '../../relation/domain/relation.dart';
import '../../shared/data/api_client.dart';
import '../../shared/data/local/app_database.dart' hide Fragment;
import '../domain/create_params.dart';
import '../domain/fragment.dart';
import '../domain/fragment_repository.dart';
import 'local/fragment_local_ds.dart';
import 'mappers/fragment_mapper.dart';

export '../domain/fragment.dart';

/// H7: Active repository now implements the domain contract.
/// This makes FragmentRepositoryImpl (fragment_repository_impl.dart) redundant.
class FragmentRepositoryImpl implements FragmentRepositoryContract {
  FragmentRepositoryImpl(this._api, this._auth, {AppDatabase? db}) {
    _localDs = FragmentLocalDataSource(db ?? AppDatabase());
  }

  final ApiClient _api;
  final AuthRepositoryContract _auth;
  late final FragmentLocalDataSource _localDs;

  /// 每次本地 fragment 变更（create/update/delete）后调用，供 SyncEngine 入队 OpLog
  @override
  FragmentChangedCallback? onFragmentChanged;

  @override
  Future<List<Fragment>> listFragments() async {
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
          .map((item) => FragmentMapper.fromApi(item as Map<String, dynamic>))
          .toList();
      return remote.isEmpty ? await _localDs.getAll() : remote;
    } catch (e) {
      developer.log('listFragments remote failed, using local', error: e);
      return _localDs.getAll();
    }
  }

  /// 只读取本地缓存，不联网。供本地优先的 provider 在 build 阶段立即拿数据。
  @override
  Future<List<Fragment>> listLocalFragments() => _localDs.getAll();

  /// 只尝试远端，不做本地兜底。失败/无 token 时返回 null，供后台刷新使用。
  @override
  Future<List<Fragment>?> tryListRemoteFragments() async {
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
          .map((item) => FragmentMapper.fromApi(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('tryListRemoteFragments failed', error: e);
      return null;
    }
  }

  /// 游标分页加载光片 — 支持增量加载
  @override
  Future<CursorPage<Fragment>> listFragmentsPaged({
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
          .map((item) => FragmentMapper.fromApi(item as Map<String, dynamic>))
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

  @override
  Future<Fragment> createFragment({
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
      final created = FragmentMapper.fromApi(body);
      await _localDs.mirrorInsert(created);
      return created;
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

  Future<Fragment> _createLocalFragment({
    required String text,
    required String emotion,
    required List<String> tags,
    required List<String> mediaUrls,
  }) async {
    final now = DateTime.now();
    final model = Fragment(
      id: 0, // DB will assign
      publicId: '',
      userId: 0,
      contentText: text,
      emotion: emotion,
      tags: tags,
      mediaUrls: mediaUrls,
      createdAt: now,
      updatedAt: now,
      status: tags.length >= 3 ? 'island_core' : 'twilight',
    );
    final dbId = await _localDs.insert(model);
    return Fragment(
      id: dbId,
      publicId: '',
      userId: 0,
      contentText: text,
      emotion: emotion,
      tags: tags,
      mediaUrls: mediaUrls,
      createdAt: now,
      updatedAt: now,
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

  @override
  Future<Fragment?> getFragment(int id) async {
    final local = await _localDs.getById(id);
    await _auth.ensureSession();
    if (_api.hasToken) {
      try {
        final body = await _api.get('/fragments/$id');
        return FragmentMapper.fromApi(body);
      } on DioException {
        return local;
      }
    }
    return local;
  }

  @override
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
      final updated = FragmentMapper.fromApi(body);
      await _localDs.mirrorInsert(updated);
      return;
    }
    if (local != null) {
      await _localDs.update(Fragment(
        id: local.id,
        publicId: local.publicId,
        userId: local.userId,
        contentText: newText,
        emotion: emotion,
        tags: tags,
        createdAt: local.createdAt,
        status: local.status,
        updatedAt: DateTime.now(),
        mediaUrls: mediaUrls ?? local.mediaUrls,
      ));
      onFragmentChanged?.call('fragment', 'UPDATE', id, {
        'content_text': newText,
        'emotion': emotion,
        'tag_names': tags,
        if (mediaUrls != null) 'media_urls': mediaUrls,
        if (local.publicId.isNotEmpty) 'public_id': local.publicId,
      });
    }
  }

  @override
  Future<void> deleteFragment(int id) async {
    await _auth.ensureSession();
    if (_api.hasToken) {
      try {
        await _api.delete('/fragments/$id');
      } on DioException {
        // Local fallback keeps the app operable while the backend is offline.
        final local = await _localDs.getById(id);
        onFragmentChanged?.call('fragment', 'DELETE', id, {
          'id': id,
          if (local?.publicId.isNotEmpty == true) 'public_id': local!.publicId,
        });
      }
    } else {
      final local = await _localDs.getById(id);
      onFragmentChanged?.call('fragment', 'DELETE', id, {
        'id': id,
        if (local?.publicId.isNotEmpty == true) 'public_id': local!.publicId,
      });
    }
    await _localDs.delete(id);
  }

  @override
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
    return listFragments();
  }

  @override
  Future<Fragment?> getById(int id) async {
    return getFragment(id);
  }

  @override
  Future<Fragment> create(CreateFragmentParams params) async {
    return createFragment(
      text: params.contentText,
      emotion: params.emotion,
      tags: params.tagNames,
    );
  }

  @override
  Future<Fragment> update(Fragment fragment) async {
    await updateFragmentText(
      fragment.id,
      fragment.contentText,
      emotion: fragment.emotion,
      tags: fragment.tags,
    );
    return fragment;
  }

  @override
  Future<void> delete(int id) => deleteFragment(id);
}
