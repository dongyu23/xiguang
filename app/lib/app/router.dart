import 'package:flutter/material.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'app_state.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/sync/presentation/providers/sync_providers.dart';
import '../design/tokens/colors.dart';
import '../design/tokens/motion.dart';
import '../design/tokens/radius.dart';
import '../design/tokens/spacing.dart';
import '../design/tokens/typography.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/fragment/presentation/pages/capture_page.dart';
import '../features/fragment/presentation/pages/fragment_detail_page.dart';
import '../features/fragment/presentation/pages/fragment_edit_page.dart';
import '../features/ai/presentation/pages/glow_organize_page.dart';
import '../features/ai/presentation/pages/island_group_suggestions_page.dart';
import '../features/ai/domain/ai_request.dart';
import '../features/timeline/presentation/pages/time_river_page.dart';
import '../features/island/presentation/pages/island_detail_page.dart';
import '../features/island/presentation/pages/island_create_page.dart';
import '../features/island/presentation/pages/universe_page.dart';
import '../features/island/presentation/pages/branch_detail_page.dart';
import '../features/island/domain/universe_overview.dart';
import '../features/membership/presentation/pages/membership_page.dart';
import '../features/space/presentation/pages/space_page.dart';
import '../features/whitenoise/presentation/pages/whitenoise_page.dart';
import '../features/stats/presentation/pages/tide_insight_page.dart';
import '../features/profile/presentation/pages/mine_page.dart';
import '../features/profile/presentation/pages/data_archive_page.dart';
import '../features/profile/presentation/pages/trash_page.dart';
import '../features/profile/presentation/pages/about_page.dart';
import '../features/profile/presentation/pages/privacy_settings_page.dart';
import '../features/profile/presentation/pages/storage_settings_page.dart';
import '../features/profile/presentation/pages/device_management_page.dart';
import '../features/profile/presentation/pages/reminder_settings_page.dart';
import '../features/relation/presentation/pages/relation_ledger_page.dart';
import '../features/relation/presentation/pages/relation_type_manage_page.dart';
import '../features/relation/presentation/pages/weave_page.dart';
import '../features/sync/presentation/pages/sync_settings_page.dart';
import '../features/emotion/presentation/pages/emotion_manage_page.dart';
import '../ui/spaces/space_canvas.dart';

import '../ui/primitives/night_background.dart';
import 'navigator.dart';

/// GoRouter + StatefulShellRoute.indexedStack
///
/// 四个底部 Tab 作为一级入口；光片详情/织线保留为上下文页面。
/// [refreshListenable] 用于在 auth 状态变化时触发重定向，避免重建整个路由。
GoRouter createRouter(WidgetRef ref, [Listenable? refreshListenable]) {
  final shellRouteKey = GlobalKey<StatefulNavigationShellState>();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final restore = ref.read(authRestoreProvider);
      final signedIn = ref.read(authSessionProvider) != null;
      final path = state.uri.path;
      final isRestoreRoute = path == '/auth-restoring';
      final isAuthRoute = path == '/login' || path == '/register';
      // 已退出登录时，即使 restore 还在 loading 也允许 /login，避免卡白屏
      if (restore.isLoading) {
        if (signedIn || isAuthRoute) return null;
        return isRestoreRoute ? null : '/auth-restoring';
      }
      if (isRestoreRoute) return signedIn ? '/capture' : '/login';
      // 深链接支持：未登录时记录原始路径，登录后回跳
      if (!signedIn && !isAuthRoute) {
        final returnTo = Uri.encodeComponent(state.uri.toString());
        return '/login?return_to=$returnTo';
      }
      // 登录后回跳到原始路径（深链接），否则去首页
      if (signedIn && path == '/login') {
        final returnTo = state.uri.queryParameters['return_to'];
        if (returnTo != null && returnTo.isNotEmpty) {
          return Uri.decodeComponent(returnTo);
        }
        return '/capture';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth-restoring',
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const _AuthRestoringPage(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const RegisterPage(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        key: shellRouteKey,
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell),
        branches: [
          // Tab 1: 捕光
          StatefulShellBranch(routes: [
            GoRoute(path: '/capture', builder: (_, __) => const CapturePage()),
          ]),
          // Tab 2: 时间河
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/timeline', builder: (_, __) => const TimeRiverPage()),
          ]),
          // Tab 3: 小宇宙
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/universe',
                builder: (_, state) => UniversePage(
                      showBranches:
                          state.uri.queryParameters['view'] == 'branches',
                      revealIslandKey: state.uri.queryParameters['reveal'],
                    )),
            GoRoute(
                path: '/islands/create',
                builder: (_, __) => const IslandCreatePage()),
            GoRoute(
                path: '/islands/:id',
                pageBuilder: (_, state) => CustomTransitionPage<void>(
                      key: state.pageKey,
                      transitionDuration: AppMotion.islandTravel,
                      reverseTransitionDuration: AppMotion.slow,
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        final fade = CurvedAnimation(
                          parent: animation,
                          curve:
                              const Interval(0, .42, curve: AppMotion.easeOut),
                          reverseCurve: AppMotion.easeIn,
                        );
                        return FadeTransition(opacity: fade, child: child);
                      },
                      child: IslandDetailPage(
                        id: state.pathParameters['id']!,
                        initialIsland: state.extra is IslandVisualNode
                            ? state.extra! as IslandVisualNode
                            : null,
                      ),
                    )),
            GoRoute(
                path: '/relations/ledger',
                builder: (_, __) => const RelationLedgerPage()),
            GoRoute(
                path: '/relations/types/manage',
                builder: (_, __) => const RelationTypeManagePage()),
            GoRoute(
                path: '/branches/:id',
                builder: (_, state) => BranchDetailPage(
                      id: state.pathParameters['id']!,
                    )),
          ]),
          // Tab 4: 我的
          StatefulShellBranch(routes: [
            GoRoute(path: '/mine', builder: (_, __) => const MinePage()),
            GoRoute(
                path: '/experience-settings',
                builder: (_, __) => const ExperienceSettingsPage()),
            GoRoute(
                path: '/data-settings',
                builder: (_, __) => const DataSettingsOverviewPage()),
            GoRoute(
                path: '/membership',
                builder: (_, __) => const MembershipPage()),
            GoRoute(
                path: '/sync-settings',
                builder: (_, __) => const SyncSettingsPage()),
            GoRoute(
                path: '/emotions/manage',
                builder: (_, __) => const EmotionManagePage()),
            GoRoute(
                path: '/data-archive',
                builder: (_, __) => const DataArchivePage()),
            GoRoute(path: '/trash', builder: (_, __) => const TrashPage()),
            GoRoute(
                path: '/privacy-settings',
                builder: (_, __) => const PrivacySettingsPage()),
            GoRoute(
                path: '/storage-settings',
                builder: (_, __) => const StorageSettingsPage()),
            GoRoute(path: '/about', builder: (_, __) => const AboutPage()),
            GoRoute(
                path: '/devices',
                builder: (_, __) => const DeviceManagementPage()),
            GoRoute(
                path: '/reminders',
                builder: (_, __) => const ReminderSettingsPage()),
          ]),
        ],
      ),
      // 非 Tab 页面（全屏）
      GoRoute(path: '/space', builder: (_, __) => const SpacePage()),
      GoRoute(path: '/starmap', redirect: (_, __) => '/universe?view=branches'),
      GoRoute(path: '/whitenoise', builder: (_, __) => const WhiteNoisePage()),
      GoRoute(
          path: '/tide-insight', builder: (_, __) => const TideInsightPage()),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/fragments/:id',
        builder: (_, state) => FragmentDetailPage(
          id: state.pathParameters['id']!,
          islandId: int.tryParse(
            state.uri.queryParameters['islandId'] ?? '',
          ),
          islandRouteId: state.uri.queryParameters['islandRouteId'],
          islandName: state.uri.queryParameters['islandName'],
          islandManual: state.uri.queryParameters['islandManual'] == '1',
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/fragments/:id/edit',
        builder: (_, state) =>
            FragmentEditPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/weave/:sourceId',
        builder: (_, state) => WeavePage(
          sourceId: int.tryParse(state.pathParameters['sourceId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
          path: '/glow-organize',
          builder: (_, state) {
            final query = state.uri.queryParameters;
            AIScope? scope;
            final ids = (query['fragmentIds'] ?? '')
                .split(',')
                .map(int.tryParse)
                .whereType<int>()
                .toList();
            final islandId = int.tryParse(query['islandId'] ?? '');
            final days = int.tryParse(query['days'] ?? '');
            if (ids.length >= 2) {
              scope = AIScope.fragments(ids);
            } else if (islandId != null) {
              scope = AIScope.island(islandId);
            } else if (days == 7 || days == 30) {
              scope = AIScope.range(days);
            }
            return GlowOrganizePage(initialScope: scope);
          }),
      GoRoute(
          path: '/ai/island-groups',
          builder: (_, __) => const IslandGroupSuggestionsPage()),
      GoRoute(
          path: '/ai/build-islands', redirect: (_, __) => '/ai/island-groups'),
      GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/fragment-detail/:id',
          redirect: (_, state) => '/fragments/${state.pathParameters['id']}'),
    ],
  );
}

class _AuthRestoringPage extends StatelessWidget {
  const _AuthRestoringPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Positioned.fill(child: RepaintBoundary(child: AtmosphereBackground())),
        Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}

/// 底部导航骨架 — 双击返回退出 + 更新 activeTabIndex
class _AppShell extends ConsumerStatefulWidget {
  const _AppShell(this.navigationShell);
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  DateTime? _lastBackPress;
  int? _reportedTabIndex;

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    _reportActiveTab(currentIndex);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    // 键盘弹出时收起底部导航，把空间留给输入区
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < AppMotion.snackbar) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        showOverlaySnackBar(
          context,
          SnackBar(
            content: const Text('再按一次退出隙光'),
            duration: AppMotion.snackbar,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.routeOverlayClearance,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg)),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // C2: Single AtmosphereBackground for all tabs (prevents 4x simultaneous animations)
            const Positioned.fill(child: NightBackgroundPlaceholder()),
            // RepaintBoundary: 隔离 ambient 动画的每帧重绘，避免波及内容层
            const Positioned.fill(
                child: RepaintBoundary(child: AtmosphereBackground())),
            widget.navigationShell,
            const Positioned(
              left: 16,
              right: 16,
              top: 10,
              child: _BackendDisconnectedBanner(),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 10 + bottomPadding,
              child: IgnorePointer(
                ignoring: keyboardVisible,
                child: AnimatedOpacity(
                  opacity: keyboardVisible ? 0 : 1,
                  duration: AppMotion.fast,
                  curve: AppMotion.easeOut,
                  child: _XiguangNavBar(
                    selectedIndex: currentIndex,
                    onTap: (i) {
                      if (i == currentIndex) {
                        ref.read(scrollToTopSignalProvider.notifier).state++;
                      } else {
                        widget.navigationShell
                            .goBranch(i, initialLocation: true);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reportActiveTab(int index) {
    if (_reportedTabIndex == index) return;
    _reportedTabIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(activeTabIndexProvider.notifier);
      if (notifier.state != index) notifier.state = index;
    });
  }
}

class _BackendDisconnectedBanner extends ConsumerWidget {
  const _BackendDisconnectedBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    if (status.connected) return const SizedBox.shrink();
    final topPadding = MediaQuery.paddingOf(context).top;
    final nightMode = ref.watch(nightModeProvider);
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: nightMode
                ? AppColors.nightSurfaceHigh.withValues(alpha: .92)
                : AppColors.white.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: AppColors.sunsetCoral.withValues(alpha: .30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: nightMode ? .20 : .08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 16,
                color: AppColors.sunsetCoral,
              ),
              const SizedBox(width: AppSpacing.s6),
              Text(
                '后端未连接，本地记录仍可使用',
                style: AppText.caption.copyWith(
                  color: nightMode ? AppColors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部导航栏 — 隙 / 线 / 屿 / 我的（Telegram 风格浮岛）
///
/// 选中态用滑动 pill 指示器，从旧 tab 平移到新 tab。
class _XiguangNavBar extends ConsumerWidget {
  const _XiguangNavBar({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    ('assets/nav_icons/nav_gap.png', '隙', 'capture', 34.0, 28.0),
    ('assets/nav_icons/nav_thread.png', '线', 'timeline', 32.0, 26.0),
    ('assets/nav_icons/nav_island.png', '屿', 'universe', 34.0, 28.0),
    ('assets/nav_icons/nav_mine.png', '我的', 'mine', 34.0, 28.0),
  ];

  static const _pillHMargin = 4.0;
  static const _pillVMargin = 3.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nightMode = ref.watch(nightModeProvider);
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s6,
        vertical: AppSpacing.s6,
      ),
      decoration: BoxDecoration(
        color: nightMode ? AppColors.nightSurfaceHigh : AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: nightMode ? .24 : .08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: nightMode ? .12 : .04),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / _items.length;
          return Stack(
            children: [
              // 滑动 pill — 选中指示器在 tab 之间平移
              AnimatedPositioned(
                duration: AppMotion.pageSwap,
                curve: AppMotion.microMovement,
                left: selectedIndex * tabWidth + _pillHMargin,
                top: _pillVMargin,
                bottom: _pillVMargin,
                child: Container(
                  width: tabWidth - _pillHMargin * 2,
                  decoration: BoxDecoration(
                    color: AppColors.teaGreen
                        .withValues(alpha: nightMode ? .22 : .12),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                ),
              ),
              // Tab 按钮
              Row(
                children: List.generate(_items.length, (i) {
                  final selected = selectedIndex == i;
                  return Expanded(
                    child: InkWell(
                      key: ValueKey('nav-${_items[i].$3}'),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      onTap: () => onTap(i),
                      child: SizedBox(
                        height: 52,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _NavIcon(
                              assetPath: _items[i].$1,
                              selected: selected,
                              nightMode: nightMode,
                              width: _items[i].$4,
                              height: _items[i].$5,
                            ),
                            const SizedBox(height: AppSpacing.s3),
                            Text(
                              _items[i].$2,
                              style: AppText.nav.copyWith(
                                color: selected
                                    ? (nightMode
                                        ? AppColors.white
                                        : AppColors.ink)
                                    : (nightMode
                                        ? AppColors.white.withValues(alpha: .50)
                                        : AppColors.inkMuted
                                            .withValues(alpha: .72)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.assetPath,
    required this.selected,
    required this.nightMode,
    required this.width,
    required this.height,
  });

  final String assetPath;
  final bool selected;
  final bool nightMode;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      // 小图标用 medium 足够；high 对 34x28 图标过度采样，浪费 GPU
      filterQuality: FilterQuality.medium,
      // 按显示尺寸 3x 解码，避免按原始分辨率解码后再缩放（省内存 + 省 GPU）
      cacheWidth: (width * 3).round(),
      cacheHeight: (height * 3).round(),
      opacity: selected
          ? const AlwaysStoppedAnimation(1)
          : AlwaysStoppedAnimation(nightMode ? .55 : .50),
    );
  }
}
