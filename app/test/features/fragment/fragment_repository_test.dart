import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/fragment/data/mappers/fragment_mapper.dart';
import 'package:xiguang/features/fragment/domain/fragment.dart';

void main() {
  group('Fragment display data', () {
    test('title truncates long text to 16 chars', () {
      final model = Fragment(
        id: 1,
        contentText: '这是一段超过十六个字的光片内容，需要被截断显示',
        emotion: '平静',
        tags: const [],
        createdAt: DateTime(2024, 6, 15, 10, 30),
        status: 'twilight',
      );
      expect(model.title.length, lessThanOrEqualTo(19)); // 16 + '...'
      expect(model.title, endsWith('...'));
    });

    test('title keeps short text as-is', () {
      final model = Fragment(
        id: 1,
        contentText: '短短的光',
        emotion: '平静',
        tags: const [],
        createdAt: DateTime(2024, 6, 15, 10, 30),
        status: 'twilight',
      );
      expect(model.title, '短短的光');
    });

    test('title uses first line only', () {
      final model = Fragment(
        id: 1,
        contentText: '第一行\n第二行\n第三行',
        emotion: '平静',
        tags: const [],
        createdAt: DateTime(2024, 6, 15, 10, 30),
        status: 'twilight',
      );
      expect(model.title, '第一行');
    });

    test('time formats correctly', () {
      final model = Fragment(
        id: 1,
        contentText: 'test',
        emotion: '平静',
        tags: const [],
        createdAt: DateTime(2024, 6, 15, 9, 5),
        status: 'twilight',
      );
      expect(model.time, '09:05');
    });

    test('dateLabel formats correctly', () {
      final model = Fragment(
        id: 1,
        contentText: 'test',
        emotion: '平静',
        tags: const [],
        createdAt: DateTime(2024, 6, 15),
        status: 'twilight',
      );
      expect(model.dateLabel, '2024年6月15日');
    });

    test('fromJson handles missing fields gracefully', () {
      final model = FragmentMapper.fromApi({});
      expect(model.id, 0);
      expect(model.contentText, '');
      expect(model.emotion, '说不清');
      expect(model.tags, isEmpty);
      expect(model.status, 'twilight');
    });

    test('fromJson parses complete data', () {
      final model = FragmentMapper.fromApi({
        'id': 42,
        'content_text': '今天天气很好',
        'emotion': '开心',
        'tags': ['天气', '心情'],
        'media_urls': ['users/abc/media/2024/06/img.jpg'],
        'created_at': '2024-06-15T10:30:00Z',
        'status': 'stardust',
      });
      expect(model.id, 42);
      expect(model.contentText, '今天天气很好');
      expect(model.emotion, '开心');
      expect(model.tags, ['天气', '心情']);
      expect(model.mediaUrls, ['users/abc/media/2024/06/img.jpg']);
      expect(model.status, 'stardust');
    });
  });

  group('Fragment (freezed)', () {
    test('creates with defaults', () {
      final now = DateTime.now();
      final fragment = Fragment(
        id: 1,
        createdAt: now,
        updatedAt: now,
      );
      expect(fragment.id, 1);
      expect(fragment.contentText, '');
      expect(fragment.emotion, '说不清');
      expect(fragment.status, 'twilight');
      expect(fragment.tags, isEmpty);
      expect(fragment.mediaUrls, isEmpty);
    });

    test('copyWith works correctly', () {
      final now = DateTime.now();
      final fragment = Fragment(
        id: 1,
        contentText: 'original',
        createdAt: now,
        updatedAt: now,
      );
      final updated = fragment.copyWith(contentText: 'updated');
      expect(updated.contentText, 'updated');
      expect(updated.id, 1); // unchanged
    });

    test('equality works', () {
      final now = DateTime.now();
      final a =
          Fragment(id: 1, contentText: 'test', createdAt: now, updatedAt: now);
      final b =
          Fragment(id: 1, contentText: 'test', createdAt: now, updatedAt: now);
      expect(a, equals(b));
    });

    test('fromJson/toJson roundtrip', () {
      final now = DateTime(2024, 6, 15, 10, 30);
      final fragment = Fragment(
        id: 1,
        publicId: 'abc-123',
        contentText: 'test content',
        emotion: '平静',
        status: 'twilight',
        tags: const ['tag1'],
        mediaUrls: const [],
        createdAt: now,
        updatedAt: now,
      );
      final json = fragment.toJson();
      final restored = Fragment.fromJson(json);
      expect(restored, equals(fragment));
    });
  });
}
