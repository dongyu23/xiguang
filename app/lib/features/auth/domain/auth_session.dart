class AuthSession {
  const AuthSession({
    required this.id,
    required this.publicId,
    required this.username,
    required this.nickname,
    this.avatarKey = '',
    this.aiEnabled = false,
    this.privacyMode = 'private',
  });

  final int id;
  final String publicId;
  final String username;
  final String nickname;
  final String avatarKey;
  final bool aiEnabled;
  final String privacyMode;

  AuthSession copyWith({
    int? id,
    String? publicId,
    String? username,
    String? nickname,
    String? avatarKey,
    bool? aiEnabled,
    String? privacyMode,
  }) {
    return AuthSession(
      id: id ?? this.id,
      publicId: publicId ?? this.publicId,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      avatarKey: avatarKey ?? this.avatarKey,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      privacyMode: privacyMode ?? this.privacyMode,
    );
  }
}
