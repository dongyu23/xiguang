import 'auth_session.dart';

abstract interface class AuthRepositoryContract {
  AuthSession? get currentSession;

  Future<AuthSession> ensureSession();
  Future<AuthSession?> restoreSession();
  Future<AuthSession> login({
    required String username,
    required String password,
  });
  Future<AuthSession> register({
    required String username,
    required String password,
    required String nickname,
  });
  Future<void> logout();
  Future<AuthSession> me();
  Future<AuthSession> updateMe({
    required String nickname,
    required String avatarKey,
    required bool aiEnabled,
    required String privacyMode,
  });
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });
}
