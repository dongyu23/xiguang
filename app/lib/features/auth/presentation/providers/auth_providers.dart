import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final authRestoreProvider = FutureProvider<AuthSession?>((ref) {
  return ref.watch(authRepositoryProvider).restoreSession();
});

final authSessionProvider = StateProvider<AuthSession?>((ref) {
  return ref.watch(authRepositoryProvider).currentSession;
});

final sessionProvider = FutureProvider<AuthSession>((ref) {
  final current = ref.watch(authSessionProvider);
  if (current != null) return current;
  return ref.watch(authRepositoryProvider).ensureSession();
});
