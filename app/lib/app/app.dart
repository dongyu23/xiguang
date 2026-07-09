import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_state.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/sync/presentation/providers/sync_providers.dart';
import '../design/tokens/colors.dart';
import '../design/tokens/spacing.dart';
import '../design/tokens/motion.dart';
import '../design/tokens/typography.dart';
import '../design/themes/theme.dart';
import '../design/themes/extensions/blur_theme.dart';
import '../design/themes/extensions/glow_theme.dart';
import '../design/themes/extensions/night_theme.dart';
import '../design/themes/extensions/space_theme.dart';
import '../ui/primitives/sentry_error_boundary.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/app_update/application/app_update_providers.dart';
import '../features/sync/domain/sync_config.dart';
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
  Timer? _appUpdateTimer;
  late final _AppLifecycleObserver _lifecycleObserver;
  late final ValueNotifier<int> _authNotifier;

  // Theme 缓存 — 避免每次 build 重建 ThemeData + 4 个 extension
  ThemeData? _cachedTheme;
  bool? _cachedNightMode;

  @override
  void initState() {
    super.initState();
    _authNotifier = ValueNotifier(0);
    _lifecycleObserver = _AppLifecycleObserver(ref);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    // ErrorWidget.builder 只需设置一次，不应在 build() 中重复赋值
    ErrorWidget.builder = (details) {
      final nightMode = ref.read(nightModeProvider);
      return Material(
        child: Container(
          color: nightMode ? AppColors.nightBackground : AppColors.paper,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wb_twilight,
                    size: 48, color: AppColors.teaGreen),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '一道微光闪烁了一下。',
                  style: AppText.body.copyWith(
                    color:
                        nightMode ? AppText.nightInkMuted : AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${details.exception}',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(
                    color: nightMode
                        ? AppText.nightInkMuted.withValues(alpha: .72)
                        : AppColors.inkSubtle,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    };
    ref.listenManual<AsyncValue<AuthSession?>>(authRestoreProvider,
        (previous, next) {
      next.whenData((session) {
        ref.read(authSessionProvider.notifier).state = session;
        if (session != null) {
          ref.read(aiPolishEnabledProvider.notifier).state = session.aiEnabled;
          // 重启 app 时（authRestore 恢复会话）主动触发一次同步检查。
          // syncEngineProvider 提前初始化时调过一次 checkConnection，但那时
          // apiClient 可能还没 token，必然失败。authRestore 完成后再调一次。
          final engine = ref.read(syncEngineProvider);
          engine.checkConnection().then((connected) {
            if (!ref.exists(syncStatusProvider)) return;
            ref.read(syncStatusProvider.notifier).state = engine.status;
            if (connected && ref.read(syncConfigProvider).enabled) {
              engine.syncNow().then((status) {
                if (!ref.exists(syncStatusProvider)) return;
                ref.read(syncStatusProvider.notifier).state = status;
              });
            }
          });
        }
      });
    }, fireImmediately: true); // 冷启动时若 authRestore 已先于 listener 完成，
    // 必须立即补触发一次，否则永远不会连后端（用户反馈：第二次进入不自动连接）。
    // M3: Listen to auth changes in initState (not build) to avoid re-subscribing
    ref.listenManual<AuthSession?>(authSessionProvider, (previous, next) {
      if (previous?.id != next?.id) {
        _authNotifier.value++;
      }
      // 登录成功（从无 session 变为有 session）后，立刻刷新一次同步连通状态。
      // 之前的问题：syncEngineProvider 在登录前就初始化并调过一次 checkConnection，
      // 此时 apiClient 还没 token，永远拿到离线状态；登录后没有任何地方再次触发，
      // 导致用户进入应用后云同步一直显示离线，必须手动点测试连接才会更新。
      if (previous?.id != next?.id && next != null) {
        // 会话变更（登录或恢复）-> 立即标记已连接。
        // 登录：刚成功调用了 /auth/login，后端必然可达。
        // 恢复：本地读取 session，后续 checkConnection() 会验证真实连通性，
        //       不通时再纠正为 false。这样主 Shell 首帧不会闪现"未连接" banner。
        final currentSync = ref.read(syncStatusProvider);
        if (!currentSync.connected) {
          ref.read(syncStatusProvider.notifier).state =
              currentSync.copyWith(connected: true, error: null);
        }
        final engine = ref.read(syncEngineProvider);
        engine.checkConnection().then((connected) {
          if (!ref.exists(syncStatusProvider)) return;
          ref.read(syncStatusProvider.notifier).state = engine.status;
          if (connected && ref.read(syncConfigProvider).enabled) {
            engine.syncNow().then((status) {
              if (!ref.exists(syncStatusProvider)) return;
              ref.read(syncStatusProvider.notifier).state = status;
            });
          }
        });
      }
    });
    // H8: Trigger nightMode initialization here (was previously in removed Consumer)
    ref.listenManual<AsyncValue<bool>>(nightModeLoadedProvider, (_, __) {});
    // 预初始化 SyncEngine，确保 onFragmentChanged 在首次捕光前就位
    ref.read(syncEngineProvider);
    ref.listenManual<SyncConfig>(syncConfigProvider, (previous, next) {
      if (previous == null) return;
      stopAutoSync();
      startAutoSync(ref);
    });
    // 启动后台静默检查更新 — 30 秒后访问 /app/version，将红点状态写入 provider。
    _appUpdateTimer = Timer(AppTiming.updateCheckDelay, () {
      if (!mounted) return;
      try {
        ref.read(appUpdateStateProvider.notifier).checkForUpdate(silent: true);
      } catch (_) {}
    });
    // 启动自动同步（按 syncConfig.frequency）
    startAutoSync(ref);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _appUpdateTimer?.cancel();
    _authNotifier.dispose();
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restore = ref.watch(authRestoreProvider);
    final nightMode = ref.watch(nightModeProvider);

    if (restore.isLoading && _router == null) {
      return SentryErrorBoundary(
        child: SplashGate(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: '隙光',
            theme: _themeFor(nightMode),
            builder: (context, child) =>
                _errorBoundary(context, _fixedTextScaleBuilder(context, child)),
            home: const Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
    }
    // 只在首次创建路由，后续通过 refreshListenable 触发重定向
    _router ??= createRouter(ref, _authNotifier);
    return SentryErrorBoundary(
      child: SplashGate(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: '隙光',
          theme: _themeFor(nightMode),
          routerConfig: _router,
          builder: (context, child) =>
              _errorBoundary(context, _fixedTextScaleBuilder(context, child)),
        ),
      ),
    );
  }

  Widget _errorBoundary(BuildContext context, Widget? child) {
    return child ?? const SizedBox.shrink();
  }

  ThemeData _themeFor(bool nightMode) {
    if (_cachedTheme != null && _cachedNightMode == nightMode) {
      return _cachedTheme!;
    }
    _cachedNightMode = nightMode;
    _cachedTheme = xiguangTheme(nightMode: nightMode).copyWith(
      extensions: [
        BlurTheme.light(),
        GlowTheme.default_(),
        SpaceTheme.default_(),
        nightMode ? NightTheme.night() : NightTheme.day(),
      ],
    );
    return _cachedTheme!;
  }

  // H8: Use nightMode from outer build instead of watching again inside Consumer
  Widget _fixedTextScaleBuilder(BuildContext context, Widget? child) {
    final nightMode = ref.read(nightModeProvider);
    return MediaQuery.withNoTextScaling(
      child: SizedBox.expand(
        child: ColoredBox(
          color: nightMode
              ? NightTheme.night().background
              : NightTheme.day().background,
          child: child ?? const SizedBox.shrink(),
        ),
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
