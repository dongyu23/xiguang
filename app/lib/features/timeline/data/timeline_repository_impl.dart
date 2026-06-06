import '../domain/date_group.dart';
import '../domain/timeline_query.dart';
import '../domain/timeline_repository.dart';
import 'timeline_api.dart';
import '../../fragment/domain/fragment.dart';

class TimelineRepositoryImpl implements TimelineRepositoryContract {
  const TimelineRepositoryImpl(this._api);

  final TimelineApi _api;

  @override
  Future<List<DateGroup>> list(TimelineQuery query) async {
    final body = await _api.list(query);
    final groups = body['groups'] as List<dynamic>? ?? const [];
    return groups
        .map((item) => _dateGroupFromJson(item as Map<String, dynamic>))
        .toList();
  }

  DateGroup _dateGroupFromJson(Map<String, dynamic> json) {
    final fragments = (json['fragments'] as List<dynamic>? ?? const [])
        .map((item) => _fragmentFromJson(item as Map<String, dynamic>))
        .toList();
    return DateGroup(
      dateLabel: json['label'] as String? ?? '',
      fragments: fragments,
      emotionDots: fragments
          .map((fragment) => fragment.emotion ?? '说不清')
          .toSet()
          .toList(),
    );
  }

  Fragment _fragmentFromJson(Map<String, dynamic> json) {
    return Fragment(
      id: json['id'] as int? ?? 0,
      publicId: json['public_id'] as String? ?? '',
      userId: json['user_id'] as int? ?? 0,
      contentText: json['content_text'] as String? ?? '',
      emotion: json['emotion'] as String? ?? '说不清',
      status: _statusFromJson(json['status'] as String?),
      mediaUrls: (json['media_urls'] as List<dynamic>? ?? const [])
          .map((value) => '$value')
          .toList(),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((value) => '$value')
          .toList(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  FragmentStatus _statusFromJson(String? value) {
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
