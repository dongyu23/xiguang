import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/auth/application/auth_actions_controller.dart';
import 'package:xiguang/features/auth/application/auth_providers.dart';

import '../../test_auth_repository.dart';

void main() {
  test('auth actions controller remains available without a UI listener',
      () async {
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    ]);
    addTearDown(container.dispose);

    final first = container.read(authActionsControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final second = container.read(authActionsControllerProvider.notifier);

    expect(second, same(first));
  });
}
