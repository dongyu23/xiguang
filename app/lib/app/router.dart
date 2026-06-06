import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/fragment/presentation/pages/capture_page.dart';
import '../features/fragment/presentation/pages/fragment_detail_page.dart';
import '../features/fragment/presentation/pages/fragment_edit_page.dart';
import '../features/ai/presentation/pages/glow_organize_page.dart';
import '../features/timeline/presentation/pages/time_river_page.dart';
import '../features/island/presentation/pages/island_detail_page.dart';
import '../features/island/presentation/pages/universe_page.dart';
import '../features/space/presentation/pages/space_page.dart';
import '../features/starmap/presentation/widgets/starmap_page.dart';
import '../features/whitenoise/presentation/pages/whitenoise_page.dart';
import '../features/profile/presentation/pages/mine_page.dart';
import '../features/profile/presentation/pages/settings_page.dart';
import '../features/relation/presentation/pages/weave_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter + StatefulShellRoute.indexedStack
///
/// 四个底部 Tab 作为一级入口；光片详情/织线保留为上下文页面。
GoRouter createRouter(WidgetRef ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final signedIn = ref.read(authSessionProvider) != null;
      final path = state.uri.path;
      final isAuthRoute = path == '/login' || path == '/register';
      if (!signedIn && !isAuthRoute) return '/login';
      if (signedIn && isAuthRoute) return '/capture';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell),
        branches: [
          // Tab 1: 捕光
          StatefulShellBranch(routes: [
            GoRoute(path: '/capture', builder: (_, __) => const CapturePage()),
            GoRoute(
                path: '/fragments/:id',
                builder: (_, state) =>
                    FragmentDetailPage(id: state.pathParameters['id']!)),
            GoRoute(
                path: '/fragments/:id/edit',
                builder: (_, state) =>
                    FragmentEditPage(id: state.pathParameters['id']!)),
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
                path: '/islands/:id',
                builder: (_, state) =>
                    IslandDetailPage(id: state.pathParameters['id']!)),
          ]),
          // Tab 4: 我的
          StatefulShellBranch(routes: [
            GoRoute(path: '/mine', builder: (_, __) => const MinePage()),
            GoRoute(
                path: '/settings', builder: (_, __) => const SettingsPage()),
          ]),
        ],
      ),
      // 非 Tab 页面（全屏）
      GoRoute(path: '/space', builder: (_, __) => const SpacePage()),
      GoRoute(path: '/starmap', builder: (_, __) => const StarmapPage()),
      GoRoute(path: '/whitenoise', builder: (_, __) => const WhiteNoisePage()),
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
          parentNavigatorKey: _rootNavigatorKey,
          path: '/fragment-detail/:id',
          redirect: (_, state) => '/fragments/${state.pathParameters['id']}'),
    ],
  );
}

/// 底部导航骨架
class _AppShell extends StatelessWidget {
  const _AppShell(this.navigationShell);
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: navigationShell.currentIndex == 3
          ? null
          : FloatingActionButton.extended(
              onPressed: () => navigationShell.goBranch(0),
              icon: const Icon(Icons.wb_sunny_outlined),
              label: const Text('捕光'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _XiguangNavBar(
        selectedIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(i,
            initialLocation: i == navigationShell.currentIndex),
      ),
    );
  }
}

/// 底部导航栏 — 隙 / 线 / 屿 / 我的
class _XiguangNavBar extends StatelessWidget {
  const _XiguangNavBar({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.edit_note_rounded, '隙', 'capture'),
      (Icons.timeline_rounded, '线', 'timeline'),
      (Icons.nights_stay_outlined, '屿', 'universe'),
      (Icons.person_outline_rounded, '我的', 'mine'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6).withValues(alpha: .94),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1123413F), blurRadius: 28, offset: Offset(0, 16))
        ],
        border: Border.all(color: const Color(0xFFE4DDD0)),
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
                        ? const Color(0xFF72A58F).withValues(alpha: .16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(items[i].$1,
                        size: 22,
                        color: selected
                            ? const Color(0xFF72A58F)
                            : const Color(0xFF78827D)),
                    const SizedBox(height: 4),
                    Text(items[i].$2,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? const Color(0xFF233332)
                                : const Color(0xFF78827D))),
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

class FragmentEditPlaceholder extends StatelessWidget {
  const FragmentEditPlaceholder({super.key, required this.id});
  final String id;
  @override
  Widget build(_) => Scaffold(body: Center(child: Text('编辑光片: $id')));
}
