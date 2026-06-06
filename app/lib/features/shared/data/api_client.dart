import 'package:dio/dio.dart';

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

  String get baseUrl => _dio.options.baseUrl;
  bool get hasToken => _accessToken != null;
  String? debugAccessTokenForVerification() => _accessToken;

  set accessToken(String? token) {
    _accessToken = token;
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
      options: Options(headers: _authHeaders()),
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: body,
      options: Options(headers: _authHeaders()),
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> put(
      String path, Map<String, dynamic> body) async {
    final response = await _dio.put<Map<String, dynamic>>(
      path,
      data: body,
      options: Options(headers: _authHeaders()),
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      path,
      options: Options(headers: _authHeaders()),
    );
    return _unwrap(response.data);
  }

  Map<String, String> _authHeaders() {
    final token = _accessToken;
    if (token == null) return const {};
    return {'Authorization': 'Bearer $token'};
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
}
