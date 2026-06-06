import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/fragment/data/fragment_repository.dart';
import 'package:xiguang/features/shared/data/api_client.dart';

import 'test_auth_repository.dart';

void main() {
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
    final repo = FragmentRepository(api, auth);

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
    final repo = FragmentRepository(
      ApiClient(baseUrl: 'http://test.invalid/api/v1'),
      auth,
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
}
