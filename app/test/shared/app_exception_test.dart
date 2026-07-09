import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/shared/domain/app_exception.dart';

void main() {
  group('AppException', () {
    test('NetworkException.fromDio converts connection timeout', () {
      final dio = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/x'),
        message: 'timeout',
      );
      final ex = NetworkException.fromDio(dio);
      expect(ex, isA<NetworkException>());
      expect(ex, isA<AppException>());
      expect(ex.message, isNotEmpty);
      expect(ex.cause, same(dio));
    });

    test('NetworkException.fromDio converts 401 to AuthException', () {
      final dio = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 401,
        ),
        message: 'unauthorized',
      );
      final ex = NetworkException.fromDio(dio);
      expect(ex, isA<AuthException>());
    });

    test('NetworkException.fromDio converts 500 to NetworkException', () {
      final dio = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 500,
        ),
        message: 'server error',
      );
      final ex = NetworkException.fromDio(dio);
      expect(ex, isA<NetworkException>());
      expect(ex, isNot(isA<AuthException>()));
    });

    test('StorageException wraps underlying cause', () {
      final ex = StorageException('drift write failed',
          cause: StateError('db locked'));
      expect(ex.message, 'drift write failed');
      expect(ex.cause, isA<StateError>());
    });
  });
}
