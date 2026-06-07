import 'package:dio/dio.dart';

typedef TokenRefreshCallback = Future<String?> Function();

class ApiClient {
  ApiClient({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? defaultBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 10),
              headers: {'Content-Type': 'application/json'},
            )) {
    _dio.interceptors.add(_RetryInterceptor(_dio));
  }

  static const defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8088/api/v1',
  );

  final Dio _dio;
  String? _accessToken;
  TokenRefreshCallback? _refreshToken;

  String get baseUrl => _dio.options.baseUrl;
  bool get hasToken => _accessToken != null;
  String? get accessToken => _accessToken;
  String? debugAccessTokenForVerification() => _accessToken;

  void updateBaseUrl(String baseUrl) {
    final oldUrl = _dio.options.baseUrl;
    if (baseUrl == oldUrl) return;
    _dio.options.baseUrl = baseUrl;
    // 切换到新后端时清除旧凭据，避免用旧 JWT 请求新服务器导致反复 401
    _accessToken = null;
    _refreshToken = null;
  }

  set accessToken(String? token) {
    _accessToken = token;
  }

  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required String filePath,
    required String fileName,
    required int fragmentId,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'fragment_id': fragmentId,
    });
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: formData,
      options: Options(headers: _authHeaders()),
    );
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> uploadBytes(
    String path, {
    required List<int> bytes,
    required String fileName,
    required int fragmentId,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'fragment_id': fragmentId,
    });
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: formData,
      options: Options(headers: _authHeaders()),
    );
    return _unwrap(response.data);
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
    return _send(
      () => _dio.put<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(headers: _authHeaders()),
      ),
      allowRefresh: path != '/auth/refresh',
    );
  }

  Future<Map<String, dynamic>> delete(String path,
      {Map<String, dynamic>? body}) async {
    return _send(
      () => _dio.delete<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(headers: _authHeaders()),
      ),
      allowRefresh: path != '/auth/refresh',
    );
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

class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);
  final Dio _dio;

  static const _maxRetries = 3;
  static final _retryableStatuses = {429, 502, 503, 504};

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final extra = err.requestOptions.extra;
    final attempts = (extra['_retry_attempts'] as int?) ?? 0;
    if (attempts >= _maxRetries || !_isRetryable(err)) {
      handler.next(err);
      return;
    }
    extra['_retry_attempts'] = attempts + 1;
    final delay =
        Duration(milliseconds: (200 * (1 << attempts)).clamp(0, 3000));
    await Future.delayed(delay);
    try {
      final response = await _dio.fetch<dynamic>(
        err.requestOptions..extra = extra,
      );
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isRetryable(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }
    final status = err.response?.statusCode;
    return status != null && _retryableStatuses.contains(status);
  }
}
