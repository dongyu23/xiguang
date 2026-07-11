import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/app.dart';

Future<void> main() async {
  // runZonedGuarded 必须包在 SentryFlutter.init 外层，并在 zone 内先
  // ensureInitialized，保证 binding 与 runApp 在同一 zone；否则
  // SentryFlutter.init 在根 zone 初始化 binding、runApp 跑在子 zone，
  // 触发 "Zone mismatch" 导致 widget 树无法挂载、卡在开屏。
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SentryFlutter.init(
      (options) {
        options
          ..dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '')
          // Debug 模式下关闭 trace 采样，减少路由跳转/操作的开销
          ..tracesSampleRate = kDebugMode ? 0.0 : 0.2
          ..debug = false;
      },
      appRunner: () => runApp(const ProviderScope(child: XiguangApp())),
    );
  }, (error, stack) {
    Sentry.captureException(error, stackTrace: stack);
  });
}
