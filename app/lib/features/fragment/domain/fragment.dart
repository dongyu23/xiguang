/// Fragment 实体 — "光片"
///
/// TODO: 用 freezed + json_serializable 重写
class Fragment {
  const Fragment({
    required this.id,
    required this.publicId,
    required this.userId,
    required this.contentText,
    this.emotion,
    this.status = FragmentStatus.twilight,
    this.mediaUrls = const [],
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String publicId;
  final int userId;
  final String contentText;
  final String? emotion;
  final FragmentStatus status;
  final List<String> mediaUrls;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
}

enum FragmentStatus { twilight, stardust, echo, seed, tide, islandCore }
