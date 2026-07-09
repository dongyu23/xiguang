import '../../domain/fragment.dart';

/// Maps transport and local persistence values to the single Fragment entity.
///
/// The API and SQLite use snake_case strings, while the domain keeps an enum.
/// Keeping that conversion here prevents UI and repository callers from
/// depending on either persistence representation.
class FragmentMapper {
  FragmentMapper._();

  static Fragment fromApi(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
    final updatedAt = DateTime.tryParse(json['updated_at'] as String? ?? '');
    final timestamp = createdAt ?? DateTime.now();
    return Fragment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      publicId: json['public_id'] as String? ?? '',
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      contentText: json['content_text'] as String? ?? '',
      emotion: json['emotion'] as String? ?? '说不清',
      status: statusFromStorage(json['status'] as String? ?? 'twilight'),
      tags: (json['tags'] as List<dynamic>? ??
              json['tag_names'] as List<dynamic>? ??
              const [])
          .map((value) => '$value')
          .toList(),
      mediaUrls: (json['media_urls'] as List<dynamic>? ?? const [])
          .map((value) => '$value')
          .toList(),
      createdAt: timestamp,
      updatedAt: updatedAt ?? timestamp,
    );
  }

  static String statusFromStorage(String value) =>
      value == 'islandCore' ? 'island_core' : value;

  static String statusToStorage(String value) => value;
}
