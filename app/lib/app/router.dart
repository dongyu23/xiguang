import 'package:flutter/material.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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

import 'navigator.dart';

/// GoRouter + StatefulShellRoute.indexedStack
///
/// 四个底部 Tab 作为一级入口；光片详情/织线保留为上下文页面。
GoRouter createRouter(WidgetRef ref) {
  final shellRouteKey = GlobalKey<StatefulNavigationShellState>();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
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
        parentNavigatorKey: rootNavigatorKey,
        path: '/fragments/:id',
        builder: (_, state) =>
            FragmentDetailPage(id: state.pathParameters['id']!),
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
          path: '/glow-organize', builder: (_, __) => const GlowOrganizePage()),
      GoRoute(
          path: '/ai/build-islands',
          builder: (_, __) => const AiBuildIslandsPage()),
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
        Positioned.fill(child: AtmosphereBackground()),
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

  @override
  Widget build(BuildContext context) {
    ref.read(activeTabIndexProvider.notifier).state =
        widget.navigationShell.currentIndex;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        showOverlaySnackBar(
          context,
          SnackBar(
            content: const Text('再按一次退出隙光'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 100),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: widget.navigationShell,
        bottomNavigationBar: _XiguangNavBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onTap: (i) {
            if (i == widget.navigationShell.currentIndex) {
              ref.read(scrollToTopSignalProvider.notifier).state++;
            } else {
              widget.navigationShell.goBranch(i, initialLocation: true);
            }
          },
        ),
      ),
    );
  }
}

/// 底部导航栏 — 隙 / 线 / 屿 / 我的
///
/// 选中态用滑动 pill 指示器，从旧 tab 平移到新 tab，不用淡入淡出。
class _XiguangNavBar extends ConsumerWidget {
  const _XiguangNavBar({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    ('assets/nav_icons/nav_gap.png', '隙', 'capture', 34.0, 28.0),
    ('assets/nav_icons/nav_thread.png', '线', 'timeline', 28.0, 23.0),
    ('assets/nav_icons/nav_island.png', '屿', 'universe', 34.0, 28.0),
    ('assets/nav_icons/nav_mine.png', '我的', 'mine', 34.0, 28.0),
  ];

  static const _pillHMargin = 4.0;
  static const _pillVMargin = 2.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nightMode = ref.watch(nightModeProvider);

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final navHeight = 78.0 + bottomInset;
    final navBottomPadding = bottomInset > 8 ? bottomInset : 8.0;
    return Container(
      height: navHeight,
      padding: EdgeInsets.fromLTRB(8, 6, 8, navBottomPadding),
      decoration: BoxDecoration(
        color: (nightMode ? const Color(0xFF172625) : const Color(0xFFFFFCF6))
            .withValues(alpha: nightMode ? .97 : .96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
              color: (nightMode ? Colors.black : const Color(0xFF23413F))
                  .withValues(alpha: nightMode ? .28 : .075),
              blurRadius: 30,
              spreadRadius: -8,
              offset: const Offset(0, -8))
        ],
        border: Border(
          top: BorderSide(
            color: nightMode
                ? AppColors.white.withValues(alpha: .10)
                : const Color(0xFFE4DDD0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        minimum: EdgeInsets.zero,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / _items.length;
            return Stack(
              children: [
                // 滑动 pill — 选中指示器在 tab 之间平移
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  left: selectedIndex * tabWidth + _pillHMargin,
                  top: _pillVMargin,
                  bottom: _pillVMargin,
                  child: Container(
                    width: tabWidth - _pillHMargin * 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFF72A58F)
                          .withValues(alpha: nightMode ? .24 : .16),
                      borderRadius: BorderRadius.circular(18),
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
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onTap(i),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 58),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            _NavIcon(
                              assetPath: _items[i].$1,
                              selected: selected,
                              nightMode: nightMode,
                              width: _items[i].$4,
                              height: _items[i].$5,
                            ),
                            const SizedBox(height: 4),
                            Text(_items[i].$2,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? (nightMode
                                            ? AppColors.white
                                            : const Color(0xFF233332))
                                        : (nightMode
                                            ? AppColors.white
                                                .withValues(alpha: .62)
                                            : const Color(0xFF78827D)))),
                          ]),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
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
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      opacity: selected
          ? const AlwaysStoppedAnimation(1)
          : AlwaysStoppedAnimation(nightMode ? .72 : .66),
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
