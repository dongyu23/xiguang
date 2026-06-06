import 'package:xiguang/features/auth/data/auth_repository.dart';
import 'package:xiguang/features/shared/data/api_client.dart';

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository()
      : super(ApiClient(baseUrl: 'http://test.invalid/api/v1'));

  AuthSession? _session;
  int _nextID = 1;

  @override
  AuthSession? get currentSession => _session;

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> ensureSession() => me();

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      throw StateError('invalid_login');
    }
    _session = _newSession(
      username: username.trim(),
      nickname: username.trim() == 'second_user' ? '第二个账号' : '后端试光者',
    );
    return _session!;
  }

  @override
  Future<AuthSession> register({
    required String username,
    required String password,
    required String nickname,
  }) async {
    if (username.trim().isEmpty ||
        password.isEmpty ||
        nickname.trim().isEmpty) {
      throw StateError('invalid_register');
    }
    _session = _newSession(
      username: username.trim(),
      nickname: nickname.trim(),
    );
    return _session!;
  }

  @override
  Future<void> logout() async {
    _session = null;
  }

  @override
  Future<AuthSession> me() async {
    final session = _session;
    if (session == null) throw StateError('not_authenticated');
    return session;
  }

  @override
  Future<AuthSession> updateMe({
    required String nickname,
    required String avatarKey,
    required bool aiEnabled,
    required String privacyMode,
  }) async {
    final session = _session;
    if (session == null) throw StateError('not_authenticated');
    _session = session.copyWith(
      nickname: nickname.trim().isEmpty ? session.nickname : nickname.trim(),
      avatarKey: avatarKey.trim(),
      aiEnabled: aiEnabled,
      privacyMode: privacyMode,
    );
    return _session!;
  }

  AuthSession _newSession({
    required String username,
    required String nickname,
  }) {
    final id = _nextID++;
    return AuthSession(
      id: id,
      publicId: 'test-public-$id',
      username: username,
      nickname: nickname,
    );
  }
}
