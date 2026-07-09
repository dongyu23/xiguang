import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/app.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options
        ..dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '')
        // Debug 模式下关闭 trace 采样，减少路由跳转/操作的开销
        ..tracesSampleRate = kDebugMode ? 0.0 : 0.2
        ..debug = false;
    },
    appRunner: () => runZonedGuarded(
      () => runApp(const ProviderScope(child: XiguangApp())),
      (error, stack) {
        Sentry.captureException(error, stackTrace: stack);
      },
    ),
  );
}
