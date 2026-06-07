import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import '../design/tokens/colors.dart';
import '../design/themes/theme.dart';
import '../design/themes/extensions/blur_theme.dart';
import '../design/themes/extensions/glow_theme.dart';
import '../design/themes/extensions/space_theme.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/sync/presentation/providers/sync_provider.dart';
import 'router.dart';
import 'splash_gate.dart';

class XiguangApp extends ConsumerStatefulWidget {
  const XiguangApp({super.key});

  @override
  ConsumerState<XiguangApp> createState() => _XiguangAppState();
}

class _XiguangAppState extends ConsumerState<XiguangApp> {
  GoRouter? _router;
  int? _routerSessionId;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<AuthSession?>>(authRestoreProvider,
        (previous, next) {
      next.whenData((session) {
        ref.read(authSessionProvider.notifier).state = session;
        if (session != null) {
          ref.read(aiPolishEnabledProvider.notifier).state = session.aiEnabled;
        }
      });
    });
    // 预初始化 SyncEngine，确保 onFragmentChanged 在首次捕光前就位
    ref.read(syncEngineProvider);
    // 启动自动同步（按 syncConfig.frequency）
    startAutoSync(ref);
    // App 生命周期监听：回到前台时触发一次同步
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(ref));
  }

  @override
  Widget build(BuildContext context) {
    final restore = ref.watch(authRestoreProvider);
    final sessionId = ref.watch(authSessionProvider.select((s) => s?.id));
    if (restore.isLoading && _router == null) {
      return SplashGate(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '隙光',
          theme: _theme,
          builder: (context, child) =>
              _errorBoundary(context, _fixedTextScaleBuilder(context, child)),
          home: const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
    if (_router == null || _routerSessionId != sessionId) {
      final oldRouter = _router;
      _router = createRouter(ref);
      _routerSessionId = sessionId;
      if (oldRouter != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => oldRouter.dispose());
      }
    }
    return SplashGate(
      child: MaterialApp.router(
        key: ValueKey('xiguang-app-${sessionId ?? 'guest'}'),
        debugShowCheckedModeBanner: false,
        title: '隙光',
        theme: _theme,
        routerConfig: _router,
        builder: (context, child) =>
            _errorBoundary(context, _fixedTextScaleBuilder(context, child)),
      ),
    );
  }

  Widget _errorBoundary(BuildContext context, Widget? child) {
    ErrorWidget.builder = (details) {
      return Material(
        child: Container(
          color: AppColors.paper,
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wb_twilight, size: 48,
                    color: Color(0xFF72A58F)),
                const SizedBox(height: 16),
                Text(
                  '一道微光闪烁了一下。',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF78827D),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${details.exception}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFA0A8A5),
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    };
    return child ?? const SizedBox.shrink();
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
      child: Consumer(
        builder: (context, ref, _) {
          final nightMode = ref.watch(nightModeProvider);
          return SizedBox.expand(
            child: ColoredBox(
              color: nightMode ? const Color(0xFF142322) : AppColors.paper,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}

/// App 回到前台时触发一次同步检查
class _AppLifecycleObserver with WidgetsBindingObserver {
  _AppLifecycleObserver(this._ref);
  final WidgetRef _ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final engine = _ref.read(syncEngineProvider);
      if (!engine.status.isSyncing) {
        engine.syncNow().then((status) {
          if (_ref.exists(syncStatusProvider)) {
            _ref.read(syncStatusProvider.notifier).state = status;
          }
        });
      }
    }
  }
}
