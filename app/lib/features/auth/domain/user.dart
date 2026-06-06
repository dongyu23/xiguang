/// User 实体
///
/// TODO: freezed + json_serializable
class User {
  const User(
      {required this.id,
      required this.publicId,
      required this.username,
      required this.nickname,
      this.avatarKey});

  final int id;
  final String publicId;
  final String username;
  final String nickname;
  final String? avatarKey;
}
