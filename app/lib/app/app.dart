import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import '../design/themes/theme.dart';
import '../design/themes/extensions/blur_theme.dart';
import '../design/themes/extensions/glow_theme.dart';
import '../design/themes/extensions/space_theme.dart';
import '../features/auth/data/auth_repository.dart';
import 'router.dart';

class XiguangApp extends ConsumerStatefulWidget {
  const XiguangApp({super.key});

  @override
  ConsumerState<XiguangApp> createState() => _XiguangAppState();
}

class _XiguangAppState extends ConsumerState<XiguangApp> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<AuthSession?>>(authRestoreProvider,
        (previous, next) {
      next.whenData((session) {
        ref.read(authSessionProvider.notifier).state = session;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final restore = ref.watch(authRestoreProvider);
    if (restore.isLoading && _router == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Glimmer',
        theme: _theme,
        builder: _fixedTextScaleBuilder,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    _router ??= createRouter(ref);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Glimmer',
      theme: _theme,
      routerConfig: _router,
      builder: _fixedTextScaleBuilder,
    );
  }

  ThemeData get _theme => xiguangTheme().copyWith(
        extensions: [
          BlurTheme.light(),
          GlowTheme.default_(),
          SpaceTheme.default_(),
        ],
      );

  Widget _fixedTextScaleBuilder(BuildContext context, Widget? child) {
    return MediaQuery.withNoTextScaling(
      child: child ?? const SizedBox.shrink(),
    );
  }
}
