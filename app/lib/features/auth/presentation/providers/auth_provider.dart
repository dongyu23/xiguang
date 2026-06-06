import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthViewState { signedOut, signingIn, signedIn }

final authViewStateProvider = StateProvider<AuthViewState>((ref) {
  return AuthViewState.signedOut;
});
