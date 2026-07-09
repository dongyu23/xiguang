import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/auth_session.dart';

export '../../../app/providers.dart' show authRepositoryProvider;

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
