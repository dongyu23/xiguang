import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../design/tokens/motion.dart';

typedef TokenRefreshCallback = Future<String?> Function();

class ApiClient {
  ApiClient({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? defaultBaseUrl,
              connectTimeout: AppTiming.apiConnectTimeout,
              receiveTimeout: AppTiming.apiReceiveTimeout,
              sendTimeout: AppTiming.apiSendTimeout,
              headers: {'Content-Type': 'application/json'},
            )) {
    _dio.interceptors.add(_RetryInterceptor(_dio));
  }

  static const defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.5.200:8088/api/v1',
  );

  final Dio _dio;
  String? _accessToken;
  TokenRefreshCallback? _refreshToken;

  /// C4: Lock to prevent concurrent token refreshes
  Completer<bool>? _refreshLock;

  String get baseUrl => _dio.options.baseUrl;
  bool get hasToken => _accessToken != null;
  String get serverOrigin {
    final uri = Uri.parse(baseUrl);
    return uri
        .replace(path: '', query: null, fragment: null)
        .toString()
        .replaceFirst(RegExp(r'/$'), '');
  }

  String? debugAccessTokenForVerification() => _accessToken;

  void updateBaseUrl(String baseUrl) {
    final oldUrl = _dio.options.baseUrl;
    if (baseUrl == oldUrl) return;
    _dio.options.baseUrl = baseUrl;
    // 不暴力清 token — 新后端 401 → _refreshToken → refresh 失败 → AuthRepository.logout()
    // 这个自然流转会正确处理 session 清理
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

  Future<void> downloadToFile(String source, String targetPath) async {
    final trimmed = source.trim();
    final url = trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : '$serverOrigin/${trimmed.replaceFirst(RegExp(r'^/+'), '')}';
    await _dio.download(
      url,
      targetPath,
      options: Options(headers: _authHeaders()),
    );
  }

  Future<void> uploadToSignedUrl(
    String url,
    String filePath, {
    required String contentType,
  }) async {
    await Dio().put<void>(
      url,
      data: File(filePath).openRead(),
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': await File(filePath).length(),
        },
      ),
    );
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
      // C4: Coalesce concurrent refreshes into a single refresh call
      if (_refreshLock != null) {
        // Another request is already refreshing — wait for it
        final success = await _refreshLock!.future;
        if (!success) rethrow;
        // Refresh succeeded, retry with new token
        final response = await request();
        return _unwrap(response.data);
      }
      // We are the first to hit 401 — do the refresh
      final refreshLock = Completer<bool>();
      _refreshLock = refreshLock;
      try {
        final token = await _refreshToken!();
        if (token == null || token.isEmpty) {
          rethrow;
        }
        _accessToken = token;
        refreshLock.complete(true);
      } catch (_) {
        if (!refreshLock.isCompleted) refreshLock.complete(false);
        rethrow;
      } finally {
        _refreshLock = null;
      }
      // Keep the retry outside the refresh-completion block. If this request
      // still fails, callers must receive that failure instead of a second
      // completion attempt on the shared refresh lock.
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

  /// 解包 API 响应，兼容两种格式：
  /// 1. 当前格式: { ok: true, data: ... }
  /// 2. 规范格式: { code: "success", message: "ok", data: ... }
  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) return const {};

    // 成功响应 — 规范格式 { code: "success", data: ... }
    if (body['code'] == 'success' && body['data'] is Map<String, dynamic>) {
      return body['data'] as Map<String, dynamic>;
    }
    // 成功响应 — 当前格式 { ok: true, data: ... }
    if (body['ok'] == true && body['data'] is Map<String, dynamic>) {
      return body['data'] as Map<String, dynamic>;
    }
    if (body['ok'] == true) {
      return {'value': body['data']};
    }

    // 错误响应 — 规范格式 { code: "xxx", message: "..." }
    final code = body['code'] as String?;
    if (code != null && code != 'success') {
      throw DioException(
        requestOptions: RequestOptions(path: _dio.options.baseUrl),
        error: {'code': code, 'message': body['message'] ?? ''},
        type: DioExceptionType.badResponse,
      );
    }
    // 错误响应 — 当前格式 { ok: false, error: ... }
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
      // 规范格式: { code: "auth.unauthorized" }
      final code = body['code'] as String?;
      if (code != null && code.contains('unauthorized')) return true;
      // 当前格式: { error: { code: "unauthorized" } }
      final apiError = body['error'];
      if (apiError is Map) {
        final errorCode = apiError['code']?.toString() ?? '';
        if (errorCode.contains('unauthorized')) return true;
      }
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
    final delay = AppTiming.retryBackoff(attempts);
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
