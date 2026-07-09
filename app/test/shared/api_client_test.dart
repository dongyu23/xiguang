import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/shared/data/api_client.dart';

void main() {
  test('failed token refresh preserves the unauthorized response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.invalid/api/v1'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(DioException(
          requestOptions: options,
          response: Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        ));
      },
    ));
    final api = ApiClient(dio: dio)..accessToken = 'expired-token';
    api.tokenRefreshCallback = () async => null;

    expect(
      api.get('/protected'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
  });
}
