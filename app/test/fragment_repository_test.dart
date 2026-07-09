import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/fragment/data/fragment_repository.dart';
import 'package:xiguang/features/shared/data/local/app_database.dart';
import 'package:xiguang/features/shared/data/api_client.dart';

import 'test_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('remote create failure is not disguised as a local success', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.invalid/api/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
        requestOptions: options,
        response: Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 500,
          data: const {
            'ok': false,
            'error': {'code': 'create_failed', 'message': 'failed'},
          },
        ),
        type: DioExceptionType.badResponse,
      ));
    }));
    final auth = FakeAuthRepository();
    await auth.login(username: 'user', password: 'password');
    final api = ApiClient(dio: dio)..accessToken = 'test-token';
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = FragmentRepositoryImpl(api, auth, db: db);

    expect(
      () => repo.createFragment(
        text: 'hello',
        emotion: '平静',
        tags: const [],
      ),
      throwsA(isA<DioException>()),
    );
  });

  test('local media becomes an explicit local draft', () async {
    final auth = FakeAuthRepository();
    await auth.login(username: 'user', password: 'password');
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = FragmentRepositoryImpl(
      ApiClient(baseUrl: 'http://test.invalid/api/v1'),
      auth,
      db: db,
    );

    expect(
      () => repo.createFragment(
        text: 'hello',
        emotion: '平静',
        tags: const [],
        mediaUrls: const ['/tmp/local.jpg'],
      ),
      throwsA(isA<LocalDraftException>()),
    );
  });

  test('online create is mirrored locally for offline fallback', () async {
    final auth = FakeAuthRepository();
    await auth.login(username: 'user', password: 'password');
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = FragmentRepositoryImpl(
      _CreateApiClient(),
      auth,
      db: db,
    );

    final created = await repo.createFragment(
      text: 'online light',
      emotion: '平静',
      tags: const ['回声'],
    );

    expect(created.id, 42);
    final local = await db.getAllFragments();
    expect(local, hasLength(1));
    expect(local.single.id, 42);
    expect(local.single.publicId, 'fragment-42');
    expect(local.single.contentText, 'online light');
    expect(local.single.isSynced, isTrue);
  });

  test('online REST mutations are not enqueued a second time', () async {
    final auth = FakeAuthRepository();
    await auth.login(username: 'user', password: 'password');
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = FragmentRepositoryImpl(_CreateApiClient(), auth, db: db);
    final created = await repo.createFragment(
      text: 'online light',
      emotion: '平静',
      tags: const [],
    );
    final operations = <String>[];
    repo.onFragmentChanged = (_, operation, __, ___) {
      operations.add(operation);
    };

    await repo.updateFragmentText(
      created.id,
      'updated online light',
      emotion: '开心',
    );
    await repo.deleteFragment(created.id);

    expect(operations, isEmpty);
  });

  test('offline mutations are queued for later sync', () async {
    final auth = FakeAuthRepository();
    await auth.login(username: 'user', password: 'password');
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = FragmentRepositoryImpl(
      ApiClient(baseUrl: 'http://test.invalid/api/v1'),
      auth,
      db: db,
    );
    final operations = <String>[];
    repo.onFragmentChanged = (_, operation, __, ___) {
      operations.add(operation);
    };
    final created = await repo.createFragment(
      text: 'offline light',
      emotion: '平静',
      tags: const [],
    );
    operations.clear();

    await repo.updateFragmentText(created.id, 'updated offline light');
    await repo.deleteFragment(created.id);

    expect(operations, ['UPDATE', 'DELETE']);
  });
}

class _CreateApiClient extends ApiClient {
  _CreateApiClient() : super(baseUrl: 'http://test.invalid/api/v1') {
    accessToken = 'test-token';
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Options? options,
  }) async {
    return {
      'id': 42,
      'public_id': 'fragment-42',
      'content_text': body['content_text'],
      'emotion': body['emotion'],
      'tags': body['tag_names'],
      'media_urls': body['media_urls'],
      'created_at': '2026-07-10T08:00:00Z',
      'updated_at': '2026-07-10T08:00:00Z',
      'status': 'twilight',
    };
  }

  @override
  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    return {
      'id': 42,
      'public_id': 'fragment-42',
      'content_text': body['content_text'],
      'emotion': body['emotion'],
      'tags': body['tag_names'],
      'media_urls': body['media_urls'] ?? const [],
      'created_at': '2026-07-10T08:00:00Z',
      'updated_at': '2026-07-10T09:00:00Z',
      'status': 'twilight',
    };
  }

  @override
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return const {};
  }
}
