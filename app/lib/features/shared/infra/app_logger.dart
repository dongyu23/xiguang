// app/lib/features/shared/infra/app_logger.dart
import 'dart:developer' as developer;

import 'package:sentry_flutter/sentry_flutter.dart';

/// 统一日志入口。替代散落的 developer.log / debugPrint / print 直呼。
/// error 级 -> Sentry captureException；warn 级 -> Sentry breadcrumb；debug 级仅本地。
class AppLogger {
  AppLogger._();

  static void debug(String message, {Object? error}) {
    developer.log(message, name: 'xiguang', level: 0, error: error);
  }

  static void warn(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message,
        name: 'xiguang', level: 500, error: error, stackTrace: stackTrace);
    Sentry.addBreadcrumb(Breadcrumb(
      level: SentryLevel.warning,
      message: message,
      data: error == null ? null : {'error': error.toString()},
    ));
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message,
        name: 'xiguang', level: 1000, error: error, stackTrace: stackTrace);
    Sentry.captureException(error ?? message, stackTrace: stackTrace);
  }
}
