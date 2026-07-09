import 'package:dio/dio.dart';

/// 应用统一异常层级。data 层出口转换为 AppException，presentation 层只 catch AppException。
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// 网络/HTTP 异常（超时、断网、5xx 等）。
class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});

  /// 从 DioException 转换。401/403 -> AuthException；其余 -> NetworkException。
  factory NetworkException.fromDio(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return AuthException('登录已失效，请重新登录', cause: e);
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return NetworkException('网络不太通，请稍后再试', cause: e);
    }
    if (e.type == DioExceptionType.connectionError) {
      return NetworkException('好像没有连上网', cause: e);
    }
    if (code != null && code >= 500) {
      return NetworkException('服务暂时不可用', cause: e);
    }
    return NetworkException('请求失败了，请稍后再试', cause: e);
  }
}

/// 认证异常（token 失效、未登录）。
class AuthException extends NetworkException {
  const AuthException(super.message, {super.cause});
}

/// 本地存储异常（drift、secure_storage、文件 IO）。
class StorageException extends AppException {
  const StorageException(super.message, {super.cause});
}

/// 未知异常兜底。
class UnknownException extends AppException {
  const UnknownException(super.message, {super.cause});
}
