import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_session.dart';
import 'auth_providers.dart';

class AuthActionState {
  const AuthActionState({this.isLoading = false, this.error});

  final bool isLoading;
  final Object? error;
}

class AuthActionsController extends Notifier<AuthActionState> {
  @override
  AuthActionState build() => const AuthActionState();

  void reset() => state = const AuthActionState();

  Future<AuthSession> login({
    required String username,
    required String password,
  }) {
    return _run(() => ref.read(authRepositoryProvider).login(
          username: username,
          password: password,
        ));
  }

  Future<AuthSession> register({
    required String username,
    required String password,
    required String nickname,
  }) {
    return _run(() => ref.read(authRepositoryProvider).register(
          username: username,
          password: password,
          nickname: nickname,
        ));
  }

  Future<void> logout() async {
    await _run(() => ref.read(authRepositoryProvider).logout());
    ref.read(authSessionProvider.notifier).state = null;
    ref.invalidate(sessionProvider);
  }

  Future<AuthSession> updateProfile({
    required String nickname,
    required String avatarKey,
    required bool aiEnabled,
    required String privacyMode,
  }) {
    return _run(() => ref.read(authRepositoryProvider).updateMe(
          nickname: nickname,
          avatarKey: avatarKey,
          aiEnabled: aiEnabled,
          privacyMode: privacyMode,
        ));
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return _run(() => ref.read(authRepositoryProvider).changePassword(
          oldPassword: oldPassword,
          newPassword: newPassword,
        ));
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    if (state.isLoading) throw StateError('auth_action_in_progress');
    state = const AuthActionState(isLoading: true);
    try {
      final result = await action();
      if (result is AuthSession) {
        ref.read(authSessionProvider.notifier).state = result;
        ref.invalidate(sessionProvider);
      }
      state = const AuthActionState();
      return result;
    } catch (error) {
      state = AuthActionState(error: error);
      rethrow;
    }
  }
}

final authActionsControllerProvider =
    NotifierProvider<AuthActionsController, AuthActionState>(
  AuthActionsController.new,
);
