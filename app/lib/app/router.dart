import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/fragment/presentation/pages/capture_page.dart';
import '../features/timeline/presentation/pages/time_river_page.dart';
import '../features/starmap/presentation/widgets/starmap_page.dart';
import '../features/island/presentation/pages/universe_page.dart';
import '../features/space/presentation/pages/space_page.dart';

/// GoRouter + StatefulShellRoute.indexedStack
///
/// 四个底部 Tab 保持页面状态不销毁，用户切换不丢滚动位置/输入状态
GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/capture',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _AppShell(navigationShell),
        branches: [
          // Tab 1: 捕光
          StatefulShellBranch(routes: [
            GoRoute('/capture', builder: (_, __) => const CapturePage()),
            GoRoute('/fragments/:id', builder: (_, state) =>
              FragmentDetailPlaceholder(id: state.pathParameters['id']!)),
            GoRoute('/fragments/:id/edit', builder: (_, state) =>
              FragmentEditPlaceholder(id: state.pathParameters['id']!)),
          ]),
          // Tab 2: 时间河
          StatefulShellBranch(routes: [
            GoRoute('/timeline', builder: (_, __) => const TimeRiverPage()),
          ]),
          // Tab 3: 织线（星图）
          StatefulShellBranch(routes: [
            GoRoute('/weave', builder: (_, __) => const StarmapPage()),
            GoRoute('/weave/select', builder: (_, __) => const _SelectPlaceholder()),
          ]),
          // Tab 4: 小宇宙
          StatefulShellBranch(routes: [
            GoRoute('/universe', builder: (_, __) => const UniversePage()),
            GoRoute('/islands/:id', builder: (_, state) =>
              _IslandDetailPlaceholder(id: state.pathParameters['id']!)),
          ]),
        ],
      ),
      // 非 Tab 页面（全屏）
      GoRoute('/space', builder: (_, __) => const SpacePage()),
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
      bottomNavigationBar: _XiguangNavBar(
        selectedIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
      ),
    );
  }
}

/// 底部导航栏 — 捕光 / 时间河 / 织线 / 小宇宙
class _XiguangNavBar extends StatelessWidget {
  const _XiguangNavBar({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.edit_note_rounded, '捕光'),
      (Icons.timeline_rounded, '时间河'),
      (Icons.blur_circular_rounded, '织线'),
      (Icons.nights_stay_outlined, '小宇宙'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6).withValues(alpha: .94),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x1123413F), blurRadius: 28, offset: Offset(0, 16))],
        border: Border.all(color: const Color(0xFFE4DDD0)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (i) {
            final selected = selectedIndex == i;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF72A58F).withValues(alpha: .16) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(items[i].$1, size: 22,
                      color: selected ? const Color(0xFF72A58F) : const Color(0xFF78827D)),
                    const SizedBox(height: 4),
                    Text(items[i].$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: selected ? const Color(0xFF233332) : const Color(0xFF78827D))),
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

// ---- Placeholder pages below; replace with real implementations as features are built ----

class _SelectPlaceholder extends StatelessWidget {
  const _SelectPlaceholder();
  @override
  Widget build(_) => const Scaffold(body: Center(child: Text('选择目标光片 — 织线')));
}

class _IslandDetailPlaceholder extends StatelessWidget {
  const _IslandDetailPlaceholder({required this.id});
  final String id;
  @override
  Widget build(_) => Scaffold(body: Center(child: Text('岛详情: $id')));
}

class FragmentDetailPlaceholder extends StatelessWidget {
  const FragmentDetailPlaceholder({required this.id});
  final String id;
  @override
  Widget build(_) => Scaffold(body: Center(child: Text('光片详情: $id')));
}

class FragmentEditPlaceholder extends StatelessWidget {
  const FragmentEditPlaceholder({required this.id});
  final String id;
  @override
  Widget build(_) => Scaffold(body: Center(child: Text('编辑光片: $id')));
}
