import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import '../design/tokens/colors.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/fragment/presentation/pages/capture_page.dart';
import '../features/fragment/presentation/pages/fragment_detail_page.dart';
import '../features/fragment/presentation/pages/fragment_edit_page.dart';
import '../features/ai/presentation/pages/glow_organize_page.dart';
import '../features/ai/presentation/pages/ai_build_islands_page.dart';
import '../features/timeline/presentation/pages/time_river_page.dart';
import '../features/island/presentation/pages/island_detail_page.dart';
import '../features/island/presentation/pages/island_create_page.dart';
import '../features/island/presentation/pages/universe_page.dart';
import '../features/space/presentation/pages/space_page.dart';
import '../features/starmap/presentation/widgets/starmap_page.dart';
import '../features/whitenoise/presentation/pages/whitenoise_page.dart';
import '../features/profile/presentation/pages/mine_page.dart';
import '../features/relation/presentation/pages/relation_ledger_page.dart';
import '../features/relation/presentation/pages/weave_page.dart';
import '../features/sync/presentation/pages/sync_settings_page.dart';
import '../ui/spaces/space_canvas.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter + StatefulShellRoute.indexedStack
///
/// 四个底部 Tab 作为一级入口；光片详情/织线保留为上下文页面。
GoRouter createRouter(WidgetRef ref) {
  final shellRouteKey = GlobalKey<StatefulNavigationShellState>();
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final restore = ref.read(authRestoreProvider);
      final signedIn = ref.read(authSessionProvider) != null ||
          ref.read(authRepositoryProvider).currentSession != null;
      final path = state.uri.path;
      final isRestoreRoute = path == '/auth-restoring';
      final isAuthRoute = path == '/login' || path == '/register';
      if (restore.isLoading) {
        return isRestoreRoute ? null : '/auth-restoring';
      }
      if (isRestoreRoute) return signedIn ? '/capture' : '/login';
      if (!signedIn && !isAuthRoute) return '/login';
      if (signedIn && path == '/login') return '/capture';
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
                path: '/universe', builder: (_, __) => const UniversePage()),
            GoRoute(
                path: '/islands/create',
                builder: (_, __) => const IslandCreatePage()),
            GoRoute(
                path: '/islands/:id',
                builder: (_, state) =>
                    IslandDetailPage(id: state.pathParameters['id']!)),
            GoRoute(
                path: '/relations/ledger',
                builder: (_, __) => const RelationLedgerPage()),
          ]),
          // Tab 4: 我的
          StatefulShellBranch(routes: [
            GoRoute(path: '/mine', builder: (_, __) => const MinePage()),
            GoRoute(
                path: '/sync-settings',
                builder: (_, __) => const SyncSettingsPage()),
          ]),
        ],
      ),
      // 非 Tab 页面（全屏）
      GoRoute(path: '/space', builder: (_, __) => const SpacePage()),
      GoRoute(path: '/starmap', builder: (_, __) => const StarmapPage()),
      GoRoute(path: '/whitenoise', builder: (_, __) => const WhiteNoisePage()),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/fragments/:id',
        builder: (_, state) =>
            FragmentDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/fragments/:id/edit',
        builder: (_, state) =>
            FragmentEditPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/weave/:sourceId',
        builder: (_, state) => WeavePage(
          sourceId: int.tryParse(state.pathParameters['sourceId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
          path: '/glow-organize', builder: (_, __) => const GlowOrganizePage()),
      GoRoute(
          path: '/ai/build-islands',
          builder: (_, __) => const AiBuildIslandsPage()),
      GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
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
        Positioned.fill(child: AtmosphereBackground()),
        Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}

/// 底部导航骨架 — 更新 activeTabIndex 以便各页面暂停非活跃动画
class _AppShell extends ConsumerWidget {
  const _AppShell(this.navigationShell);
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(activeTabIndexProvider.notifier).state = navigationShell.currentIndex;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: navigationShell,
      bottomNavigationBar: _XiguangNavBar(
        selectedIndex: navigationShell.currentIndex,
        onTap: (i) => context.go(_tabRootPaths[i]),
      ),
    );
  }
}

const _tabRootPaths = ['/capture', '/timeline', '/universe', '/mine'];

/// 底部导航栏 — 隙 / 线 / 屿 / 我的
class _XiguangNavBar extends ConsumerWidget {
  const _XiguangNavBar({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nightMode = ref.watch(nightModeProvider);
    const items = [
      ('assets/nav_icons/nav_gap.png', '隙', 'capture', 34.0, 28.0),
      ('assets/nav_icons/nav_thread.png', '线', 'timeline', 28.0, 23.0),
      ('assets/nav_icons/nav_island.png', '屿', 'universe', 34.0, 28.0),
      ('assets/nav_icons/nav_mine.png', '我的', 'mine', 34.0, 28.0),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: (nightMode ? const Color(0xFF172625) : const Color(0xFFFFFCF6))
            .withValues(alpha: nightMode ? .96 : .94),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: (nightMode ? Colors.black : const Color(0xFF23413F))
                  .withValues(alpha: nightMode ? .26 : .07),
              blurRadius: 28,
              offset: const Offset(0, 16))
        ],
        border: Border.all(
            color: nightMode
                ? AppColors.white.withValues(alpha: .10)
                : const Color(0xFFE4DDD0)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (i) {
            final selected = selectedIndex == i;
            return Expanded(
              child: InkWell(
                key: ValueKey('nav-${items[i].$3}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF72A58F)
                            .withValues(alpha: nightMode ? .24 : .16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _NavIcon(
                      assetPath: items[i].$1,
                      selected: selected,
                      nightMode: nightMode,
                      width: items[i].$4,
                      height: items[i].$5,
                    ),
                    const SizedBox(height: 4),
                    Text(items[i].$2,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? (nightMode
                                    ? AppColors.white
                                    : const Color(0xFF233332))
                                : (nightMode
                                    ? AppColors.white.withValues(alpha: .62)
                                    : const Color(0xFF78827D)))),
                  ]),
                ),
              ),
            );
          }),
        ),
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
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: selected ? 1 : (nightMode ? .72 : .66),
      child: Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class FragmentEditPlaceholder extends StatelessWidget {
  const FragmentEditPlaceholder({super.key, required this.id});
  final String id;
  @override
  Widget build(_) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: Text('编辑光片: $id')),
      );
}
