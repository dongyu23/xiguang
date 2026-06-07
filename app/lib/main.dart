import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/app.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options
        ..dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '')
        ..tracesSampleRate = 1.0
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
