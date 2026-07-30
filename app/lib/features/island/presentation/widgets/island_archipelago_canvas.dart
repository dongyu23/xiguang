import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../domain/island_visual_stage.dart';
import '../../domain/universe_overview.dart';
import 'island_sprite_visual.dart';

const _selectionScaleDelta = .18;

void paintIslandSeaAtmosphere(
  Canvas canvas,
  Size size,
  NightTheme theme,
  double phase, {
  double opacity = 1,
}) {
  final alpha = opacity.clamp(0.0, 1.0);
  if (alpha <= 0) return;
  final bounds = Offset.zero & size;
  final waterColors = theme.isNight
      ? [
          AppColors.islandSeaNightDeep.withValues(alpha: .74 * alpha),
          AppColors.islandSeaNightMid.withValues(alpha: .68 * alpha),
          AppColors.islandSeaNightBlue.withValues(alpha: .56 * alpha),
          AppColors.islandSeaNightDusk.withValues(alpha: .42 * alpha),
        ]
      : [
          AppColors.islandSeaDayWarm.withValues(alpha: .62 * alpha),
          AppColors.islandSeaDayMint.withValues(alpha: .72 * alpha),
          AppColors.islandSeaDayMist.withValues(alpha: .62 * alpha),
          AppColors.islandSeaDaySand.withValues(alpha: .52 * alpha),
        ];
  canvas.drawRect(
    bounds,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: waterColors,
        stops: const [0, .38, .72, 1],
      ).createShader(bounds),
  );

  final basinCenter = Offset(
    size.width * .5 + sin(phase * pi * 2) * 5,
    size.height * .49 + cos(phase * pi * 1.4) * 3,
  );
  final basinRadius = size.longestSide * .64;
  canvas.drawOval(
    Rect.fromCenter(
      center: basinCenter,
      width: basinRadius * 1.34,
      height: basinRadius,
    ),
    Paint()
      ..shader = RadialGradient(
        colors: [
          (theme.isNight
                  ? AppColors.islandBasinNightGreen
                  : AppColors.islandBasinDayGreen)
              .withValues(alpha: .13 * alpha),
          (theme.isNight
                  ? AppColors.islandBasinNightBlue
                  : AppColors.islandBasinDayBlue)
              .withValues(alpha: .065 * alpha),
          Colors.transparent,
        ],
        stops: const [0, .48, 1],
      ).createShader(Rect.fromCircle(
        center: basinCenter,
        radius: basinRadius,
      )),
  );

  for (var layer = 0; layer < 7; layer++) {
    final startX = -size.width * (.18 + (layer % 3) * .07);
    final endX = size.width * (1.08 + (layer % 2) * .12);
    final baseY = size.height * (.12 + layer * .125);
    final amplitude = 3.6 + (layer % 3) * 1.35;
    final direction = layer.isEven ? 1.0 : -0.72;
    final path = Path();
    for (var x = startX; x <= endX; x += 8) {
      final y = baseY +
          sin(x / (54 + layer * 5) + phase * pi * 2 * direction + layer) *
              amplitude +
          cos(x / (116 + layer * 7) - phase * pi * .8 + layer * .43) * 1.7;
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
        ..strokeWidth = layer.isEven ? .9 : .62
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .55)
        ..color = (layer.isEven ? theme.accent : theme.foregroundMuted)
            .withValues(alpha: (theme.isNight ? .075 : .095) * alpha),
    );
  }

  for (var index = 0; index < 4; index++) {
    final center = Offset(
      size.width * (.16 + index * .23) + sin(phase * pi * 2 + index) * 4,
      size.height * (.24 + (index.isEven ? .13 : .42)),
    );
    final radius = size.shortestSide * (.11 + (index % 2) * .035);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(colors: [
          (index.isEven ? theme.accent : theme.foregroundMuted)
              .withValues(alpha: (theme.isNight ? .055 : .07) * alpha),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  final glintPaint = Paint()
    ..color = theme.foreground.withValues(
      alpha: (theme.isNight ? .085 : .075) * alpha,
    );
  for (var index = 0; index < 22; index++) {
    final x = ((index * 83 + 19) % 233) / 233 * size.width;
    final y = ((index * 47 + 31) % 197) / 197 * size.height;
    final pulse = .55 + .45 * sin(phase * pi * 2 + index * .73);
    canvas.drawCircle(Offset(x, y), .35 + pulse * .45, glintPaint);
  }
}

class IslandViewportNode {
  const IslandViewportNode({
    required this.normalizedCenter,
    required this.normalizedExtent,
  });

  final Offset normalizedCenter;
  final double normalizedExtent;
}

class IslandSeaViewportSnapshot {
  const IslandSeaViewportSnapshot({
    required this.seaIndex,
    required this.nodes,
  });

  final int seaIndex;
  final Map<String, IslandViewportNode> nodes;
}

class IslandArchipelagoCanvas extends StatefulWidget {
  const IslandArchipelagoCanvas({
    super.key,
    required this.islands,
    required this.selected,
    required this.onSelect,
    this.initialSeaIndex = 0,
    this.onSeaChanged,
    this.onViewportChanged,
    this.revealIslandKey,
    this.onRevealHandled,
    this.onReorder,
  });

  final List<IslandVisualNode> islands;
  final IslandVisualNode? selected;
  final ValueChanged<IslandVisualNode?> onSelect;
  final int initialSeaIndex;
  final ValueChanged<int>? onSeaChanged;
  final ValueChanged<IslandSeaViewportSnapshot>? onViewportChanged;
  final String? revealIslandKey;
  final VoidCallback? onRevealHandled;
  final void Function(String visualKey, String targetVisualKey)? onReorder;

  @override
  State<IslandArchipelagoCanvas> createState() =>
      _IslandArchipelagoCanvasState();
}

class _IslandArchipelagoCanvasState extends State<IslandArchipelagoCanvas>
    with TickerProviderStateMixin {
  static const _spriteFamilyCount = 6;

  late final AnimationController _breathe;
  late final AnimationController _growth;
  late final AnimationController _selection;
  late final AnimationController _spriteReveal;
  late final AnimationController _arrival;
  late final AnimationController _reflow;
  late final PageController _pageController;
  late Map<String, IslandVisualStage> _knownStages;
  final Set<String> _growingKeys = {};
  Map<int, Map<IslandVisualStage, ui.Image>> _spriteFamilies = const {};
  String? _selectionVisualKey;
  String? _arrivingVisualKey;
  String? _draggingVisualKey;
  String? _dragTargetVisualKey;
  Offset _dragGrabOffset = Offset.zero;
  Offset? _dragCenter;
  List<List<IslandVisualNode>> _previousPages = const [];
  final Map<String, Offset> _releaseOrigins = {};
  bool _revealHandled = false;
  int? _programmaticTargetPage;
  int _page = 0;
  String? _lastViewportSignature;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(vsync: this, duration: AppMotion.breath)
      ..repeat();
    _growth = AnimationController(vsync: this, duration: AppMotion.islandGrowth)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(_growingKeys.clear);
        }
      });
    _selection = AnimationController(
      vsync: this,
      duration: AppMotion.pageSwap,
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed &&
            widget.selected == null &&
            _selectionVisualKey != null &&
            mounted) {
          setState(() => _selectionVisualKey = null);
        }
      });
    _spriteReveal = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    _arrival = AnimationController(
      vsync: this,
      duration: AppMotion.islandCanvasTransition,
    );
    _reflow = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _previousPages = const [];
            _releaseOrigins.clear();
          });
        }
      });
    final pages = buildIslandSeaPages(widget.islands);
    final revealPage = _pageForVisualKey(pages, widget.revealIslandKey);
    _revealHandled =
        widget.revealIslandKey == null || widget.revealIslandKey!.isEmpty;
    _page =
        revealPage ?? widget.initialSeaIndex.clamp(0, max(0, pages.length - 1));
    _pageController = PageController(initialPage: _page);
    if (revealPage != null) {
      _revealHandled = true;
      _arrivingVisualKey = widget.revealIslandKey;
      _notifyRevealHandled();
    }
    _selectionVisualKey = widget.selected?.visualKey;
    _knownStages = {
      for (final island in widget.islands) island.visualKey: island.visualStage,
    };
    _loadSpriteImages();
  }

  Future<void> _loadSpriteImages() async {
    final loaded = <int, Map<IslandVisualStage, ui.Image>>{};
    try {
      for (var family = 0; family < _spriteFamilyCount; family++) {
        final stages = <IslandVisualStage, ui.Image>{};
        for (final stage in IslandVisualStage.values) {
          final data = await rootBundle.load(
            'assets/islands/family_$family/${stage.name}.png',
          );
          final bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          stages[stage] = frame.image;
          codec.dispose();
        }
        loaded[family] = stages;
      }
      if (!mounted) {
        for (final image in loaded.values.expand((stages) => stages.values)) {
          image.dispose();
        }
        return;
      }
      setState(() {
        for (final image
            in _spriteFamilies.values.expand((stages) => stages.values)) {
          image.dispose();
        }
        _spriteFamilies = loaded;
      });
      _spriteReveal.forward(from: 0);
      _startArrival();
    } catch (error, stackTrace) {
      for (final image in loaded.values.expand((stages) => stages.values)) {
        image.dispose();
      }
      assert(() {
        debugPrint('Failed to load island sprites: $error');
        debugPrintStack(stackTrace: stackTrace);
        return true;
      }());
      if (mounted) _startArrival(force: true);
    }
  }

  void _startArrival({bool force = false}) {
    if (_arrivingVisualKey == null ||
        _arrival.isAnimating ||
        _arrival.isCompleted) {
      return;
    }
    if (!force && _spriteFamilies.isEmpty) return;
    _arrival.forward(from: 0);
  }

  @override
  void dispose() {
    _breathe.dispose();
    _growth.dispose();
    _selection.dispose();
    _spriteReveal.dispose();
    _arrival.dispose();
    _reflow.dispose();
    _pageController.dispose();
    for (final image
        in _spriteFamilies.values.expand((stages) => stages.values)) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant IslandArchipelagoCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPages = buildIslandSeaPages(oldWidget.islands);
    final seaPages = buildIslandSeaPages(widget.islands);
    if (_layoutSignature(oldWidget.islands) !=
        _layoutSignature(widget.islands)) {
      _previousPages = oldPages;
      _reflow.forward(from: 0);
    }
    if (widget.selected?.visualKey != oldWidget.selected?.visualKey) {
      if (widget.selected != null) {
        _selectionVisualKey = widget.selected!.visualKey;
        _selection.forward(from: 0);
      } else if (oldWidget.selected != null) {
        _selectionVisualKey = oldWidget.selected!.visualKey;
        _selection.reverse(from: 1);
      }
    }
    final pageCount = max(1, seaPages.length);
    if (_page >= pageCount) {
      _page = pageCount - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(_page);
        }
      });
    }
    if (oldWidget.initialSeaIndex != widget.initialSeaIndex &&
        widget.initialSeaIndex >= 0 &&
        widget.initialSeaIndex < pageCount &&
        widget.initialSeaIndex != _page) {
      _moveToPage(widget.initialSeaIndex);
    }
    if (!_revealHandled) {
      final revealPage = _pageForVisualKey(seaPages, widget.revealIslandKey);
      if (revealPage != null) {
        _revealHandled = true;
        _arrivingVisualKey = widget.revealIslandKey;
        _arrival.reset();
        _startArrival();
        _moveToPage(revealPage);
        _notifyRevealHandled();
      }
    } else if (widget.selected != null) {
      final selectedPage =
          _pageForVisualKey(seaPages, widget.selected!.visualKey);
      if (selectedPage != null && selectedPage != _page) {
        _moveToPage(selectedPage, preserveSelection: true);
      }
    }

    final nextStages = {
      for (final island in widget.islands) island.visualKey: island.visualStage,
    };
    final changed = <String>{};
    for (final entry in nextStages.entries) {
      final previous = _knownStages[entry.key];
      if (previous == null ||
          islandStageRank(entry.value) > islandStageRank(previous)) {
        changed.add(entry.key);
      }
    }
    _knownStages = nextStages;
    if (changed.isNotEmpty) {
      _growingKeys
        ..clear()
        ..addAll(changed);
      _growth.forward(from: 0);
    }
  }

  void _moveToPage(int page, {bool preserveSelection = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients || page == _page) return;
      if (preserveSelection) _programmaticTargetPage = page;
      _pageController.animateToPage(
        page,
        duration: AppMotion.pageSwap,
        curve: AppMotion.easeOut,
      );
    });
  }

  void _notifyRevealHandled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onRevealHandled?.call();
    });
  }

  Map<String, Offset> _previousCentersForPage(
    Size size,
    int pageIndex,
    _IslandLayout currentLayout,
  ) {
    if (_previousPages.isEmpty) return const {};
    final previousPageByKey = <String, int>{};
    for (var page = 0; page < _previousPages.length; page++) {
      for (final island in _previousPages[page]) {
        previousPageByKey[island.visualKey] = page;
      }
    }
    final oldVisible = pageIndex < _previousPages.length
        ? _previousPages[pageIndex]
        : const <IslandVisualNode>[];
    final oldLayout =
        oldVisible.isEmpty ? null : _IslandLayout.build(size, oldVisible);
    final result = <String, Offset>{};
    for (final item in currentLayout.items) {
      final key = item.island.visualKey;
      final releaseOrigin = _releaseOrigins[key];
      if (releaseOrigin != null) {
        result[key] = releaseOrigin;
        continue;
      }
      final oldPage = previousPageByKey[key];
      if (oldPage == null) continue;
      if (oldPage == pageIndex) {
        final oldItem = oldLayout?.itemFor(key);
        if (oldItem != null) result[key] = oldItem.center;
        continue;
      }
      result[key] = Offset(
        item.center.dx + (oldPage < pageIndex ? -size.width : size.width),
        item.center.dy,
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.islands.isEmpty) {
      return const _EmptyArchipelago();
    }
    final pages = buildIslandSeaPages(widget.islands);
    final pageCount = pages.length;
    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            key: const ValueKey('archipelago-pager'),
            controller: _pageController,
            itemCount: pageCount,
            physics: const PageScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            onPageChanged: (page) {
              setState(() => _page = page);
              widget.onSeaChanged?.call(page);
              if (_programmaticTargetPage == page) {
                _programmaticTargetPage = null;
              } else {
                widget.onSelect(null);
              }
            },
            itemBuilder: (context, page) => LayoutBuilder(
              builder: (context, constraints) => _buildSeaPage(
                context,
                constraints,
                page,
                pages,
              ),
            ),
          ),
        ),
        if (pageCount > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: _SeaPageIndicator(
              key: ValueKey('archipelago-page-indicator-${_page + 1}'),
              current: _page,
              total: pageCount,
            ),
          ),
      ],
    );
  }

  Widget _buildSeaPage(
    BuildContext context,
    BoxConstraints constraints,
    int pageIndex,
    List<List<IslandVisualNode>> pages,
  ) {
    final visible = pages[pageIndex];
    final size = Size(constraints.maxWidth, constraints.maxHeight);
    final layout = _IslandLayout.build(size, visible);
    if (pageIndex == _page) {
      _emitViewportSnapshot(size, pageIndex, layout);
    }
    final previousCenters = _previousCentersForPage(
      size,
      pageIndex,
      layout,
    );
    Offset displayedCenter(_PlacedIsland item) {
      if (_draggingVisualKey == item.island.visualKey && _dragCenter != null) {
        return _dragCenter!;
      }
      final previous = previousCenters[item.island.visualKey];
      if (previous == null) return item.center;
      return Offset.lerp(
        previous,
        item.center,
        AppMotion.microMovement.transform(_reflow.value),
      )!;
    }

    final selectionItem = layout.itemFor(_selectionVisualKey);
    Offset cameraOffset() {
      if (selectionItem == null) return Offset.zero;
      final target = Offset(size.width * .5, size.height * .38);
      final destination = target - selectionItem.center;
      return destination * AppMotion.microMovement.transform(_selection.value);
    }

    return Stack(
      // 跨海域重排时，目标页的小岛会从页外沿水平方向滑入。
      // 允许它越过单页边界绘制，外层 PageView 仍负责裁剪整个海域窗口。
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final hit = layout.hitTest(
                details.localPosition - cameraOffset(),
              );
              final selected = widget.selected;
              if (selected != null) {
                if (hit?.island.visualKey != selected.visualKey) {
                  widget.onSelect(null);
                }
                return;
              }
              widget.onSelect(hit?.island);
            },
            onLongPressStart: (details) {
              final worldPoint = details.localPosition - cameraOffset();
              final hit = layout.hitTest(worldPoint);
              if (hit == null) return;
              final selected = widget.selected;
              if (selected != null &&
                  selected.visualKey != hit.island.visualKey) {
                widget.onSelect(null);
                return;
              }
              HapticFeedback.mediumImpact();
              setState(() {
                _draggingVisualKey = hit.island.visualKey;
                _dragGrabOffset = worldPoint - hit.center;
                _dragCenter = hit.center;
                _dragTargetVisualKey = null;
              });
            },
            onLongPressMoveUpdate: (details) {
              final visualKey = _draggingVisualKey;
              if (visualKey == null) return;
              final item = layout.itemFor(visualKey);
              if (item == null) return;
              final center =
                  details.localPosition - cameraOffset() - _dragGrabOffset;
              final clamped = layout.clampCenter(item, center);
              final target = layout.nearestItem(clamped, excluding: visualKey);
              setState(() {
                _dragCenter = clamped;
                _dragTargetVisualKey = target?.island.visualKey;
              });
            },
            onLongPressEnd: (_) {
              final visualKey = _draggingVisualKey;
              if (visualKey == null) return;
              final targetVisualKey = _dragTargetVisualKey;
              final releaseCenter = _dragCenter;
              if (releaseCenter != null) {
                _releaseOrigins[visualKey] = releaseCenter;
              }
              setState(() {
                _draggingVisualKey = null;
                _dragTargetVisualKey = null;
                _dragCenter = null;
                _previousPages = pages;
              });
              _reflow.forward(from: 0);
              if (targetVisualKey != null) {
                widget.onReorder?.call(visualKey, targetVisualKey);
              }
            },
            child: AnimatedBuilder(
              animation: Listenable.merge(
                [
                  _breathe,
                  _growth,
                  _selection,
                  _spriteReveal,
                  _arrival,
                  _reflow,
                ],
              ),
              builder: (_, __) => CustomPaint(
                painter: _ArchipelagoPainter(
                  layout: layout,
                  selected: widget.selected,
                  overlayVisualKey: selectionItem?.island.visualKey,
                  cameraOffset: cameraOffset(),
                  breathe: _breathe.value,
                  growth: _growth.value,
                  spriteReveal: _spriteReveal.value,
                  growingKeys: _growingKeys,
                  spriteFamilies: _spriteFamilies,
                  theme: NightTheme.of(context),
                  arrivalVisualKey: _arrivingVisualKey,
                  arrival: _arrival.value,
                  draggingVisualKey: _draggingVisualKey,
                  dragCenter: _dragCenter,
                  dragTargetVisualKey: _dragTargetVisualKey,
                  previousCenters: previousCenters,
                  reflow: _reflow.value,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        for (final item in layout.items)
          AnimatedBuilder(
            animation: Listenable.merge([_selection, _reflow]),
            builder: (context, child) {
              final center = displayedCenter(item) + cameraOffset();
              final bounds = item.boundsAt(center);
              return Positioned(
                left: bounds.left,
                top: bounds.top,
                width: bounds.width,
                height: bounds.height,
                child: IgnorePointer(
                  child: Semantics(
                    key: ValueKey(
                      'island-bounds-${item.island.visualKey}',
                    ),
                    label:
                        '${item.island.island.name}，${item.island.fragmentCount} 束光',
                    child: Stack(
                      children: [
                        Positioned(
                          left: item.horizontalHalf - 22,
                          top: item.topHalf - 22,
                          width: 44,
                          height: 44,
                          child: SizedBox(
                            key: ValueKey(
                              'island-slot-${item.island.visualKey}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        if (selectionItem != null)
          AnimatedBuilder(
            animation: Listenable.merge([_selection, _reflow]),
            builder: (context, child) => _SelectedIslandOverlay(
              item: selectionItem,
              center: displayedCenter(selectionItem),
              islandCount: layout.items.length,
              selection: _selection,
              cameraOffset: cameraOffset(),
            ),
          ),
      ],
    );
  }

  void _emitViewportSnapshot(
    Size size,
    int pageIndex,
    _IslandLayout layout,
  ) {
    final shortest = max(1.0, min(size.width, size.height));
    final nodes = {
      for (final item in layout.items)
        item.island.visualKey: IslandViewportNode(
          normalizedCenter: Offset(
            item.center.dx / max(1.0, size.width),
            item.center.dy / max(1.0, size.height),
          ),
          normalizedExtent:
              item.radius * _spriteSizeFactor(layout.items.length) / shortest,
        ),
    };
    final signature = '$pageIndex|${nodes.entries.map((entry) => '${entry.key}:'
        '${entry.value.normalizedCenter.dx.toStringAsFixed(4)},'
        '${entry.value.normalizedCenter.dy.toStringAsFixed(4)},'
        '${entry.value.normalizedExtent.toStringAsFixed(4)}').join(';')}';
    if (_lastViewportSignature == signature) return;
    _lastViewportSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _page != pageIndex) return;
      widget.onViewportChanged?.call(IslandSeaViewportSnapshot(
        seaIndex: pageIndex,
        nodes: nodes,
      ));
    });
  }
}

List<List<IslandVisualNode>> buildIslandSeaPages(
  List<IslandVisualNode> islands,
) {
  if (islands.isEmpty) return const [];
  const maxIslands = 5;
  const maxVisualLoad = 6.2;
  final pages = <List<IslandVisualNode>>[];
  var current = <IslandVisualNode>[];
  var load = 0.0;
  for (final island in islands) {
    final nextLoad = _islandVisualLoad(island.visualStage);
    if (current.isNotEmpty &&
        (current.length == maxIslands || load + nextLoad > maxVisualLoad)) {
      pages.add(current);
      current = <IslandVisualNode>[];
      load = 0;
    }
    current.add(island);
    load += nextLoad;
  }
  if (current.isNotEmpty) pages.add(current);
  return pages;
}

int? _pageForVisualKey(
  List<List<IslandVisualNode>> pages,
  String? visualKey,
) {
  if (visualKey == null || visualKey.isEmpty) return null;
  for (var page = 0; page < pages.length; page++) {
    if (pages[page].any((island) => island.visualKey == visualKey)) {
      return page;
    }
  }
  return null;
}

String _layoutSignature(List<IslandVisualNode> islands) => islands
    .map((island) =>
        '${island.visualKey}:${island.visualStage.name}:${island.fragmentCount}')
    .join('|');

double _islandVisualLoad(IslandVisualStage stage) {
  return switch (stage) {
    IslandVisualStage.shoal => 1,
    IslandVisualStage.sprouting => 1.15,
    IslandVisualStage.growing => 1.55,
    IslandVisualStage.formed => 1.9,
    IslandVisualStage.dormant => 1.9,
    IslandVisualStage.relit => 1.9,
  };
}

class _SeaPageIndicator extends StatelessWidget {
  const _SeaPageIndicator({
    super.key,
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return IgnorePointer(
      child: Semantics(
        label: '海域 ${current + 1}/$total',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(total, (index) {
            final selected = index == current;
            return AnimatedContainer(
              duration: AppMotion.quick,
              width: selected ? 15 : 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: selected ? .78 : .24),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _EmptyArchipelago extends StatelessWidget {
  const _EmptyArchipelago();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.water_rounded,
            size: 42, color: theme.accent.withValues(alpha: .7)),
        const SizedBox(height: 12),
        Text('第一座岛会从重复出现的光里浮起',
            style: AppText.bodyMuted.copyWith(color: theme.foregroundMuted)),
      ]),
    );
  }
}

List<List<int>> _islandRows(int count) => switch (count) {
      1 => const [
          [0],
        ],
      2 => const [
          [0, 1],
        ],
      3 => const [
          [0],
          [1, 2],
        ],
      4 => const [
          [0, 1],
          [2, 3],
        ],
      _ => const [
          [0, 1],
          [2],
          [3, 4],
        ],
    };

double _desiredIslandRadius(
  double shortest,
  int islandCount,
  int fragmentCount,
) {
  final count = fragmentCount.clamp(1, 14);
  final minimum = islandCount == 1 ? 66.0 : 42.0;
  final maximum = islandCount <= 2 ? 78.0 : 62.0;
  return (shortest * (.105 + count * .006)).clamp(minimum, maximum);
}

List<_IslandMetric> _islandMetrics(
  List<double> baseRadii,
  int islandCount,
  double scale,
) =>
    [
      for (final baseRadius in baseRadii)
        _IslandMetric.fromRadius(
          max(30.0, baseRadius * scale),
          islandCount,
        ),
    ];

bool _metricsFit(
  List<_IslandMetric> metrics,
  List<List<int>> rows,
  Rect safeRect,
) {
  const minimumColumnGap = 18.0;
  const minimumRowGap = 12.0;
  const verticalMargins = 16.0;
  var contentHeight = 0.0;
  for (final row in rows) {
    final rowMetric = _IslandRowMetrics.from(row, metrics);
    contentHeight += rowMetric.topHalf + rowMetric.bottomHalf;
    final rowWidth = row.fold<double>(
      0,
      (sum, index) => sum + metrics[index].horizontalHalf * 2,
    );
    if (rowWidth + minimumColumnGap * (row.length + 1) > safeRect.width) {
      return false;
    }
  }
  return contentHeight +
          minimumRowGap * max(0, rows.length - 1) +
          verticalMargins <=
      safeRect.height;
}

class _IslandMetric {
  const _IslandMetric({
    required this.radius,
    required this.horizontalHalf,
    required this.topHalf,
    required this.bottomHalf,
  });

  factory _IslandMetric.fromRadius(double radius, int islandCount) {
    final labelTop = radius * (islandCount <= 3 ? 1.75 : 1.40);
    final spriteHalf = radius * _spriteSizeFactor(islandCount) / 2;
    return _IslandMetric(
      radius: radius,
      horizontalHalf: max(spriteHalf, radius * 1.55),
      topHalf: max(spriteHalf, radius * 1.55),
      bottomHalf: max(spriteHalf, labelTop + 22),
    );
  }

  final double radius;
  final double horizontalHalf;
  final double topHalf;
  final double bottomHalf;
}

class _IslandRowMetrics {
  const _IslandRowMetrics({
    required this.topHalf,
    required this.bottomHalf,
  });

  factory _IslandRowMetrics.from(
    List<int> row,
    List<_IslandMetric> metrics,
  ) =>
      _IslandRowMetrics(
        topHalf: row.map((index) => metrics[index].topHalf).reduce(max),
        bottomHalf: row.map((index) => metrics[index].bottomHalf).reduce(max),
      );

  final double topHalf;
  final double bottomHalf;
}

class _IslandLayout {
  const _IslandLayout(this.items, this.safeRect);

  final List<_PlacedIsland> items;
  final Rect safeRect;

  factory _IslandLayout.build(Size size, List<IslandVisualNode> islands) {
    final shortest = min(size.width, size.height);
    final safeRect = Rect.fromLTRB(12, 10, size.width - 12, size.height - 38);
    final rows = _islandRows(islands.length);
    final baseRadii = [
      for (final island in islands)
        _desiredIslandRadius(shortest, islands.length, island.fragmentCount),
    ];
    var low = .62;
    var high = 1.0;
    for (var iteration = 0; iteration < 18; iteration++) {
      final candidate = (low + high) / 2;
      final metrics = _islandMetrics(baseRadii, islands.length, candidate);
      if (_metricsFit(metrics, rows, safeRect)) {
        low = candidate;
      } else {
        high = candidate;
      }
    }
    final metrics = _islandMetrics(baseRadii, islands.length, low);
    final rowMetrics = [
      for (final row in rows) _IslandRowMetrics.from(row, metrics),
    ];
    final contentHeight = rowMetrics.fold<double>(
      0,
      (sum, row) => sum + row.topHalf + row.bottomHalf,
    );
    final remainingHeight = max(0.0, safeRect.height - contentHeight);
    final rowGap = rows.length <= 1
        ? 0.0
        : (remainingHeight / (rows.length + 1)).clamp(12.0, 28.0);
    final outerVertical = max(
      0.0,
      (remainingHeight - rowGap * (rows.length - 1)) / 2,
    );
    final placed = <_PlacedIsland>[];
    var rowTop = safeRect.top + outerVertical;
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final rowMetric = rowMetrics[rowIndex];
      final rowWidth = row.fold<double>(
        0,
        (sum, index) => sum + metrics[index].horizontalHalf * 2,
      );
      final columnGap = (safeRect.width - rowWidth) / (row.length + 1);
      var left = safeRect.left + columnGap;
      for (final index in row) {
        final metric = metrics[index];
        final center = Offset(
          left + metric.horizontalHalf,
          rowTop + rowMetric.topHalf,
        );
        placed.add(_PlacedIsland(
          island: islands[index],
          center: center,
          radius: metric.radius,
          horizontalHalf: metric.horizontalHalf,
          topHalf: metric.topHalf,
          bottomHalf: metric.bottomHalf,
        ));
        left += metric.horizontalHalf * 2 + columnGap;
      }
      rowTop += rowMetric.topHalf + rowMetric.bottomHalf + rowGap;
    }
    return _IslandLayout(placed, safeRect);
  }

  Offset clampCenter(
    _PlacedIsland item,
    Offset proposed,
  ) {
    final minX = safeRect.left + item.horizontalHalf;
    final maxX = safeRect.right - item.horizontalHalf;
    final minY = safeRect.top + item.topHalf;
    final maxY = safeRect.bottom - item.bottomHalf;
    return Offset(
      minX <= maxX ? proposed.dx.clamp(minX, maxX) : safeRect.center.dx,
      minY <= maxY ? proposed.dy.clamp(minY, maxY) : safeRect.center.dy,
    );
  }

  _PlacedIsland? nearestItem(Offset point, {required String excluding}) {
    _PlacedIsland? nearest;
    var distance = double.infinity;
    for (final item in items) {
      if (item.island.visualKey == excluding) continue;
      final nextDistance = (point - item.center).distance;
      if (nextDistance < distance) {
        distance = nextDistance;
        nearest = item;
      }
    }
    if (nearest == null || distance > max(76, nearest.radius * 2.15)) {
      return null;
    }
    return nearest;
  }

  _PlacedIsland? hitTest(Offset point) {
    for (final item in items.reversed) {
      final hitFactor = switch (item.island.visualStage) {
        IslandVisualStage.shoal => 1.23,
        IslandVisualStage.sprouting => 1.43,
        IslandVisualStage.growing => 1.68,
        IslandVisualStage.formed => 1.90,
        IslandVisualStage.dormant => 1.90,
        IslandVisualStage.relit => 1.90,
      };
      if ((point - item.center).distance <= max(44, item.radius * hitFactor)) {
        return item;
      }
    }
    return null;
  }

  _PlacedIsland? itemFor(String? visualKey) {
    if (visualKey == null) return null;
    for (final item in items) {
      if (item.island.visualKey == visualKey) return item;
    }
    return null;
  }
}

class _PlacedIsland {
  const _PlacedIsland({
    required this.island,
    required this.center,
    required this.radius,
    required this.horizontalHalf,
    required this.topHalf,
    required this.bottomHalf,
  });

  final IslandVisualNode island;
  final Offset center;
  final double radius;
  final double horizontalHalf;
  final double topHalf;
  final double bottomHalf;

  Rect boundsAt(Offset value) => Rect.fromLTRB(
        value.dx - horizontalHalf,
        value.dy - topHalf,
        value.dx + horizontalHalf,
        value.dy + bottomHalf,
      );
}

class _SelectedIslandOverlay extends StatelessWidget {
  const _SelectedIslandOverlay({
    required this.item,
    required this.center,
    required this.islandCount,
    required this.selection,
    required this.cameraOffset,
  });

  final _PlacedIsland item;
  final Offset center;
  final int islandCount;
  final Animation<double> selection;
  final Offset cameraOffset;

  @override
  Widget build(BuildContext context) {
    final extent = item.radius * _spriteSizeFactor(islandCount);
    return Positioned(
      left: center.dx + cameraOffset.dx - extent / 2,
      top: center.dy + cameraOffset.dy - extent / 2,
      width: extent,
      height: extent,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: selection,
          builder: (context, child) => Transform.scale(
            key: const ValueKey('selected-island-scale'),
            scale: 1 +
                _selectionScaleDelta *
                    AppMotion.easeOut.transform(selection.value),
            child: child,
          ),
          child: Hero(
            tag: islandHeroTag(item.island),
            createRectTween: islandHeroRectTween,
            flightShuttleBuilder: islandHeroFlightShuttle(item.island),
            placeholderBuilder: islandHeroPlaceholder,
            transitionOnUserGestures: true,
            child: IslandSpriteVisual(
              island: item.island,
              width: extent,
              height: extent,
            ),
          ),
        ),
      ),
    );
  }
}

double _spriteSizeFactor(int islandCount) => islandCount <= 3 ? 3.75 : 2.80;

class _ArchipelagoPainter extends CustomPainter {
  const _ArchipelagoPainter({
    required this.layout,
    required this.selected,
    required this.overlayVisualKey,
    required this.cameraOffset,
    required this.breathe,
    required this.growth,
    required this.spriteReveal,
    required this.growingKeys,
    required this.spriteFamilies,
    required this.theme,
    required this.arrivalVisualKey,
    required this.arrival,
    required this.draggingVisualKey,
    required this.dragCenter,
    required this.dragTargetVisualKey,
    required this.previousCenters,
    required this.reflow,
  });

  final _IslandLayout layout;
  final IslandVisualNode? selected;
  final String? overlayVisualKey;
  final Offset cameraOffset;
  final double breathe;
  final double growth;
  final double spriteReveal;
  final Set<String> growingKeys;
  final Map<int, Map<IslandVisualStage, ui.Image>> spriteFamilies;
  final NightTheme theme;
  final String? arrivalVisualKey;
  final double arrival;
  final String? draggingVisualKey;
  final Offset? dragCenter;
  final String? dragTargetVisualKey;
  final Map<String, Offset> previousCenters;
  final double reflow;

  @override
  void paint(Canvas canvas, Size size) {
    _paintWater(canvas, size);
    canvas.save();
    canvas.translate(cameraOffset.dx, cameraOffset.dy);
    _paintTides(canvas);
    for (var i = 0; i < layout.items.length; i++) {
      _paintIsland(canvas, layout.items[i], i);
    }
    canvas.restore();
  }

  _GrowthTransform _growthTransform(double progress) {
    if (progress <= .18) {
      final t = progress / .18;
      return _GrowthTransform(
        scaleX: 1 - .06 * t,
        scaleY: 1 - .22 * t,
        rotation: sin(t * pi) * -.025,
      );
    }
    final t = ((progress - .18) / .82).clamp(0.0, 1.0);
    final spring = AppMotion.growthSpring.transform(t);
    return _GrowthTransform(
      scaleX: .68 + .32 * spring,
      scaleY: .60 + .40 * spring,
      rotation: sin(t * pi * 2) * .018 * (1 - t),
    );
  }

  void _paintWater(Canvas canvas, Size size) {
    paintIslandSeaAtmosphere(canvas, size, theme, breathe);
  }

  void _paintTides(Canvas canvas) {
    for (final item in layout.items) {
      final tideColor =
          theme.isNight ? AppColors.islandTideNight : AppColors.islandTideDay;
      for (var ring = 0; ring < 2; ring++) {
        final spread = item.radius * (3.05 + ring * .52);
        canvas.drawOval(
          Rect.fromCenter(
            center: _animatedCenter(item),
            width: spread * 1.12,
            height: spread * .72,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = tideColor.withValues(
              alpha: theme.isNight ? .055 - ring * .016 : .075 - ring * .02,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
  }

  void _paintIsland(Canvas canvas, _PlacedIsland item, int index) {
    final isSelected = selected?.visualKey == item.island.visualKey;
    final isDimmed = selected != null && !isSelected;
    final radius = item.radius;
    final color = _islandColor(index, item.island.island.name);
    final isDragging = draggingVisualKey == item.island.visualKey;
    final isDragTarget = dragTargetVisualKey == item.island.visualKey;
    final isArriving = arrivalVisualKey == item.island.visualKey && arrival < 1;

    canvas.save();
    final center = _animatedCenter(item);
    canvas.translate(center.dx, center.dy);
    if (isArriving) {
      final t = Curves.easeOutBack.transform(arrival.clamp(0, 1));
      canvas.scale(.42 + .58 * t);
    }
    if (isDragging) {
      canvas.scale(1.07);
    } else if (isDragTarget) {
      canvas.scale(1.035);
    }
    if (growingKeys.contains(item.island.visualKey)) {
      final transform = _growthTransform(growth);
      canvas.rotate(transform.rotation);
      canvas.scale(transform.scaleX, transform.scaleY);
    }
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        color.withValues(
          alpha: isDimmed ? .03 : (isDragging || isDragTarget ? .34 : .22),
        ),
        color.withValues(alpha: 0),
      ]).createShader(
          Rect.fromCircle(center: Offset.zero, radius: radius * 1.7));
    canvas.drawCircle(Offset.zero, radius * 1.7, glow);

    final availableFamilies = spriteFamilies.length;
    final familyIndex = availableFamilies == 0
        ? 0
        : item.island.visualFamily % availableFamilies;
    final family = spriteFamilies[familyIndex] ?? spriteFamilies[0];
    final sprite =
        family?[item.island.visualStage] ?? family?[IslandVisualStage.formed];
    if (sprite != null) {
      if (overlayVisualKey != item.island.visualKey) {
        _paintSprite(
          canvas,
          sprite,
          item.island.visualStage,
          radius,
          isDimmed,
        );
      }
      _paintMediaOrbit(canvas, item, radius, color, isDimmed);
      _paintLabel(canvas, item, radius, isDimmed);
      if (growingKeys.contains(item.island.visualKey)) {
        _paintGrowthBurst(canvas, radius, color, isDimmed);
      }
      canvas.restore();
      return;
    }

    // 贴图解码完成前只保留水面微光和名称，不绘制程序化假岛。
    // 这样真实素材出现时不会发生轮廓与质感突然替换的“换皮”。
    _paintLabel(canvas, item, radius, isDimmed);
    canvas.restore();
  }

  Offset _animatedCenter(_PlacedIsland item) {
    final key = item.island.visualKey;
    final dragged = draggingVisualKey == key ? dragCenter : null;
    final previous = previousCenters[key];
    final settled = dragged ??
        (previous == null
            ? item.center
            : Offset.lerp(
                previous,
                item.center,
                AppMotion.microMovement.transform(reflow.clamp(0, 1)),
              )!);
    final visualKey = arrivalVisualKey;
    if (visualKey == null || arrival >= 1 || key == visualKey) {
      return settled;
    }
    final arriving = layout.itemFor(visualKey);
    if (arriving == null) return settled;
    final away = settled - arriving.center;
    if (away.distance < 1) return settled;
    final push = min(34.0, away.distance * .22);
    final start = settled - away / away.distance * push;
    return Offset.lerp(
      start,
      settled,
      Curves.easeOutCubic.transform(arrival.clamp(0, 1)),
    )!;
  }

  void _paintSprite(
    Canvas canvas,
    ui.Image sprite,
    IslandVisualStage _,
    double radius,
    bool dimmed,
  ) {
    final source = Rect.fromLTWH(
      0,
      0,
      sprite.width.toDouble(),
      sprite.height.toDouble(),
    );
    // 六阶段素材来自同一张定标总图。这里必须使用相同倍率，岛体的真实
    // 生长由素材自身表达；否则会把浅滩强行放大成与成形岛相同的体量。
    final sizeFactor = _spriteSizeFactor(layout.items.length);
    final extent = radius * sizeFactor;
    final aspect = sprite.width / sprite.height;
    final destination = Rect.fromCenter(
      center: Offset.zero,
      width: aspect >= 1 ? extent : extent * aspect,
      height: aspect >= 1 ? extent / aspect : extent,
    );
    canvas.drawImageRect(
      sprite,
      source,
      destination,
      Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = islandSpriteColorFilter
        ..color = AppColors.white.withValues(
          alpha: (dimmed ? .24 : 1) * spriteReveal,
        ),
    );
  }

  void _paintGrowthBurst(
    Canvas canvas,
    double radius,
    Color color,
    bool dimmed,
  ) {
    if (growth < .16 || growth > .78) return;
    final t = ((growth - .16) / .62).clamp(0.0, 1.0);
    final opacity = sin(t * pi) * (dimmed ? .10 : .68);
    final distance = radius * (.72 + t * .62);
    for (var i = 0; i < 9; i++) {
      final angle = i / 9 * pi * 2 + .24;
      final center = Offset(cos(angle), sin(angle)) * distance;
      canvas.drawCircle(
        center,
        1.4 + (i % 3) * .55,
        Paint()
          ..color = Color.lerp(color, AppColors.white, .56)!
              .withValues(alpha: opacity),
      );
    }
  }

  void _paintMediaOrbit(
    Canvas canvas,
    _PlacedIsland item,
    double radius,
    Color color,
    bool dimmed,
  ) {
    final total = min(8, item.island.fragmentCount);
    if (total == 0) return;
    final densityScale = layout.items.length <= 3 ? 1.0 : .84;
    final orbitFactor = switch (item.island.visualStage) {
      IslandVisualStage.shoal => 1.18,
      IslandVisualStage.sprouting => 1.38,
      IslandVisualStage.growing => 1.67,
      IslandVisualStage.formed => 1.88,
      IslandVisualStage.dormant => 1.88,
      IslandVisualStage.relit => 1.88,
    };
    for (var i = 0; i < total; i++) {
      final angle = i / total * pi * 2 + .4;
      final center =
          Offset(cos(angle), sin(angle)) * radius * orbitFactor * densityScale;
      final alpha = dimmed ? .10 : .72;
      if (i < item.island.imageCount) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: 7, height: 7),
            const Radius.circular(2),
          ),
          Paint()..color = AppColors.white.withValues(alpha: alpha),
        );
      } else if (i < item.island.imageCount + item.island.audioCount) {
        canvas.drawCircle(center, 4.2,
            Paint()..color = AppColors.white.withValues(alpha: alpha));
        canvas.drawCircle(
          center,
          7 + sin(breathe * pi * 2 + i) * 1.2,
          Paint()
            ..color = color.withValues(alpha: alpha * .35)
            ..style = PaintingStyle.stroke,
        );
      } else {
        canvas.drawCircle(center, 3.2,
            Paint()..color = AppColors.white.withValues(alpha: alpha));
      }
    }
  }

  void _paintLabel(
      Canvas canvas, _PlacedIsland item, double radius, bool dimmed) {
    final title = TextPainter(
      text: TextSpan(
        text: '${item.island.island.name} · ${item.island.fragmentCount} 束',
        style: AppText.captionStrong.copyWith(
          color: theme.foreground.withValues(alpha: dimmed ? .28 : .94),
          shadows: [
            Shadow(
              color: theme.background.withValues(alpha: dimmed ? .18 : .72),
              blurRadius: 6,
            ),
          ],
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: item.horizontalHalf * 2);
    title.paint(
      canvas,
      Offset(
        -title.width / 2,
        radius * (layout.items.length <= 3 ? 1.75 : 1.40),
      ),
    );
  }

  Color _islandColor(int index, String name) {
    const colors = [
      AppColors.teaGreen,
      AppColors.mistBlue,
      AppColors.lilac,
      AppColors.sunsetCoral,
      AppColors.emotionCalm,
      AppColors.emotionHappy,
      AppColors.emotionTired,
    ];
    return colors[(name.hashCode.abs() + index) % colors.length];
  }

  @override
  bool shouldRepaint(covariant _ArchipelagoPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.selected != selected ||
      oldDelegate.overlayVisualKey != overlayVisualKey ||
      oldDelegate.cameraOffset != cameraOffset ||
      oldDelegate.breathe != breathe ||
      oldDelegate.growth != growth ||
      oldDelegate.spriteReveal != spriteReveal ||
      oldDelegate.growingKeys != growingKeys ||
      oldDelegate.spriteFamilies != spriteFamilies ||
      oldDelegate.theme != theme ||
      oldDelegate.arrivalVisualKey != arrivalVisualKey ||
      oldDelegate.arrival != arrival ||
      oldDelegate.draggingVisualKey != draggingVisualKey ||
      oldDelegate.dragCenter != dragCenter ||
      oldDelegate.dragTargetVisualKey != dragTargetVisualKey ||
      oldDelegate.previousCenters != previousCenters ||
      oldDelegate.reflow != reflow;
}

class _GrowthTransform {
  const _GrowthTransform({
    required this.scaleX,
    required this.scaleY,
    required this.rotation,
  });

  final double scaleX;
  final double scaleY;
  final double rotation;
}
