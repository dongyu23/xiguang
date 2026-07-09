import '../../../design/tokens/motion.dart';
import '../../shared/data/api_client.dart';
import '../domain/auth_session.dart';
import '../domain/auth_repository.dart';
import 'session_storage.dart';

export '../domain/auth_session.dart';

class AuthRepository implements AuthRepositoryContract {
  AuthRepository(this._api, {SessionStorage storage = const SessionStorage()})
      : _storage = storage {
    _api.tokenRefreshCallback = _refreshForApiClient;
  }

  final ApiClient _api;
  final SessionStorage _storage;
  AuthSession? _session;
  String? _refreshToken;
  DateTime? _expiresAt;

  @override
  AuthSession? get currentSession => _session;

  @override
  Future<AuthSession> ensureSession() async {
    final existing = _session;
    if (existing != null) return existing;
    final restored = await restoreSession();
    if (restored != null) return restored;
    return me();
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final stored = await _storage.read();
    if (stored == null) return null;
    _session = stored.session;
    _refreshToken = stored.refreshToken;
    _expiresAt = stored.expiresAt;
    _api.accessToken = stored.accessToken;

    // 启动恢复只读取本地缓存，不在这里同步等待后端。
    // 无网时 refresh/me 会等到 Dio 超时，导致启动页长时间转圈；
    // 后续页面和同步引擎会各自尝试联网，失败时回退本地数据并显示未连接状态。
    return _session!;
  }

  @override
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

  @override
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

  @override
  Future<void> logout() async {
    _api.accessToken = null;
    _session = null;
    _refreshToken = null;
    _expiresAt = null;
    await _storage.delete();
  }

  @override
  Future<AuthSession> me() async {
    await _ensureFreshAccessToken();
    final body = await _api.get('/users/me');
    _session = _parseUser(body);
    return _session!;
  }

  @override
  Future<AuthSession> updateMe({
    required String nickname,
    required String avatarKey,
    required bool aiEnabled,
    required String privacyMode,
  }) async {
    await _ensureFreshAccessToken();
    final body = await _api.put('/users/me', {
      'nickname': nickname.trim(),
      'avatar_key': avatarKey.trim(),
      'ai_enabled': aiEnabled,
      'privacy_mode': privacyMode,
    });
    _session = _parseUser(body);
    await _persistCurrent();
    return _session!;
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _ensureFreshAccessToken();
    await _api.put('/auth/password', {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  Future<void> _ensureFreshAccessToken() async {
    if (_api.hasToken &&
        _expiresAt != null &&
        _expiresAt!.isBefore(DateTime.now().add(AppTiming.tokenRefreshSkew))) {
      await _refresh();
    }
    if (!_api.hasToken) {
      throw StateError('not_authenticated');
    }
  }

  Future<void> _refresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('not_authenticated');
    }
    final body = await _api.post('/auth/refresh', {
      'refresh_token': refreshToken,
    });
    _saveTokens(body);
    await _persistCurrent();
  }

  Future<String?> _refreshForApiClient() async {
    try {
      await _refresh();
      return _api.debugAccessTokenForVerification();
    } catch (_) {
      await logout();
      return null;
    }
  }

  Future<AuthSession> _saveSession(Map<String, dynamic> body) async {
    _saveTokens(body['tokens'] as Map<String, dynamic>? ?? const {});
    final user = body['user'] as Map<String, dynamic>? ?? const {};
    _session = _parseUser(user);
    await _persistCurrent();
    return _session!;
  }

  void _saveTokens(Map<String, dynamic> tokens) {
    final accessToken = tokens['access_token'] as String?;
    if (accessToken != null && accessToken.isNotEmpty) {
      _api.accessToken = accessToken;
    }
    final refreshToken = tokens['refresh_token'] as String?;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
    }
    final expiresAt = DateTime.tryParse(tokens['expires_at'] as String? ?? '');
    if (expiresAt != null) {
      _expiresAt = expiresAt;
    }
  }

  Future<void> _persistCurrent() async {
    final session = _session;
    final accessToken = _api.debugAccessTokenForVerification();
    final refreshToken = _refreshToken;
    final expiresAt = _expiresAt;
    if (session == null ||
        accessToken == null ||
        refreshToken == null ||
        expiresAt == null) {
      return;
    }
    await _storage.save(StoredAuthSession(
      session: session,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    ));
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
