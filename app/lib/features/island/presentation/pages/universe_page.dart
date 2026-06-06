import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../data/island_repository.dart';
import '../../../../ui/composites/night_mode_button.dart';
import '../../../../ui/spaces/space_canvas.dart';

/// 小宇宙页 — 主题岛、星点、柔光整理入口
class UniversePage extends ConsumerWidget {
  const UniversePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final islands = ref.watch(islandsProvider);
    final nightMode = ref.watch(nightModeProvider);
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 104),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(nightMode: nightMode),
                    const SizedBox(height: 20),
                    islands.when(
                      data: (items) => _UniverseSkyBanner(islands: items),
                      loading: () => const _UniverseSkyBanner(),
                      error: (_, __) => const _UniverseSkyBanner(),
                    ),
                    const SizedBox(height: 20),
                    _RelationLedgerPanel(nightMode: nightMode),
                    const SizedBox(height: 12),
                    _CreateIslandPanel(nightMode: nightMode),
                    const SizedBox(height: 18),
                    _SectionTitle(
                      title: '我的小岛',
                      nightMode: nightMode,
                    ),
                    const SizedBox(height: 12),
                    islands.when(
                      data: (items) => _TopicIslandGrid(
                        items: items,
                        nightMode: nightMode,
                      ),
                      loading: () => _TopicIslandGrid(
                        items: const [],
                        nightMode: nightMode,
                      ),
                      error: (_, __) => _TopicIslandGrid(
                        items: const [],
                        nightMode: nightMode,
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PRIVATE SKY', style: AppText.onNight(AppText.eyebrow, nightMode)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: Text('屿', style: AppText.onNight(AppText.hero, nightMode)),
        ),
        const NightModeButton(),
      ]),
      const SizedBox(height: 8),
      Text(
        '标签、情绪和旧光慢慢连成一张只属于你的星图。',
        style: AppText.onNight(AppText.body, nightMode),
      ),
    ]);
  }
}

class _UniverseSkyBanner extends StatefulWidget {
  const _UniverseSkyBanner({this.islands = const []});

  final List<IslandModel> islands;

  @override
  State<_UniverseSkyBanner> createState() => _UniverseSkyBannerState();
}

class _UniverseSkyBannerState extends State<_UniverseSkyBanner>
    with TickerProviderStateMixin {
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.islands;

    return Container(
      height: 276,
      decoration: softDecoration(AppColors.ink)
          .copyWith(gradient: AppColors.gradientNight),
      child: Stack(children: [
        // Data-driven star map
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _breathe,
            builder: (_, __) => CustomPaint(
              painter: _UniversePainter(
                islands: items,
                breathe: _breathe.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        // Island name labels
        if (items.isNotEmpty)
          Positioned.fill(
            child: _IslandLabels(islands: items),
          ),
        // Top bar
        Positioned(
            left: 20,
            top: 18,
            right: 20,
            child: Text('小宇宙', style: AppText.inverseTitle)),
        // Bottom actions
        Positioned(
            left: 20,
            bottom: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (items.isEmpty)
                  Text('第一座小岛会在这里亮起。', style: AppText.inverseBody)
                else
                  Text(
                    '每一座小岛，都先安静地发着自己的光。',
                    style: AppText.inverseBody,
                  ),
                const SizedBox(height: 12),
              ],
            )),
      ]),
    );
  }
}

/// Data-driven star map painter — each island is a glowing star.
class _UniversePainter extends CustomPainter {
  _UniversePainter({required this.islands, required this.breathe});

  final List<IslandModel> islands;
  final double breathe;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Background star dust
    final dustPaint = Paint()
      ..color = AppColors.white.withValues(alpha: .08 + breathe * .04);
    final rng = Random(17);
    for (var i = 0; i < 40; i++) {
      final x = (rng.nextDouble() * 0.9 + 0.05) * size.width;
      final y = (rng.nextDouble() * 0.85 + 0.05) * size.height;
      final r = (rng.nextDouble() * 1.4 + 0.4) * (1 + breathe * 0.3);
      canvas.drawCircle(Offset(x, y), r, dustPaint);
    }

    if (islands.isEmpty) {
      // Empty state: single soft glow at center
      final emptyGlow = Paint()
        ..shader = RadialGradient(colors: [
          AppColors.white.withValues(alpha: .12 + breathe * .04),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: center, radius: 80));
      canvas.drawCircle(center, 80, emptyGlow);
      return;
    }

    // Position islands in a gentle spiral from center
    final points = <_IslandPoint>[];
    for (var i = 0; i < islands.length; i++) {
      final angle = i * 2.4 + 0.5; // golden-angle-ish spiral
      final dist = 50.0 + i * 38.0;
      final x = center.dx + cos(angle) * dist;
      final y = center.dy + sin(angle) * dist;
      points.add(_IslandPoint(
        x: x.clamp(30, size.width - 30),
        y: y.clamp(30, size.height - 50),
        radius: 7.0 + islands[i].fragmentCount.clamp(0, 8) * 1.2,
        color: AppColors.emotionColor(islands[i].name),
        name: islands[i].name,
        status: islands[i].status,
        fragmentCount: islands[i].fragmentCount,
      ));
    }

    // Draw subtle connecting lines between nearby islands
    final linePaint = Paint()
      ..color = AppColors.white.withValues(alpha: .10)
      ..strokeWidth = 0.7;
    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        final dx = points[i].x - points[j].x;
        final dy = points[i].y - points[j].y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < 160) {
          final alpha = (1 - dist / 160) * 0.16;
          linePaint.color = AppColors.white.withValues(alpha: alpha);
          canvas.drawLine(
            Offset(points[i].x, points[i].y),
            Offset(points[j].x, points[j].y),
            linePaint,
          );
        }
      }
    }

    // Draw each star
    for (final pt in points) {
      final glowAlpha = 0.14 + breathe * 0.06;
      final glowPaint = Paint()
        ..shader = RadialGradient(colors: [
          pt.color.withValues(alpha: glowAlpha * 2),
          pt.color.withValues(alpha: glowAlpha),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(
            center: Offset(pt.x, pt.y), radius: pt.radius * 3.0));
      canvas.drawCircle(Offset(pt.x, pt.y), pt.radius * 3.0, glowPaint);

      // Outer halo
      final haloPaint = Paint()
        ..color = AppColors.white.withValues(alpha: .18 + breathe * .08);
      canvas.drawCircle(Offset(pt.x, pt.y), pt.radius + 2.6, haloPaint);

      // Core
      final corePaint = Paint()..color = pt.color.withValues(alpha: .9);
      canvas.drawCircle(Offset(pt.x, pt.y), pt.radius, corePaint);

      // Bright center
      final brightPaint = Paint()
        ..color = AppColors.white.withValues(alpha: .72 + breathe * .12);
      canvas.drawCircle(Offset(pt.x, pt.y), pt.radius * 0.35, brightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _UniversePainter old) =>
      old.breathe != breathe || old.islands != islands;
}

class _IslandPoint {
  final double x, y;
  final double radius;
  final Color color;
  final String name;
  final String status;
  final int fragmentCount;

  _IslandPoint({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.name,
    required this.status,
    required this.fragmentCount,
  });
}

/// Subtle island name labels positioned near their stars.
class _IslandLabels extends StatelessWidget {
  const _IslandLabels({required this.islands});
  final List<IslandModel> islands;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final center = Offset(
      (size.width - 40) / 2,
      (size.height - 50) / 2,
    );
    return Stack(
      children: List.generate(islands.length, (i) {
        final angle = i * 2.4 + 0.5;
        final dist = 50.0 + i * 38.0;
        final x = center.dx + cos(angle) * dist - 40;
        final y = center.dy + sin(angle) * dist + 18;
        return Positioned(
          left: x.clamp(0, size.width - 100),
          top: y.clamp(0, size.height - 30),
          child: GestureDetector(
            onTap: () => context.push(_islandDetailPath(islands[i])),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(
                islands[i].name,
                style: AppText.inverseBody.copyWith(
                  fontSize: 10,
                  color: AppColors.white.withValues(alpha: .68),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CreateIslandPanel extends StatelessWidget {
  const _CreateIslandPanel({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/islands/create'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: nightMode
            ? _nightPanelDecoration()
            : softDecoration(AppColors.white),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.sunsetCoral
                  .withValues(alpha: nightMode ? .24 : .16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: nightMode
                    ? AppColors.white.withValues(alpha: .12)
                    : AppColors.sunsetCoral.withValues(alpha: .24),
              ),
            ),
            child: Icon(
              Icons.add_location_alt_outlined,
              color: nightMode ? AppText.nightInk : AppColors.ink,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('创建小岛',
                  style: AppText.onNight(AppText.titleMedium, nightMode)),
              const SizedBox(height: 3),
              Text(
                '以一方小岛，安放细碎情绪。',
                style: AppText.onNight(AppText.bodyMuted, nightMode),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.chevron_right_rounded,
            color: nightMode ? AppText.nightInkMuted : AppColors.inkMuted,
          ),
        ]),
      ),
    );
  }
}

class _RelationLedgerPanel extends StatelessWidget {
  const _RelationLedgerPanel({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/relations/ledger'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: nightMode
            ? _nightPanelDecoration()
            : softDecoration(AppColors.white),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.teaGreen.withValues(alpha: nightMode ? .24 : .14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: nightMode
                    ? AppColors.white.withValues(alpha: .12)
                    : AppColors.teaGreen.withValues(alpha: .24),
              ),
            ),
            child: Icon(
              Icons.account_tree_outlined,
              color: nightMode ? AppText.nightInk : AppColors.ink,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('查看已织线',
                  style: AppText.onNight(AppText.titleMedium, nightMode)),
              const SizedBox(height: 3),
              Text(
                '回看已经确认过的光与光之间的关系。',
                style: AppText.onNight(AppText.bodyMuted, nightMode),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.chevron_right_rounded,
            color: nightMode ? AppText.nightInkMuted : AppColors.inkMuted,
          ),
        ]),
      ),
    );
  }
}

class _TopicIsland extends StatelessWidget {
  const _TopicIsland({
    required this.island,
    required this.width,
    required this.nightMode,
    this.onTap,
  });
  final IslandModel island;
  final double width;
  final bool nightMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.emotionColor(island.name);
    final count = island.fragmentCount.clamp(1, 8);
    final statusLabel = _islandStatusLabel(island);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
          width: width,
          padding: const EdgeInsets.all(14),
          decoration: nightMode
              ? _nightPanelDecoration()
              : softDecoration(AppColors.white),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _IslandGlyph(
                color: color,
                size: 34 + count * 4,
                nightMode: nightMode,
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  size: 18,
                  color: nightMode
                      ? AppText.nightInkMuted.withValues(alpha: .72)
                      : AppColors.inkMuted.withValues(alpha: .72)),
            ]),
            const SizedBox(height: 12),
            Text('#${island.name}',
                style: AppText.onNight(AppText.titleSmall, nightMode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 7),
            _TopicStatusPill(status: island.status, nightMode: nightMode),
            const SizedBox(height: 8),
            Text(
              statusLabel,
              style: AppText.onNight(AppText.caption, nightMode),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ])),
    );
  }

  static String _islandStatusLabel(IslandModel island) {
    final count = island.fragmentCount;
    return switch (island.status) {
      'formed' => '$count 条记录已织出线索',
      'growing' => '$count 条记录，线索正在生长',
      _ => '$count 条记录，星点正在靠近',
    };
  }
}

class _IslandGlyph extends StatelessWidget {
  const _IslandGlyph({
    required this.color,
    required this.size,
    required this.nightMode,
  });

  final Color color;
  final double size;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IslandGlyphPainter(
          color: color,
          ink: nightMode ? AppText.nightInk : AppColors.ink,
        ),
      ),
    );
  }
}

class _IslandGlyphPainter extends CustomPainter {
  const _IslandGlyphPainter({required this.color, required this.ink});

  final Color color;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final wash = Paint()
      ..color = color.withValues(alpha: .62)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, wash);

    final stroke = Paint()
      ..color = AppColors.white.withValues(alpha: .88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.6, radius * .08)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final land = Path()
      ..moveTo(size.width * .22, size.height * .68)
      ..quadraticBezierTo(
        size.width * .40,
        size.height * .58,
        size.width * .56,
        size.height * .66,
      )
      ..quadraticBezierTo(
        size.width * .70,
        size.height * .73,
        size.width * .82,
        size.height * .62,
      );
    canvas.drawPath(land, stroke);

    final trunkBase = Offset(size.width * .50, size.height * .63);
    final trunkTop = Offset(size.width * .54, size.height * .38);
    canvas.drawLine(trunkBase, trunkTop, stroke);

    final leafLeft = Path()
      ..moveTo(trunkTop.dx, trunkTop.dy)
      ..quadraticBezierTo(
        size.width * .36,
        size.height * .31,
        size.width * .28,
        size.height * .42,
      );
    final leafMid = Path()
      ..moveTo(trunkTop.dx, trunkTop.dy)
      ..quadraticBezierTo(
        size.width * .55,
        size.height * .22,
        size.width * .67,
        size.height * .34,
      );
    final leafRight = Path()
      ..moveTo(trunkTop.dx, trunkTop.dy)
      ..quadraticBezierTo(
        size.width * .72,
        size.height * .35,
        size.width * .75,
        size.height * .49,
      );
    canvas.drawPath(leafLeft, stroke);
    canvas.drawPath(leafMid, stroke);
    canvas.drawPath(leafRight, stroke);

    final shadow = Paint()
      ..color = ink.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, radius * .05)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * .48, size.height * .78),
        width: size.width * .46,
        height: size.height * .12,
      ),
      .08,
      pi * .82,
      false,
      shadow,
    );
  }

  @override
  bool shouldRepaint(covariant _IslandGlyphPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.ink != ink;
  }
}

class _TopicIslandGrid extends StatelessWidget {
  const _TopicIslandGrid({required this.items, required this.nightMode});

  final List<IslandModel> items;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: nightMode
            ? _nightPanelDecoration()
            : softDecoration(AppColors.white),
        child: Text(
          '留下第一束光后，真实的小岛会在这里出现。',
          style: AppText.onNight(AppText.bodyMuted, nightMode),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map((island) => _TopicIsland(
                    island: island,
                    width: width,
                    nightMode: nightMode,
                    onTap: () => context.push(_islandDetailPath(island)),
                  ))
              .toList(),
        );
      },
    );
  }
}

String _islandDetailPath(IslandModel island) {
  final routeId = island.islandId > 0 ? '${island.islandId}' : island.name;
  return '/islands/${Uri.encodeComponent(routeId)}';
}

class _TopicStatusPill extends StatelessWidget {
  const _TopicStatusPill({required this.status, required this.nightMode});

  final String status;
  final bool nightMode;

  bool get _isFormed => status == 'formed';
  bool get _isGrowing => status == 'growing';

  @override
  Widget build(BuildContext context) {
    final bool active = _isFormed || _isGrowing;
    final String label;
    final IconData icon;
    if (_isFormed) {
      label = '已成岛';
      icon = Icons.terrain_outlined;
    } else if (_isGrowing) {
      label = '生长中';
      icon = Icons.auto_awesome_outlined;
    } else {
      label = '正在靠近';
      icon = Icons.motion_photos_on_outlined;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: nightMode
            ? (active
                ? AppColors.teaGreen.withValues(alpha: .18)
                : AppColors.white.withValues(alpha: .08))
            : (active
                ? AppColors.teaGreen.withValues(alpha: .14)
                : AppColors.paper.withValues(alpha: .88)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: nightMode
              ? (active
                  ? AppColors.teaGreen.withValues(alpha: .34)
                  : AppColors.white.withValues(alpha: .12))
              : (active
                  ? AppColors.teaGreen.withValues(alpha: .32)
                  : AppColors.line),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          icon,
          size: 13,
          color: active
              ? (nightMode ? AppText.nightAccent : AppColors.teaGreen)
              : (nightMode ? AppText.nightInkMuted : AppColors.inkMuted),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppText.caption.copyWith(
            height: 1,
            fontWeight: FontWeight.w700,
            color: active
                ? (nightMode ? AppText.nightAccent : AppColors.teaGreen)
                : (nightMode ? AppText.nightInkMuted : AppColors.inkMuted),
          ),
        ),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.nightMode});

  final String title;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppText.onNight(AppText.titleMedium, nightMode));
  }
}

BoxDecoration _nightPanelDecoration() {
  return BoxDecoration(
    color: const Color(0xFF213433).withValues(alpha: .78),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppColors.white.withValues(alpha: .13)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .16),
        blurRadius: 24,
        offset: const Offset(0, 14),
      ),
    ],
  );
}
