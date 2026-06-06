import 'token.dart';
import 'user.dart';

abstract interface class AuthRepositoryContract {
  Future<(User, TokenPair)> login({
    required String username,
    required String password,
  });

  Future<(User, TokenPair)> register({
    required String username,
    required String password,
    required String nickname,
  });

  Future<TokenPair> refresh(String refreshToken);
  Future<void> logout();
}
