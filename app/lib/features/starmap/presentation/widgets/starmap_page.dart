import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/primitives/night_background.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../domain/star_graph.dart';
import '../providers/starmap_provider.dart';

/// 星图页 — 可视化个人关系图
///
/// 星点可拖拽建立连线。第一版用 StarrySpace + InteractiveViewer。
/// ⚠️ 手势冲突：双指→InteractiveViewer(缩放平移)；单指拖星点→GestureDetector
class StarmapPage extends ConsumerWidget {
  const StarmapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph = ref.watch(starGraphProvider);
    final nightMode = ref.watch(nightModeProvider);
    return Stack(children: [
      const Positioned.fill(child: NightBackgroundPlaceholder()),
      const Positioned.fill(child: AtmosphereBackground()),
      SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.s22, AppSpacing.s18,
              AppSpacing.s22, AppSpacing.pageBottomNav),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      nightMode: nightMode,
                      onExit: () => _exit(context),
                    ),
                    const SizedBox(height: AppSpacing.s20),
                    graph.when(
                      data: (value) => _GraphPanel(graph: value),
                      loading: () => Container(
                        height: 380,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          gradient: AppColors.gradientNight,
                        ),
                        child: const CircularProgressIndicator(),
                      ),
                      error: (_, __) => Text('星图暂时无法展开，请稍后再试。',
                          style: AppText.onNight(AppText.body, nightMode)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('这里展示已经确认的织线关系。',
                        style: AppText.onNight(AppText.bodyMuted, nightMode)),
                  ]),
            ),
          ),
        ),
      ),
    ]);
  }

  void _exit(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/universe');
  }
}

class _GraphPanel extends StatelessWidget {
  const _GraphPanel({required this.graph});

  final StarGraph graph;

  @override
  Widget build(BuildContext context) {
    if (graph.nodes.isEmpty) {
      return Container(
        height: 380,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          gradient: AppColors.gradientNight,
        ),
        child: Text('先留下几束光，星图会慢慢亮起来。', style: AppText.inverseBody),
      );
    }
    return Container(
      height: 380,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: AppColors.gradientNight,
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _GraphPainter(graph),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter(this.graph);

  final StarGraph graph;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final positions = <int, Offset>{};
    for (final node in graph.nodes) {
      positions[node.fragmentId] = center + Offset(node.x, node.y) * .72;
    }
    final edgePaint = Paint()
      ..color = AppColors.white.withValues(alpha: .26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final edge in graph.edges) {
      final source = positions[edge.sourceId];
      final target = positions[edge.targetId];
      if (source == null || target == null) continue;
      final control = Offset(
        (source.dx + target.dx) / 2,
        (source.dy + target.dy) / 2 - 24,
      );
      final path = Path()
        ..moveTo(source.dx, source.dy)
        ..quadraticBezierTo(control.dx, control.dy, target.dx, target.dy);
      canvas.drawPath(path, edgePaint);
    }
    final glowPaint = Paint()..color = AppColors.white.withValues(alpha: .2);
    final nodePaint = Paint()..color = AppColors.white.withValues(alpha: .86);
    for (final entry in positions.entries) {
      canvas.drawCircle(entry.value, 15, glowPaint);
      canvas.drawCircle(entry.value, 5, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      oldDelegate.graph != graph;
}

class _Header extends StatelessWidget {
  const _Header({required this.nightMode, required this.onExit});

  final bool nightMode;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text('STARMAP',
              style: AppText.onNight(AppText.eyebrow, nightMode)),
        ),
        PageBackButton(nightMode: nightMode, onTap: onExit),
      ]),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        Expanded(
          child: Text('星图', style: AppText.onNight(AppText.hero, nightMode)),
        ),
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: nightMode
                    ? AppColors.white.withValues(alpha: .10)
                    : AppColors.white.withValues(alpha: .86),
                shape: BoxShape.circle),
            child: Icon(Icons.blur_circular_rounded,
                color: nightMode ? AppColors.nightInk : AppColors.ink)),
      ]),
      const SizedBox(height: AppSpacing.sm),
      Text('旧光之间的联系，在这里慢慢亮起来。',
          style: AppText.onNight(AppText.body, nightMode)),
    ]);
  }
}

// _ExitButton 已删除，统一使用 lib/ui/primitives/page_back_button.dart 的 PageBackButton。

