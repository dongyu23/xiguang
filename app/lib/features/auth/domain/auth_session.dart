class AuthSession {
  const AuthSession({
    required this.id,
    required this.publicId,
    required this.username,
    required this.nickname,
    this.avatarKey = '',
    this.aiEnabled = false,
    this.aiConsentAcceptedAt,
    this.privacyMode = 'private',
  });

  final int id;
  final String publicId;
  final String username;
  final String nickname;
  final String avatarKey;
  final bool aiEnabled;
  /// 用户首次开启星图管理员时记录的同意时间（ISO 字符串）。null = 未同意。
  /// 一旦设置不清空，关闭 AI 只置 aiEnabled=false。
  final String? aiConsentAcceptedAt;
  final String privacyMode;

  AuthSession copyWith({
    int? id,
    String? publicId,
    String? username,
    String? nickname,
    String? avatarKey,
    bool? aiEnabled,
    String? aiConsentAcceptedAt,
    String? privacyMode,
  }) {
    return AuthSession(
      id: id ?? this.id,
      publicId: publicId ?? this.publicId,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      avatarKey: avatarKey ?? this.avatarKey,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiConsentAcceptedAt: aiConsentAcceptedAt ?? this.aiConsentAcceptedAt,
      privacyMode: privacyMode ?? this.privacyMode,
    );
  }
}
