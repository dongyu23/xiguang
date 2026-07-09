import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../data/island_repository.dart';
import '../../../../ui/composites/settings_widgets.dart';
import '../../../../ui/primitives/scroll_to_top.dart';

/// 小宇宙页 — 主题岛、星点、柔光整理入口
class UniversePage extends ConsumerWidget {
  const UniversePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final islands = ref.watch(islandsProvider);
    final nightMode = ref.watch(nightModeProvider);
    return Stack(children: [
      // C2: Background now provided by _AppShell in router.dart
      SafeArea(
        child: ScrollToTop(
          builder: (context, controller) => SingleChildScrollView(
            controller: controller,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(22, 18, 22,
                64 + 10 + MediaQuery.paddingOf(context).bottom + 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(nightMode: nightMode),
                      const SizedBox(height: AppSpacing.s20),
                      islands.when(
                        data: (items) => _UniverseOverview(
                          islands: items,
                          nightMode: nightMode,
                        ),
                        loading: () => _UniverseOverviewSkeleton(
                          nightMode: nightMode,
                        ),
                        error: (_, __) => _UniverseOverviewSkeleton(
                          nightMode: nightMode,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s18),
                      _SectionTitle(
                        title: '我的小岛',
                        nightMode: nightMode,
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      islands.when(
                        data: (items) => _TopicIslandGrid(
                          items: items,
                          nightMode: nightMode,
                        ),
                        loading: () => _TopicIslandGridSkeleton(
                          nightMode: nightMode,
                        ),
                        error: (_, __) => _TopicIslandGridSkeleton(
                          nightMode: nightMode,
                        ),
                      ),
                    ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _UniverseOverview extends StatelessWidget {
  const _UniverseOverview({
    required this.islands,
    required this.nightMode,
  });

  final List<IslandModel> islands;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _UniverseSkyBanner(islands: islands),
      const SizedBox(height: AppSpacing.s12),
      _IslandSnapshotPanel(islands: islands, nightMode: nightMode),
      const SizedBox(height: AppSpacing.s12),
      _IslandToolsRow(nightMode: nightMode),
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
      const SizedBox(height: AppSpacing.sm),
      Text('屿', style: AppText.onNight(AppText.hero, nightMode)),
      const SizedBox(height: AppSpacing.sm),
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
      duration: AppMotion.breath,
    );
    // 延迟一帧启动动画，避免首帧卡顿
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _breathe.repeat();
    });
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
      height: 218,
      decoration: softDecoration(AppColors.ink)
          .copyWith(gradient: AppColors.gradientNight),
      child: Stack(children: [
        // Data-driven star map
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _breathe,
            builder: (_, __) => RepaintBoundary(
              child: CustomPaint(
                painter: _UniversePainter(
                  islands: items,
                  breathe: _breathe.value,
                ),
                child: const SizedBox.expand(),
              ),
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
            bottom: 18,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                    child: Text(
                      items.isEmpty ? '第一座小岛会在这里亮起。' : '每一座小岛，都先安静地发着自己的光。',
                      style: AppText.inverseBody,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/glow-organize'),
                    icon: const Icon(Icons.auto_awesome_outlined, size: 15),
                    label: const Text('柔光整理'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: BorderSide(
                          color: AppColors.white.withValues(alpha: .28)),
                      backgroundColor:
                          AppColors.white.withValues(alpha: .10),
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s11),
                      textStyle: AppText.captionStrong,
                    ),
                  ),
                ]),
              ],
            )),
      ]),
    );
  }
}

// _SkyActionButton 已弃用，调用方现已直接使用 OutlinedButton.icon。


class _IslandSnapshotPanel extends StatelessWidget {
  const _IslandSnapshotPanel({
    required this.islands,
    required this.nightMode,
  });

  final List<IslandModel> islands;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    final totalFragments =
        islands.fold<int>(0, (sum, island) => sum + island.fragmentCount);
    final formedCount =
        islands.where((island) => island.status == 'formed').length;
    final growingCount =
        islands.where((island) => island.status == 'growing').length;
    final leadingIsland = islands.isEmpty
        ? null
        : ([...islands]
              ..sort((a, b) => b.fragmentCount.compareTo(a.fragmentCount)))
            .first;
    final foreground = nightMode ? AppText.nightInk : AppColors.ink;
    final muted = nightMode ? AppText.nightInkMuted : AppColors.inkMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s14, AppSpacing.s12, AppSpacing.s14, AppSpacing.s12),
      decoration:
          nightMode ? nightDecoration() : softDecoration(AppColors.white),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.teaGreen.withValues(alpha: nightMode ? .20 : .14),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            Icons.auto_stories_outlined,
            size: 19,
            color: nightMode ? AppText.nightAccent : AppColors.teaGreen,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              islands.isEmpty
                  ? '小岛还在等第一束光'
                  : '${islands.length} 座小岛 · $totalFragments 束光',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.titleSmall.copyWith(color: foreground),
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              leadingIsland == null
                  ? '捕光时加上标签，小岛会自然浮现。'
                  : '最亮：#${leadingIsland.name} · 已成岛 $formedCount · 生长中 $growingCount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: muted),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _IslandToolsRow extends StatelessWidget {
  const _IslandToolsRow({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 10.0;
      final columns = constraints.maxWidth >= 460 ? 3 : 2;
      final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          SizedBox(
            width: itemWidth,
            child: SettingsNavRow(
              icon: Icons.account_tree_outlined,
              iconColor: AppColors.teaGreen,
              label: '已织线',
              subtitle: '关系账本',
              nightMode: nightMode,
              compact: true,
              onTap: () => context.push('/relations/ledger'),
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: SettingsNavRow(
              icon: Icons.blur_circular_rounded,
              iconColor: AppColors.mistBlue,
              label: '星图',
              subtitle: '关系可视化',
              nightMode: nightMode,
              compact: true,
              onTap: () => context.push('/starmap'),
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: SettingsNavRow(
              icon: Icons.add_location_alt_outlined,
              iconColor: AppColors.sunsetCoral,
              label: '新小岛',
              subtitle: '手动安放',
              nightMode: nightMode,
              compact: true,
              onTap: () => context.push('/islands/create'),
            ),
          ),
        ],
      );
    });
  }
}

// _IslandToolButton 已删除，统一用 SettingsNavRow（ui/composites/settings_widgets.dart）。
// _SkyActionButton 已删除，统一用 OutlinedButton.icon。

/// Data-driven star map painter — each island is a glowing star.
const double _skyBottomSafeZone = 104;
const double _skyTopSafeZone = 42;

class _UniversePainter extends CustomPainter {
  _UniversePainter({required this.islands, required this.breathe});

  final List<IslandModel> islands;
  final double breathe;

  // 复用 Random 实例和 Paint 对象，避免每帧分配
  static final _rng = Random(17);
  static final _dustPaint = Paint();
  static final _linePaint = Paint()..strokeWidth = 0.7;
  static final _haloPaint = Paint();
  static final _corePaint = Paint();
  static final _brightPaint = Paint();
  static final _emptyGlowPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Background star dust
    _dustPaint.color = AppColors.white.withValues(alpha: .08 + breathe * .04);
    // 重置随机种子以保证确定性输出
    final rng = _rng;
    for (var i = 0; i < 40; i++) {
      final x = (rng.nextDouble() * 0.9 + 0.05) * size.width;
      final y = (rng.nextDouble() * 0.85 + 0.05) * size.height;
      final r = (rng.nextDouble() * 1.4 + 0.4) * (1 + breathe * 0.3);
      canvas.drawCircle(Offset(x, y), r, _dustPaint);
    }

    if (islands.isEmpty) {
      // Empty state: single soft glow at center — reuse cached paint
      _emptyGlowPaint.shader = RadialGradient(colors: [
        AppColors.white.withValues(alpha: .12 + breathe * .04),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: center, radius: 80));
      canvas.drawCircle(center, 80, _emptyGlowPaint);
      return;
    }

    // Position islands in a gentle spiral from center
    final points = <_IslandPoint>[];
    for (var i = 0; i < islands.length; i++) {
      final angle = i * 2.4 + 0.5; // golden-angle-ish spiral
      final dist = 50.0 + i * 38.0;
      final x = center.dx + cos(angle) * dist;
      final y = center.dy + sin(angle) * dist;
      final maxStarY = max(_skyTopSafeZone, size.height - _skyBottomSafeZone);
      points.add(_IslandPoint(
        x: x.clamp(30, size.width - 30),
        y: y.clamp(_skyTopSafeZone, maxStarY),
        radius: 7.0 + islands[i].fragmentCount.clamp(0, 8) * 1.2,
        color: AppColors.emotionColor(islands[i].name),
        name: islands[i].name,
        status: islands[i].status,
        fragmentCount: islands[i].fragmentCount,
      ));
    }

    // Draw subtle connecting lines between nearby islands
    // 缓存连线对：只在岛屿列表变化时重算，不在每帧做 O(n²)
    final pairs = _cachedLinePairs(points, islands, size);
    for (final pair in pairs) {
      _linePaint.color = AppColors.white.withValues(alpha: pair.alpha);
      canvas.drawLine(
        Offset(pair.x1, pair.y1),
        Offset(pair.x2, pair.y2),
        _linePaint,
      );
    }

    // Draw each star — 复用静态 Paint 对象
    final glowAlpha = 0.14 + breathe * 0.06;
    final haloAlpha = .18 + breathe * .08;
    final brightAlpha = .72 + breathe * .12;

    // H2: Reuse a single Paint object for glow across all islands
    final glowPaint = Paint();
    for (final pt in points) {
      // Glow — reuse Paint, only update shader per island
      glowPaint.shader = RadialGradient(colors: [
        pt.color.withValues(alpha: glowAlpha * 2),
        pt.color.withValues(alpha: glowAlpha),
        Colors.transparent,
      ]).createShader(
          Rect.fromCircle(center: Offset(pt.x, pt.y), radius: pt.radius * 3.0));
      canvas.drawCircle(Offset(pt.x, pt.y), pt.radius * 3.0, glowPaint);

      // Outer halo — 复用 Paint
      _haloPaint.color = AppColors.white.withValues(alpha: haloAlpha);
      canvas.drawCircle(Offset(pt.x, pt.y), pt.radius + 2.6, _haloPaint);

      // Core — 复用 Paint
      _corePaint.color = pt.color.withValues(alpha: .9);
      canvas.drawCircle(Offset(pt.x, pt.y), pt.radius, _corePaint);

      // Bright center — 复用 Paint
      _brightPaint.color = AppColors.white.withValues(alpha: brightAlpha);
      canvas.drawCircle(Offset(pt.x, pt.y), pt.radius * 0.35, _brightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _UniversePainter old) =>
      old.breathe != breathe || old.islands != islands;

  // ─── 连线缓存 ─────────────────────────────────────────────────
  // O(n²) 距离计算只在岛屿列表变化时执行，不在每帧重复。
  static List<_LinePair>? _lastPairs;
  static int _lastIslandsHash = 0;
  static Size _lastCanvasSize = Size.zero;

  static List<_LinePair> _cachedLinePairs(
      List<_IslandPoint> points, List<IslandModel> islands, Size canvasSize) {
    // M13: Use Object.hashAll instead of XOR (collision-prone), include canvas size
    final hash = Object.hashAll([
      canvasSize.width,
      canvasSize.height,
      ...islands.map((i) => Object.hash(i.name, i.fragmentCount)),
    ]);
    if (hash == _lastIslandsHash &&
        _lastPairs != null &&
        _lastCanvasSize == canvasSize) {
      return _lastPairs!;
    }
    _lastIslandsHash = hash;
    _lastCanvasSize = canvasSize;

    final pairs = <_LinePair>[];
    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        final dx = points[i].x - points[j].x;
        final dy = points[i].y - points[j].y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < 160) {
          pairs.add(_LinePair(
            x1: points[i].x,
            y1: points[i].y,
            x2: points[j].x,
            y2: points[j].y,
            alpha: (1 - dist / 160) * 0.16,
          ));
        }
      }
    }
    _lastPairs = pairs;
    return pairs;
  }
}

class _LinePair {
  final double x1, y1, x2, y2, alpha;
  const _LinePair(
      {required this.x1,
      required this.y1,
      required this.x2,
      required this.y2,
      required this.alpha});
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(size.width / 2, size.height / 2);
        return Stack(
          children: List.generate(islands.length, (i) {
            final angle = i * 2.4 + 0.5;
            final dist = 50.0 + i * 38.0;
            final x = center.dx + cos(angle) * dist - 40;
            final y = center.dy + sin(angle) * dist + 18;
            final maxLabelY = max(_skyTopSafeZone, size.height - 112);
            return Positioned(
              left: x.clamp(0, size.width - 84),
              top: y.clamp(_skyTopSafeZone, maxLabelY),
              child: GestureDetector(
                onTap: () => context.push(_islandDetailPath(islands[i])),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 80),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s6, vertical: AppSpacing.s3),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    islands[i].name,
                    style: AppText.microLabel.copyWith(
                      color: AppColors.white.withValues(alpha: .78),
                      height: 1.1,
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
      },
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
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
          width: width,
          padding: const EdgeInsets.all(AppSpacing.s14),
          decoration:
              nightMode ? nightDecoration() : softDecoration(AppColors.white),
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
            const SizedBox(height: AppSpacing.s12),
            Text('#${island.name}',
                style: AppText.onNight(AppText.titleSmall, nightMode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.s7),
            _TopicStatusPill(status: island.status, nightMode: nightMode),
            const SizedBox(height: AppSpacing.sm),
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
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration:
            nightMode ? nightDecoration() : softDecoration(AppColors.white),
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.s5),
      decoration: BoxDecoration(
        color: nightMode
            ? (active
                ? AppColors.teaGreen.withValues(alpha: .18)
                : AppColors.white.withValues(alpha: .08))
            : (active
                ? AppColors.teaGreen.withValues(alpha: .14)
                : AppColors.paper.withValues(alpha: .88)),
        borderRadius: BorderRadius.circular(AppRadius.md),
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
        const SizedBox(width: AppSpacing.s5),
        Text(
          label,
          style: AppText.captionStrong.copyWith(
            height: 1,
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

/// 中性占位 — 数据未到达时显示，避免直接渲染"空岛"文案造成首屏文本突变。
class _UniverseOverviewSkeleton extends StatelessWidget {
  const _UniverseOverviewSkeleton({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        height: 218,
        decoration: softDecoration(AppColors.ink)
            .copyWith(gradient: AppColors.gradientNight),
      ),
      const SizedBox(height: AppSpacing.s12),
      Container(
        height: 62,
        decoration:
            nightMode ? nightDecoration() : softDecoration(AppColors.white),
      ),
      const SizedBox(height: AppSpacing.s12),
      LayoutBuilder(builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 460 ? 3 : 2;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(
            3,
            (_) => SizedBox(
              width: itemWidth,
              height: 76,
              child: DecoratedBox(
                decoration: nightMode
                    ? nightDecoration()
                    : softDecoration(AppColors.white),
              ),
            ),
          ),
        );
      }),
    ]);
  }
}

class _TopicIslandGridSkeleton extends StatelessWidget {
  const _TopicIslandGridSkeleton({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(
        4,
        (_) => SizedBox(
          width: (MediaQuery.sizeOf(context).width - 22 * 2 - 10) / 2,
          height: 118,
          child: DecoratedBox(
            decoration:
                nightMode ? nightDecoration() : softDecoration(AppColors.white),
          ),
        ),
      ),
    );
  }
}
