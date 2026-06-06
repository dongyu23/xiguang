import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../design/tokens/colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../shared/data/api_client.dart';

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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return '${createdAt.month}月${createdAt.day}日';
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

class FragmentRepository {
  FragmentRepository(this._api, this._auth);

  final ApiClient _api;
  final AuthRepository _auth;
  final List<LightFragmentModel> _local = List.of(seedFragments);
  int _localID = 100;

  Future<List<LightFragmentModel>> listFragments() async {
    await _auth.ensureSession();
    if (!_api.hasToken) return List.unmodifiable(_local);
    try {
      final body = await _api.get('/fragments', query: {'limit': 100});
      final items = body['value'] is List
          ? body['value'] as List<dynamic>
          : body['items'] as List<dynamic>? ?? const [];
      final remote = items
          .map((item) =>
              LightFragmentModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return remote.isEmpty ? List.unmodifiable(_local) : remote;
    } catch (_) {
      return List.unmodifiable(_local);
    }
  }

  Future<LightFragmentModel> createFragment({
    required String text,
    required String emotion,
    required List<String> tags,
    List<String> mediaUrls = const [],
  }) async {
    await _auth.ensureSession();
    if (_api.hasToken) {
      try {
        final body = await _api.post('/fragments', {
          'content_text': text,
          'emotion': emotion,
          'tag_names': tags,
          'media_urls': mediaUrls,
          'client_op_id': 'flutter-${DateTime.now().microsecondsSinceEpoch}',
        });
        return LightFragmentModel.fromJson(body);
      } on DioException {
        // Fall through to local capture so the app remains usable during development.
      }
    }
    final local = LightFragmentModel(
      id: _localID++,
      contentText: text,
      emotion: emotion,
      tags: tags,
      mediaUrls: mediaUrls,
      createdAt: DateTime.now(),
      status: tags.length >= 3 ? 'island_core' : 'twilight',
    );
    _local.insert(0, local);
    return local;
  }

  Future<LightFragmentModel?> getFragment(int id) async {
    final local = _local.where((item) => item.id == id).firstOrNull;
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

  Future<void> deleteFragment(int id) async {
    await _auth.ensureSession();
    if (_api.hasToken) {
      try {
        await _api.delete('/fragments/$id');
      } on DioException {
        // Local fallback keeps the app operable while the backend is offline.
      }
    }
    _local.removeWhere((item) => item.id == id);
  }

  Future<void> weave({
    required int sourceFragmentId,
    required int targetFragmentId,
    String relationType = 'reminds_me',
    String? note,
  }) async {
    await _auth.ensureSession();
    if (!_api.hasToken) return;
    try {
      await _api.post('/fragments/$sourceFragmentId/weave', {
        'target_fragment_id': targetFragmentId,
        'relation_type': relationType,
        'note': note?.trim().isNotEmpty == true ? note!.trim() : '从光片详情轻轻织线',
      });
    } on DioException {
      // Weaving is optional context; failing should not interrupt reading.
    }
  }
}

final seedFragments = [
  LightFragmentModel(
    id: 1,
    contentText: '雨声把窗台变得很近\n本来只是想睡前看一眼窗外，结果突然觉得今天没有那么糟。',
    emotion: '平静',
    tags: ['雨天', '失眠', '微光'],
    createdAt: DateTime.now().subtract(const Duration(minutes: 32)),
    status: 'twilight',
  ),
  LightFragmentModel(
    id: 2,
    contentText: '一杯青提茶\n冰块、杯壁上的水珠、路边很亮的橱窗。好像被小小地接住了一下。',
    emotion: '开心',
    tags: ['通勤', '奶茶', '小小救命'],
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    status: 'seed',
  ),
  LightFragmentModel(
    id: 3,
    contentText: '凌晨突然想到的片名\n如果把这段时间剪成一支短片，名字也许叫：慢慢亮起来的房间。',
    emotion: '被击中',
    tags: ['灵感', '电影', '种子'],
    createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
    status: 'stardust',
  ),
];
