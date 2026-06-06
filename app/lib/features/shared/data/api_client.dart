import 'package:dio/dio.dart';

typedef TokenRefreshCallback = Future<String?> Function();

class ApiClient {
  ApiClient({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ??
                  const String.fromEnvironment('API_BASE_URL',
                      defaultValue: 'http://127.0.0.1:8088/api/v1'),
              connectTimeout: const Duration(seconds: 2),
              receiveTimeout: const Duration(seconds: 4),
              sendTimeout: const Duration(seconds: 4),
              headers: {'Content-Type': 'application/json'},
            ));

  final Dio _dio;
  String? _accessToken;
  TokenRefreshCallback? _refreshToken;

  String get baseUrl => _dio.options.baseUrl;
  bool get hasToken => _accessToken != null;
  String? get accessToken => _accessToken;
  String? debugAccessTokenForVerification() => _accessToken;

  set accessToken(String? token) {
    _accessToken = token;
  }

  set tokenRefreshCallback(TokenRefreshCallback? callback) {
    _refreshToken = callback;
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? query}) async {
    return _send(() => _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: query,
          options: Options(headers: _authHeaders()),
        ));
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Options? options,
  }) async {
    return _send(
      () => _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: _mergeOptions(options),
      ),
      allowRefresh: path != '/auth/refresh',
    );
  }

  Future<Map<String, dynamic>> put(
      String path, Map<String, dynamic> body) async {
    return _send(() => _dio.put<Map<String, dynamic>>(
          path,
          data: body,
          options: Options(headers: _authHeaders()),
        ));
  }

  Future<Map<String, dynamic>> delete(String path,
      {Map<String, dynamic>? body}) async {
    return _send(() => _dio.delete<Map<String, dynamic>>(
          path,
          data: body,
          options: Options(headers: _authHeaders()),
        ));
  }

  Future<Map<String, dynamic>> _send(
    Future<Response<Map<String, dynamic>>> Function() request, {
    bool allowRefresh = true,
  }) async {
    try {
      final response = await request();
      return _unwrap(response.data);
    } on DioException catch (error) {
      if (!allowRefresh || !_isUnauthorized(error) || _refreshToken == null) {
        rethrow;
      }
      final token = await _refreshToken!();
      if (token == null || token.isEmpty) {
        rethrow;
      }
      _accessToken = token;
      final response = await request();
      return _unwrap(response.data);
    }
  }

  Map<String, String> _authHeaders() {
    final token = _accessToken;
    if (token == null) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  Options _mergeOptions(Options? options) {
    final headers = <String, dynamic>{
      ...?options?.headers,
      ..._authHeaders(),
    };
    return (options ?? Options()).copyWith(headers: headers);
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) return const {};
    if (body['ok'] == true && body['data'] is Map<String, dynamic>) {
      return body['data'] as Map<String, dynamic>;
    }
    if (body['ok'] == true) {
      return {'value': body['data']};
    }
    throw DioException(
      requestOptions: RequestOptions(path: _dio.options.baseUrl),
      error: body['error'] ?? body,
      type: DioExceptionType.badResponse,
    );
  }

  bool _isUnauthorized(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401) return true;
    final body = error.response?.data;
    if (body is Map<String, dynamic>) {
      final apiError = body['error'];
      return apiError is Map && apiError['code'] == 'unauthorized';
    }
    return false;
  }
}
