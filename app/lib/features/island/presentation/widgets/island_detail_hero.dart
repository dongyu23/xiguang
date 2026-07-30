import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../domain/island_visual_stage.dart';
import '../../domain/universe_overview.dart';
import 'island_sprite_visual.dart';

class IslandDetailHero extends StatefulWidget {
  const IslandDetailHero({
    super.key,
    required this.island,
    required this.onAdd,
  });

  final IslandVisualNode island;
  final VoidCallback? onAdd;

  @override
  State<IslandDetailHero> createState() => _IslandDetailHeroState();
}

class _IslandDetailHeroState extends State<IslandDetailHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(vsync: this, duration: AppMotion.breath)
      ..repeat();
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final node = widget.island;
    final stage = node.visualStage;

    return Column(
      children: [
        SizedBox(
          key: const ValueKey('island-detail-hero'),
          height: 250,
          child: AnimatedBuilder(
            animation: _breathe,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _IslandWaterPainter(
                        progress: _breathe.value,
                        theme: theme,
                      ),
                    ),
                  ),
                  Semantics(
                    image: true,
                    label: '${node.island.name}的小岛俯视图',
                    child: Hero(
                      tag: islandHeroTag(node),
                      createRectTween: islandHeroRectTween,
                      flightShuttleBuilder: islandHeroFlightShuttle(node),
                      placeholderBuilder: islandHeroPlaceholder,
                      transitionOnUserGestures: true,
                      child: IslandSpriteVisual(
                        island: node,
                        width: 228,
                        height: 228,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        Text(
          node.island.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.subHero.copyWith(color: theme.foreground),
        ),
        const SizedBox(height: AppSpacing.s10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatusDot(color: _stageColor(stage, theme)),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${_stageLabel(stage)} · ${node.fragmentCount} 束光',
              style: AppText.bodyMuted.copyWith(color: theme.foregroundMuted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s18),
        if (node.island.manual)
          FilledButton.icon(
            key: const ValueKey('island-detail-add'),
            onPressed: widget.onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(node.fragments.isEmpty ? '放入第一束光' : '添加一束光'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
              backgroundColor: theme.accent,
              foregroundColor: theme.background,
              shape: const StadiumBorder(),
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 15, color: theme.foregroundMuted),
              const SizedBox(width: AppSpacing.s6),
              Text(
                '随同主题的光自然生长',
                style: AppText.caption.copyWith(color: theme.foregroundMuted),
              ),
            ],
          ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .45), blurRadius: 8),
        ],
      ),
    );
  }
}

class _IslandWaterPainter extends CustomPainter {
  const _IslandWaterPainter({required this.progress, required this.theme});

  final double progress;
  final NightTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .51);
    final glowBounds = Rect.fromCircle(center: center, radius: 118);
    canvas.drawCircle(
      center,
      118,
      Paint()
        ..shader = RadialGradient(
          colors: [
            theme.accent.withValues(alpha: theme.isNight ? .12 : .10),
            theme.accent.withValues(alpha: 0),
          ],
        ).createShader(glowBounds),
    );

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = theme.foregroundMuted.withValues(
        alpha: theme.isNight ? .10 : .13,
      );
    for (var ring = 0; ring < 3; ring++) {
      final pulse = math.sin(progress * math.pi * 2 + ring) * 3;
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: 205 + ring * 52 + pulse,
          height: 82 + ring * 25 + pulse * .35,
        ),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IslandWaterPainter oldDelegate) =>
      progress != oldDelegate.progress || theme != oldDelegate.theme;
}

String _stageLabel(IslandVisualStage stage) {
  return switch (stage) {
    IslandVisualStage.shoal => '初生浅滩',
    IslandVisualStage.sprouting => '开始生长',
    IslandVisualStage.growing => '渐成聚落',
    IslandVisualStage.formed => '已成岛',
    IslandVisualStage.dormant => '静静休眠',
    IslandVisualStage.relit => '重新亮起',
  };
}

Color _stageColor(IslandVisualStage stage, NightTheme theme) {
  return switch (stage) {
    IslandVisualStage.dormant => theme.foregroundMuted,
    IslandVisualStage.relit => AppColors.islandRelitGold,
    _ => theme.accent,
  };
}
