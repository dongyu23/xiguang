// app/test/shared/app_logger_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/shared/infra/app_logger.dart';

void main() {
  test('AppLogger.debug/warn/error do not throw without Sentry init', () {
    expect(() => AppLogger.debug('debug msg'), returnsNormally);
    expect(
      () => AppLogger.warn('warn msg', error: StateError('x')),
      returnsNormally,
    );
    expect(
      () => AppLogger.error('err msg',
          error: StateError('x'), stackTrace: StackTrace.current),
      returnsNormally,
    );
  });
}
