import '../../shared/data/api_client.dart';

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

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;
  AuthSession? _session;

  AuthSession? get currentSession => _session;

  Future<AuthSession> ensureSession() async {
    final existing = _session;
    if (existing != null) return existing;
    return me();
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final body = await _api.post('/auth/login', {
      'username': username,
      'password': password,
    });
    return _saveSession(body);
  }

  Future<AuthSession> register({
    required String username,
    required String password,
    required String nickname,
  }) async {
    final body = await _api.post('/auth/register', {
      'username': username,
      'password': password,
      'nickname': nickname,
    });
    return _saveSession(body);
  }

  void logout() {
    _api.accessToken = null;
    _session = null;
  }

  Future<AuthSession> me() async {
    if (!_api.hasToken) {
      throw StateError('not_authenticated');
    }
    final body = await _api.get('/users/me');
    _session = _parseUser(body);
    return _session!;
  }

  Future<AuthSession> updateMe({
    required String nickname,
    required String avatarKey,
    required bool aiEnabled,
    required String privacyMode,
  }) async {
    if (!_api.hasToken) {
      throw StateError('not_authenticated');
    }
    final body = await _api.put('/users/me', {
      'nickname': nickname.trim(),
      'avatar_key': avatarKey.trim(),
      'ai_enabled': aiEnabled,
      'privacy_mode': privacyMode,
    });
    _session = _parseUser(body);
    return _session!;
  }

  AuthSession _saveSession(Map<String, dynamic> body) {
    final tokens = body['tokens'] as Map<String, dynamic>?;
    _api.accessToken = tokens?['access_token'] as String?;
    final user = body['user'] as Map<String, dynamic>? ?? const {};
    _session = _parseUser(user);
    return _session!;
  }

  AuthSession _parseUser(Map<String, dynamic> user) {
    return AuthSession(
      id: user['id'] as int? ?? 0,
      publicId: user['public_id'] as String? ?? '',
      username: user['username'] as String? ?? 'demo',
      nickname: user['nickname'] as String? ?? '试光者',
      avatarKey: user['avatar_key'] as String? ?? '',
      aiEnabled: user['ai_enabled'] as bool? ?? false,
      privacyMode: user['privacy_mode'] as String? ?? 'private',
    );
  }
}
