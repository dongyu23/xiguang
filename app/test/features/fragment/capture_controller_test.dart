import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/fragment/application/capture_controller.dart';
import 'package:xiguang/features/fragment/application/fragment_list_controller.dart';
import 'package:xiguang/features/fragment/data/fragment_repository_impl.dart';
import 'package:xiguang/features/shared/data/api_client.dart';
import 'package:xiguang/features/shared/data/local/app_database.dart'
    hide Fragment;

import '../../test_auth_repository.dart';

void main() {
  test('fragment provider exposes loading until repository resolves', () async {
    final fixture = await _repositoryFixture();
    final completer = Completer<List<Fragment>>();
    final repository = _LoadingFragmentRepository(
      fixture.api,
      fixture.auth,
      db: fixture.db,
      local: completer.future,
    );
    final container = ProviderContainer(overrides: [
      fragmentRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(fragmentsProvider, (_, __) {});
    addTearDown(subscription.close);

    expect(container.read(fragmentsProvider).isLoading, isTrue);
    completer.complete(const []);
    expect(await container.read(fragmentsProvider.future), isEmpty);
  });

  test('fragment provider represents an empty repository result', () async {
    final fixture = await _repositoryFixture();
    final repository = _EmptyFragmentRepository(
      fixture.api,
      fixture.auth,
      db: fixture.db,
    );
    final container = ProviderContainer(overrides: [
      fragmentRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);

    expect(await container.read(fragmentsProvider.future), isEmpty);
    expect(container.read(fragmentsProvider).hasValue, isTrue);
  });

  test('fragment provider exposes repository load errors', () async {
    final fixture = await _repositoryFixture();
    final repository = _LoadErrorFragmentRepository(
      fixture.api,
      fixture.auth,
      db: fixture.db,
    );
    final container = ProviderContainer(overrides: [
      fragmentRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);

    await expectLater(
      container.read(fragmentsProvider.future),
      throwsA(isA<StateError>()),
    );
    expect(container.read(fragmentsProvider).hasError, isTrue);
  });

  test('capture controller commits a fragment through provider overrides',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final auth = FakeAuthRepository();
    await auth.login(username: 'capture', password: 'password');
    final repository = FragmentRepositoryImpl(
      ApiClient(baseUrl: 'http://test.invalid/api/v1'),
      auth,
      db: db,
    );
    final container = ProviderContainer(overrides: [
      fragmentRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final subscription =
        container.listen(captureControllerProvider, (_, __) {});
    addTearDown(subscription.close);

    final fragment = await container
        .read(captureControllerProvider.notifier)
        .capture(text: '被接住的一刻', emotion: '平静', tags: const ['夜晚']);

    expect(fragment.contentText, '被接住的一刻');
    expect(container.read(captureControllerProvider).isSaving, isFalse);
    expect(container.read(captureControllerProvider).error, isNull);
    expect(
      container.read(fragmentsProvider).valueOrNull,
      contains(predicate<Fragment>((item) => item.id == fragment.id)),
    );
  });

  test('capture controller exposes a failed local write', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final auth = FakeAuthRepository();
    await auth.login(username: 'capture', password: 'password');
    final repository = _ThrowingFragmentRepository(
      ApiClient(baseUrl: 'http://test.invalid/api/v1'),
      auth,
      db: db,
    );
    final container = ProviderContainer(overrides: [
      fragmentRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final subscription =
        container.listen(captureControllerProvider, (_, __) {});
    addTearDown(subscription.close);
    await expectLater(
      container.read(captureControllerProvider.notifier).capture(
        text: '写入失败',
        emotion: '混乱',
        tags: const [],
      ),
      throwsA(anything),
    );

    final state = container.read(captureControllerProvider);
    expect(state.isSaving, isFalse);
    expect(state.error, isNotNull);
  });
}

Future<
    ({
      AppDatabase db,
      FakeAuthRepository auth,
      ApiClient api,
    })> _repositoryFixture() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final auth = FakeAuthRepository();
  await auth.login(username: 'provider-test', password: 'password');
  return (
    db: db,
    auth: auth,
    api: ApiClient(baseUrl: 'http://test.invalid/api/v1'),
  );
}

class _LoadingFragmentRepository extends FragmentRepositoryImpl {
  _LoadingFragmentRepository(
    super.api,
    super.auth, {
    required AppDatabase db,
    required this.local,
  }) : super(db: db);

  final Future<List<Fragment>> local;

  @override
  Future<List<Fragment>> listLocalFragments() => local;

  @override
  Future<List<Fragment>?> tryListRemoteFragments() async => const [];
}

class _EmptyFragmentRepository extends FragmentRepositoryImpl {
  _EmptyFragmentRepository(
    super.api,
    super.auth, {
    required AppDatabase db,
  }) : super(db: db);

  @override
  Future<List<Fragment>> listLocalFragments() async => const [];

  @override
  Future<List<Fragment>?> tryListRemoteFragments() async => const [];
}

class _LoadErrorFragmentRepository extends FragmentRepositoryImpl {
  _LoadErrorFragmentRepository(
    super.api,
    super.auth, {
    required AppDatabase db,
  }) : super(db: db);

  @override
  Future<List<Fragment>> listLocalFragments() {
    throw StateError('simulated_load_failure');
  }
}

class _ThrowingFragmentRepository extends FragmentRepositoryImpl {
  _ThrowingFragmentRepository(
    super.api,
    super.auth, {
    required AppDatabase db,
  }) : super(db: db);

  @override
  Future<Fragment> createFragment({
    required String text,
    required String emotion,
    required List<String> tags,
    List<String> mediaUrls = const [],
  }) {
    throw StateError('simulated_write_failure');
  }
}
