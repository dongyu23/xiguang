import 'package:freezed_annotation/freezed_annotation.dart';

part 'fragment.freezed.dart';
part 'fragment.g.dart';

/// Fragment 实体 — "光片"
@freezed
class Fragment with _$Fragment {
  const factory Fragment({
    required int id,
    @Default('') String publicId,
    @Default(0) int userId,
    @Default('') String contentText,
    String? emotion,
    @Default(FragmentStatus.twilight) FragmentStatus status,
    @Default([]) List<String> mediaUrls,
    @Default([]) List<String> tags,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Fragment;

  factory Fragment.fromJson(Map<String, dynamic> json) =>
      _$FragmentFromJson(json);
}

enum FragmentStatus { twilight, stardust, echo, seed, tide, islandCore }
