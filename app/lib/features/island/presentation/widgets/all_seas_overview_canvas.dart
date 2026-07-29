import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/typography.dart';
import '../../domain/island_visual_stage.dart';
import '../../domain/universe_overview.dart';
import 'island_archipelago_canvas.dart';
import 'island_sprite_visual.dart';

class IslandOverviewNode {
  const IslandOverviewNode({
    required this.island,
    required this.seaIndex,
    required this.startCenter,
    required this.center,
    required this.startSpriteExtent,
    required this.spriteExtent,
    required this.visualExtent,
    required this.hitBounds,
    required this.revealOrder,
  });

  final IslandVisualNode island;
  final int seaIndex;
  final Offset startCenter;
  final Offset center;
  final double startSpriteExtent;
  final double spriteExtent;
  final double visualExtent;
  final Rect hitBounds;
  final int revealOrder;
}

class AllSeasOverviewCanvas extends StatefulWidget {
  const AllSeasOverviewCanvas({
    super.key,
    required this.islands,
    required this.currentSeaIndex,
    this.sourceViewport,
    required this.selectedIsland,
    required this.favoriteKeys,
    required this.onIslandSelected,
    required this.onExitCompleted,
    this.exitSeaIndex,
  });

  final List<IslandVisualNode> islands;
  final int currentSeaIndex;
  final IslandSeaViewportSnapshot? sourceViewport;
  final IslandVisualNode? selectedIsland;
  final Set<String> favoriteKeys;
  final void Function(IslandVisualNode? island, int? seaIndex) onIslandSelected;
  final int? exitSeaIndex;
  final ValueChanged<int> onExitCompleted;

  @override
  State<AllSeasOverviewCanvas> createState() => _AllSeasOverviewCanvasState();
}

class _AllSeasOverviewCanvasState extends State<AllSeasOverviewCanvas>
    with TickerProviderStateMixin {
  late final AnimationController _reveal;
  late final AnimationController _ambient;
  _GlobalOceanLayout? _layout;
  int? _notifiedExitSeaIndex;
  bool _loadingSprites = false;
  Map<int, Map<IslandVisualStage, ui.Image>> _spriteFamilies = const {};

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: AppMotion.islandGrowth,
    );
    _ambient = AnimationController(
      vsync: this,
      duration: AppMotion.oceanAmbient,
    )..repeat();
    _loadSpriteImages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      _reveal.duration = reduceMotion ? AppMotion.fast : AppMotion.islandGrowth;
      _reveal.forward();
    });
  }

  Future<void> _loadSpriteImages() async {
    if (_loadingSprites) return;
    _loadingSprites = true;
    final loaded = <int, Map<IslandVisualStage, ui.Image>>{};
    try {
      for (final island in widget.islands) {
        final family = island.visualFamily % 6;
        final stage = island.visualStage;
        if (_spriteFamilies[family]?[stage] != null ||
            loaded[family]?[stage] != null) {
          continue;
        }
        final data = await rootBundle.load(
          'assets/islands/family_$family/${stage.name}.png',
        );
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        loaded.putIfAbsent(family, () => {})[stage] = frame.image;
        codec.dispose();
      }
      if (!mounted) {
        for (final image in loaded.values.expand((stages) => stages.values)) {
          image.dispose();
        }
        return;
      }
      setState(() {
        _spriteFamilies = {
          for (final entry in _spriteFamilies.entries)
            entry.key: {...entry.value},
          for (final entry in loaded.entries)
            entry.key: {
              ...?_spriteFamilies[entry.key],
              ...entry.value,
            },
        };
      });
    } catch (error, stackTrace) {
      for (final image in loaded.values.expand((stages) => stages.values)) {
        image.dispose();
      }
      assert(() {
        debugPrint('Failed to load global-ocean island sprites: $error');
        debugPrintStack(stackTrace: stackTrace);
        return true;
      }());
    } finally {
      _loadingSprites = false;
    }
  }

  @override
  void didUpdateWidget(covariant AllSeasOverviewCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exitSeaIndex != widget.exitSeaIndex) {
      _notifiedExitSeaIndex = null;
      final exitSeaIndex = widget.exitSeaIndex;
      if (exitSeaIndex != null) {
        final reduceMotion =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        _reveal.duration =
            reduceMotion ? AppMotion.fast : AppMotion.islandTravel;
        _reveal.reverse().whenComplete(() {
          if (!mounted ||
              widget.exitSeaIndex != exitSeaIndex ||
              _notifiedExitSeaIndex == exitSeaIndex) {
            return;
          }
          _notifiedExitSeaIndex = exitSeaIndex;
          widget.onExitCompleted(exitSeaIndex);
        });
      }
    }
    if (oldWidget.islands != widget.islands) {
      _loadSpriteImages();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _ambient.dispose();
    for (final image
        in _spriteFamilies.values.expand((stages) => stages.values)) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.islands.isEmpty) {
      return const _GlobalOceanEmptyState();
    }
    final theme = NightTheme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final pages = buildIslandSeaPages(widget.islands);
      final currentSeaIndex = widget.currentSeaIndex.clamp(0, pages.length - 1);
      final layout = _GlobalOceanLayout.build(
        size: size,
        pages: pages,
        currentSeaIndex: currentSeaIndex,
        sourceViewport: widget.sourceViewport,
      );
      _layout = layout;

      return ClipRect(
        child: GestureDetector(
          key: const ValueKey('all-seas-gesture-layer'),
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleBackgroundTap(details.localPosition),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _ambient,
                  builder: (context, _) => CustomPaint(
                    painter: _OceanDepthPainter(
                      theme: theme,
                      phase: _ambient.value,
                      entrance:
                          AppMotion.microMovement.transform(_reveal.value),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_reveal, _ambient]),
                  builder: (context, _) => CustomPaint(
                    painter: _GlobalOceanPainter(
                      layout: layout,
                      theme: theme,
                      currentSeaIndex: currentSeaIndex,
                      entrance:
                          AppMotion.microMovement.transform(_reveal.value),
                      phase: _ambient.value,
                    ),
                  ),
                ),
              ),
              if (widget.islands.length > 60 && _spriteFamilies.isNotEmpty)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _reveal,
                    builder: (context, _) => CustomPaint(
                      painter: _GlobalIslandSpritePainter(
                        layout: layout,
                        currentSeaIndex: currentSeaIndex,
                        selectedVisualKey: widget.selectedIsland?.visualKey,
                        entrance:
                            AppMotion.microMovement.transform(_reveal.value),
                        spriteFamilies: _spriteFamilies,
                      ),
                    ),
                  ),
                ),
              AnimatedBuilder(
                animation: _reveal,
                builder: (context, _) {
                  final entrance =
                      AppMotion.microMovement.transform(_reveal.value);
                  final paintedSprites =
                      widget.islands.length > 60 && _spriteFamilies.isNotEmpty;
                  return Stack(
                    children: [
                      for (final node in layout.nodes)
                        _buildIsland(
                          context,
                          layout,
                          node,
                          entrance,
                          paintedSprites &&
                              _hasSprite(node) &&
                              widget.selectedIsland?.visualKey !=
                                  node.island.visualKey,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  bool _hasSprite(IslandOverviewNode node) {
    final family = node.island.visualFamily % 6;
    return _spriteFamilies[family]?[node.island.visualStage] != null;
  }

  Widget _buildIsland(
    BuildContext context,
    _GlobalOceanLayout layout,
    IslandOverviewNode node,
    double entrance,
    bool spritePainted,
  ) {
    final theme = NightTheme.of(context);
    final selected = widget.selectedIsland?.visualKey == node.island.visualKey;
    final current = node.seaIndex == layout.currentSeaIndex;
    final reveal = _nodeReveal(node, entrance, current);
    final center = _displayCenter(node, entrance);
    final extent = _displaySpriteExtent(node, entrance);
    final showLabel = selected ||
        widget.favoriteKeys.contains(node.island.visualKey) ||
        layout.labelKeys.contains(node.island.visualKey);
    final seaLabelOpacity = current
        ? Curves.easeInOutCubic.transform(
            (1 - entrance / .36).clamp(0.0, 1.0),
          )
        : 0.0;
    final overviewLabelOpacity = showLabel
        ? Curves.easeInOutCubic.transform(
            ((entrance - .08) / .32).clamp(0.0, 1.0),
          )
        : 0.0;
    final hasLabel = current || showLabel;
    final itemWidth = hasLabel ? max(extent, 112.0) : extent;
    return Positioned(
      left: center.dx - itemWidth / 2,
      top: center.dy - extent / 2,
      width: itemWidth,
      height: extent + (hasLabel ? 24 : 0),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => widget.onIslandSelected(node.island, node.seaIndex),
        child: Opacity(
          opacity: reveal,
          child: Semantics(
            button: true,
            selected: selected,
            label: '${node.island.island.name}，${node.island.fragmentCount} 束光',
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedScale(
                duration: AppMotion.normal,
                curve: AppMotion.easeOut,
                scale: selected ? 1.08 : 1,
                child: Stack(alignment: Alignment.center, children: [
                  if (selected)
                    Container(
                      width: extent * .68,
                      height: extent * .68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.accent.withValues(alpha: .34),
                            blurRadius: extent * .22,
                            spreadRadius: extent * .04,
                          ),
                        ],
                      ),
                    ),
                  if (spritePainted)
                    SizedBox.square(dimension: extent)
                  else
                    IslandSpriteVisual(
                      key: ValueKey(
                        'global-island-center-${node.island.visualKey}',
                      ),
                      island: node.island,
                      width: extent,
                      height: extent,
                    ),
                ]),
              ),
              if (hasLabel)
                Transform.translate(
                  offset: Offset(0, -extent * .025),
                  child: SizedBox(
                    width: itemWidth,
                    height: 22,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Opacity(
                          opacity: overviewLabelOpacity,
                          child: Text(
                            node.island.island.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppText.captionStrong.copyWith(
                              color: theme.foreground.withValues(alpha: .88),
                              fontSize: 10,
                              height: 1,
                              shadows: [
                                Shadow(
                                  color:
                                      theme.background.withValues(alpha: .92),
                                  blurRadius: 7,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: seaLabelOpacity,
                          child: Text(
                            '${node.island.island.name} · ${node.island.fragmentCount} 束',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppText.captionStrong.copyWith(
                              color: theme.foreground.withValues(alpha: .94),
                              shadows: [
                                Shadow(
                                  color:
                                      theme.background.withValues(alpha: .78),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  void _handleBackgroundTap(Offset localPosition) {
    final layout = _layout;
    if (layout == null) return;
    if (layout.hitTestIsland(localPosition) == null) {
      widget.onIslandSelected(null, null);
    }
  }
}

class _GlobalOceanLayout {
  const _GlobalOceanLayout({
    required this.size,
    required this.nodes,
    required this.currentSeaIndex,
    required this.labelKeys,
    required this.signature,
  });

  final Size size;
  final List<IslandOverviewNode> nodes;
  final int currentSeaIndex;
  final Set<String> labelKeys;
  final String signature;

  factory _GlobalOceanLayout.build({
    required Size size,
    required List<List<IslandVisualNode>> pages,
    required int currentSeaIndex,
    required IslandSeaViewportSnapshot? sourceViewport,
  }) {
    final islands = <({IslandVisualNode island, int seaIndex})>[];
    for (var seaIndex = 0; seaIndex < pages.length; seaIndex++) {
      for (final island in pages[seaIndex]) {
        islands.add((island: island, seaIndex: seaIndex));
      }
    }
    final safeRect = Rect.fromLTWH(
      14,
      18,
      max(1, size.width - 28),
      max(1, size.height - 36),
    );
    final sourceNodes = sourceViewport?.seaIndex == currentSeaIndex
        ? sourceViewport!.nodes
        : const <String, IslandViewportNode>{};
    final visualExtent = _overviewVisualExtent(
      safeRect.shortestSide,
      islands.length,
    );
    final spriteExtents = [
      for (final entry in islands)
        _spriteExtentForStage(visualExtent, entry.island.visualStage),
    ];
    final targetCenters = _forceClusterLayout(
      safeRect,
      islands.map((entry) => entry.island.visualKey).toList(growable: false),
      visualExtent,
    );
    final startCenters = <Offset>[];
    final startSpriteExtents = <double>[];
    for (var index = 0; index < islands.length; index++) {
      final source = sourceNodes[islands[index].island.visualKey];
      startCenters.add(source == null
          ? _spawnPoint(
              safeRect,
              islands[index].island.visualKey,
              index,
              islands.length,
            )
          : Offset(
              source.normalizedCenter.dx * size.width,
              source.normalizedCenter.dy * size.height,
            ));
      startSpriteExtents.add(source == null
          ? spriteExtents[index] * .62
          : source.normalizedExtent * size.shortestSide);
    }
    final nodes = [
      for (var index = 0; index < islands.length; index++)
        IslandOverviewNode(
          island: islands[index].island,
          seaIndex: islands[index].seaIndex,
          startCenter: startCenters[index],
          center: targetCenters[index],
          startSpriteExtent: startSpriteExtents[index],
          spriteExtent: spriteExtents[index],
          visualExtent: visualExtent,
          hitBounds: Rect.fromCircle(
            center: targetCenters[index],
            radius: max(22, visualExtent * .56),
          ),
          revealOrder: index,
        ),
    ];
    final labelKeys = _overviewLabelKeys(nodes);
    final signature = '${size.width.round()}x${size.height.round()}|'
        '${nodes.map((node) => '${node.island.visualKey}:${node.island.visualStage.name}').join(',')}|$currentSeaIndex';
    return _GlobalOceanLayout(
      size: size,
      nodes: nodes,
      currentSeaIndex: currentSeaIndex,
      labelKeys: labelKeys,
      signature: signature,
    );
  }

  IslandOverviewNode? hitTestIsland(Offset point) {
    IslandOverviewNode? nearest;
    var nearestDistance = double.infinity;
    for (final node in nodes) {
      if (!node.hitBounds.contains(point)) continue;
      final distance = (node.center - point).distanceSquared;
      if (distance < nearestDistance) {
        nearest = node;
        nearestDistance = distance;
      }
    }
    return nearest;
  }
}

List<Offset> _forceClusterLayout(
  Rect safeRect,
  List<String> visualKeys,
  double visualExtent,
) {
  if (visualKeys.isEmpty) return const [];
  final count = visualKeys.length;
  final spread = sqrt(count.toDouble());
  final clusterWidth = min(
    safeRect.width * .84,
    visualExtent * spread * 1.82,
  );
  final clusterHeight = min(
    safeRect.height * .66,
    visualExtent * spread * 2.02,
  );
  final clusterRect = Rect.fromCenter(
    center: safeRect.center.translate(0, -safeRect.height * .015),
    width: max(clusterWidth, visualExtent * 2.3),
    height: max(clusterHeight, visualExtent * 2.5),
  );
  final centers = <Offset>[];
  for (var index = 0; index < count; index++) {
    final progress = sqrt((index + .7) / count);
    final phase = (_stableHash(visualKeys[index]) % 360) / 180 * pi;
    final angle = index * 2.399963229728653 + phase * .08;
    centers.add(Offset(
      clusterRect.center.dx + cos(angle) * clusterRect.width * .43 * progress,
      clusterRect.center.dy + sin(angle) * clusterRect.height * .43 * progress,
    ));
  }
  for (var iteration = 0; iteration < 120; iteration++) {
    final pushes = List<Offset>.filled(centers.length, Offset.zero);
    for (var first = 0; first < centers.length; first++) {
      for (var second = first + 1; second < centers.length; second++) {
        var delta = centers[second] - centers[first];
        var distance = delta.distance;
        if (distance < .01) {
          final angle = (_stableHash('$first-$second') % 628) / 100;
          delta = Offset(cos(angle), sin(angle));
          distance = 1;
        }
        final minimum = visualExtent * 1.10;
        final direction = delta / distance;
        final overlap = max(0.0, minimum - distance);
        final nearRepulsion =
            distance < minimum * 1.9 ? (minimum * 1.9 - distance) * .025 : 0.0;
        final force = overlap * .54 + nearRepulsion;
        pushes[first] -= direction * force;
        pushes[second] += direction * force;
      }
    }
    for (var index = 0; index < centers.length; index++) {
      final centerPull = (clusterRect.center - centers[index]) * .0065;
      final next = centers[index] + pushes[index] + centerPull;
      final edge = max(14.0, visualExtent * .56);
      centers[index] = Offset(
        next.dx.clamp(clusterRect.left + edge, clusterRect.right - edge),
        next.dy.clamp(clusterRect.top + edge, clusterRect.bottom - edge),
      );
    }
  }
  return centers;
}

Offset _spawnPoint(
  Rect safeRect,
  String visualKey,
  int index,
  int count,
) {
  final angle = (_stableHash(visualKey) % 628) / 100 + index / max(1, count);
  return Offset(
    safeRect.center.dx + cos(angle) * safeRect.width * .46,
    safeRect.center.dy + sin(angle) * safeRect.height * .43,
  );
}

double _overviewVisualExtent(double shortest, int islandCount) {
  final extent = islandCount <= 8
      ? shortest * .17
      : islandCount <= 15
          ? shortest * .145
          : islandCount <= 30
              ? shortest * .115
              : islandCount <= 60
                  ? shortest * .09
                  : shortest * .066;
  return extent.clamp(22.0, 66.0);
}

double _spriteExtentForStage(
  double visualExtent,
  IslandVisualStage stage,
) {
  final coverage = switch (stage) {
    IslandVisualStage.shoal => .443,
    IslandVisualStage.sprouting => .652,
    IslandVisualStage.growing => .801,
    IslandVisualStage.formed => .861,
    IslandVisualStage.dormant => .863,
    IslandVisualStage.relit => .863,
  };
  return visualExtent / coverage;
}

Set<String> _overviewLabelKeys(List<IslandOverviewNode> nodes) {
  if (nodes.isEmpty) return const {};
  final selected = <IslandOverviewNode>{
    nodes.reduce((a, b) => a.center.dx < b.center.dx ? a : b),
    nodes.reduce((a, b) => a.center.dx > b.center.dx ? a : b),
    nodes.reduce((a, b) => a.center.dy < b.center.dy ? a : b),
    nodes.reduce((a, b) => a.center.dy > b.center.dy ? a : b),
  };
  return selected.map((node) => node.island.visualKey).toSet();
}

double _nodeMovement(IslandOverviewNode node, double entrance) {
  final start = min(.34, node.revealOrder * .012);
  final raw = ((entrance - start) / (1 - start)).clamp(0.0, 1.0);
  return AppMotion.microMovement.transform(raw);
}

double _nodeReveal(
  IslandOverviewNode node,
  double entrance,
  bool current,
) {
  if (current) return 1;
  final start = min(.72, .04 + node.revealOrder * .014);
  return ((entrance - start) / (1 - start)).clamp(0.0, 1.0);
}

Offset _displayCenter(
  IslandOverviewNode node,
  double entrance,
) {
  final movement = _nodeMovement(node, entrance);
  final center = Offset.lerp(node.startCenter, node.center, movement)!;
  final delta = node.center - node.startCenter;
  if (delta.distance < 1) return center;
  final perpendicular = Offset(-delta.dy, delta.dx) / delta.distance;
  final direction = _stableHash(node.island.visualKey).isEven ? 1.0 : -1.0;
  return center +
      perpendicular *
          direction *
          sin(movement * pi) *
          min(12, delta.distance * .08);
}

double _displaySpriteExtent(IslandOverviewNode node, double entrance) {
  final movement = _nodeMovement(node, entrance);
  return node.startSpriteExtent +
      (node.spriteExtent - node.startSpriteExtent) * movement;
}

class _OceanDepthPainter extends CustomPainter {
  const _OceanDepthPainter({
    required this.theme,
    required this.phase,
    required this.entrance,
  });

  final NightTheme theme;
  final double phase;
  final double entrance;

  @override
  void paint(Canvas canvas, Size size) {
    paintIslandSeaAtmosphere(canvas, size, theme, phase);
    final overviewAlpha = Curves.easeInOutCubic.transform(entrance);
    for (var index = 0; index < 4; index++) {
      final center = Offset(
        size.width * (.16 + index * .23) + sin(phase * pi * 2 + index) * 5,
        size.height * (.22 + (index.isEven ? .12 : .36)),
      );
      final radius = size.shortestSide * (.28 + index * .025);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [
            (index.isEven ? theme.accent : theme.foregroundMuted).withValues(
              alpha: (theme.isNight ? .055 : .05) * overviewAlpha,
            ),
            theme.background.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    final speckPaint = Paint()
      ..color = theme.foreground.withValues(
        alpha: (theme.isNight ? .10 : .075) * overviewAlpha,
      );
    for (var index = 0; index < 28; index++) {
      final x = ((index * 83 + 19) % 233) / 233 * size.width;
      final y = ((index * 47 + 31) % 197) / 197 * size.height;
      final pulse = .55 + .45 * sin(phase * pi * 2 + index * .73);
      canvas.drawCircle(Offset(x, y), .4 + pulse * .5, speckPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OceanDepthPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.entrance != entrance ||
      oldDelegate.theme != theme;
}

class _GlobalOceanPainter extends CustomPainter {
  const _GlobalOceanPainter({
    required this.layout,
    required this.theme,
    required this.currentSeaIndex,
    required this.entrance,
    required this.phase,
  });

  final _GlobalOceanLayout layout;
  final NightTheme theme;
  final int currentSeaIndex;
  final double entrance;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    _drawCurrents(canvas, size);
    _drawIslandRipples(canvas);
  }

  void _drawCurrents(Canvas canvas, Size size) {
    final alpha = Curves.easeInOutCubic.transform(entrance);
    for (var line = 0; line < 8; line++) {
      final startX = size.width * (((line * 37) % 83) / 100) - 12;
      final width = size.width * (.16 + (line % 4) * .035);
      final baseY = size.height * (.16 + ((line * 23) % 71) / 100);
      final path = Path();
      for (var x = startX; x <= min(size.width + 12, startX + width); x += 5) {
        final y = baseY +
            sin((x - startX) / width * pi * 1.8 + phase * pi * 2 + line) *
                (2.8 + line % 3) +
            cos((x - startX) / width * pi * 3.2 - phase * pi) * 1.2;
        if (x == startX) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .82
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .9)
          ..color = theme.accent.withValues(alpha: .06 * alpha),
      );
    }
  }

  void _drawIslandRipples(Canvas canvas) {
    for (final node in layout.nodes) {
      final current = node.seaIndex == currentSeaIndex;
      final reveal = _nodeReveal(node, entrance, current);
      if (!current && (reveal <= .08 || reveal >= 1)) continue;
      final center = _displayCenter(node, entrance);
      final visualExtent = node.visualExtent *
          (_displaySpriteExtent(node, entrance) / node.spriteExtent);
      final pulse = current
          ? .34 + sin(phase * pi * 2 + node.revealOrder) * .08
          : sin(reveal * pi);
      for (var ring = 0; ring < 2; ring++) {
        final spread = visualExtent *
            (current ? .58 + ring * .16 : .48 + reveal * .42 + ring * .16);
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: spread * 1.28,
            height: spread * .48,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1)
            ..color = theme.accent.withValues(
              alpha: (current ? .035 : .12 * pulse) * (1 - ring * .34),
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlobalOceanPainter oldDelegate) =>
      oldDelegate.layout.signature != layout.signature ||
      oldDelegate.theme != theme ||
      oldDelegate.currentSeaIndex != currentSeaIndex ||
      oldDelegate.entrance != entrance ||
      oldDelegate.phase != phase;
}

class _GlobalIslandSpritePainter extends CustomPainter {
  const _GlobalIslandSpritePainter({
    required this.layout,
    required this.currentSeaIndex,
    required this.selectedVisualKey,
    required this.entrance,
    required this.spriteFamilies,
  });

  final _GlobalOceanLayout layout;
  final int currentSeaIndex;
  final String? selectedVisualKey;
  final double entrance;
  final Map<int, Map<IslandVisualStage, ui.Image>> spriteFamilies;

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in layout.nodes) {
      if (node.island.visualKey == selectedVisualKey) continue;
      final family = node.island.visualFamily % 6;
      final image = spriteFamilies[family]?[node.island.visualStage];
      if (image == null) continue;
      final alpha = _nodeReveal(
        node,
        entrance,
        node.seaIndex == currentSeaIndex,
      );
      final extent = _displaySpriteExtent(node, entrance);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(
          center: _displayCenter(node, entrance),
          width: extent,
          height: extent,
        ),
        Paint()
          ..filterQuality = FilterQuality.high
          ..color = Colors.white.withValues(alpha: alpha)
          ..colorFilter = islandSpriteColorFilter,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlobalIslandSpritePainter oldDelegate) =>
      oldDelegate.layout.signature != layout.signature ||
      oldDelegate.currentSeaIndex != currentSeaIndex ||
      oldDelegate.selectedVisualKey != selectedVisualKey ||
      oldDelegate.entrance != entrance ||
      oldDelegate.spriteFamilies != spriteFamilies;
}

class _GlobalOceanEmptyState extends StatelessWidget {
  const _GlobalOceanEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Center(
      child: Text(
        '第一座岛浮起后，这里会慢慢成为一整片海。',
        style: AppText.bodyMuted.copyWith(color: theme.foregroundMuted),
      ),
    );
  }
}

int _stableHash(String value) {
  var hash = 0x811C9DC5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}
