import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/typography.dart';
import '../../domain/universe_overview.dart';

class BranchRiverCanvas extends StatefulWidget {
  const BranchRiverCanvas({
    super.key,
    required this.branches,
    required this.selectedBranch,
    required this.selectedNodeId,
    required this.onSelectBranch,
    required this.onSelectNode,
    this.interactive = false,
  });

  final List<BranchVisualSummary> branches;
  final BranchVisualSummary? selectedBranch;
  final int? selectedNodeId;
  final ValueChanged<BranchVisualSummary?> onSelectBranch;
  final ValueChanged<int?> onSelectNode;
  final bool interactive;

  @override
  State<BranchRiverCanvas> createState() => _BranchRiverCanvasState();
}

class _BranchRiverCanvasState extends State<BranchRiverCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw;

  @override
  void initState() {
    super.initState();
    _draw = AnimationController(vsync: this, duration: AppMotion.slow)
      ..forward();
  }

  @override
  void didUpdateWidget(covariant BranchRiverCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branches != widget.branches) _draw.forward(from: 0);
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.branches.isEmpty) return const _EmptyRiver();
    return LayoutBuilder(builder: (context, constraints) {
      final layout = _BranchLayout.build(
        Size(constraints.maxWidth, constraints.maxHeight),
        widget.branches.take(4).toList(),
      );
      final canvas = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final node = layout.hitNode(details.localPosition);
          if (node != null) {
            widget.onSelectBranch(node.branch);
            widget.onSelectNode(node.fragmentId);
            return;
          }
          widget.onSelectNode(null);
          widget.onSelectBranch(layout.hitBranch(details.localPosition));
        },
        onLongPressStart: (details) {
          final node = layout.hitNode(details.localPosition);
          if (node == null) return;
          HapticFeedback.mediumImpact();
          widget.onSelectBranch(node.branch);
          widget.onSelectNode(node.fragmentId);
        },
        child: AnimatedBuilder(
          animation: _draw,
          builder: (_, __) => CustomPaint(
            painter: _BranchPainter(
              layout: layout,
              selectedBranch: widget.selectedBranch,
              selectedNodeId: widget.selectedNodeId,
              progress: Curves.easeOutCubic.transform(_draw.value),
              theme: NightTheme.of(context),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
      if (!widget.interactive) return canvas;
      return InteractiveViewer(
        minScale: .8,
        maxScale: 2.4,
        boundaryMargin: const EdgeInsets.all(80),
        child: canvas,
      );
    });
  }
}

class _EmptyRiver extends StatelessWidget {
  const _EmptyRiver();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.route_rounded,
            size: 42, color: theme.accent.withValues(alpha: .7)),
        const SizedBox(height: 12),
        Text('选择两束光，织出第一条支线',
            style: AppText.bodyMuted.copyWith(color: theme.foregroundMuted)),
      ]),
    );
  }
}

class _BranchLayout {
  const _BranchLayout(this.nodes, this.edges, this.branchPaths);

  final List<_RiverNode> nodes;
  final List<_RiverEdge> edges;
  final Map<BranchVisualSummary, Path> branchPaths;

  factory _BranchLayout.build(Size size, List<BranchVisualSummary> branches) {
    final nodes = <_RiverNode>[];
    final edges = <_RiverEdge>[];
    final branchPaths = <BranchVisualSummary, Path>{};
    final laneWidth = size.width / (branches.length + 1);
    const top = 42.0;
    final bottom = max(top + 40, size.height - 44);
    for (var lane = 0; lane < branches.length; lane++) {
      final branch = branches[lane];
      final shown = branch.fragments.take(7).toList();
      final x = laneWidth * (lane + 1);
      final step =
          shown.length <= 1 ? 0.0 : (bottom - top) / (shown.length - 1);
      final byId = <int, _RiverNode>{};
      for (var i = 0; i < shown.length; i++) {
        final drift = sin(i * 1.7 + lane) * min(18, laneWidth * .16);
        final node = _RiverNode(
          branch: branch,
          fragmentId: shown[i].id,
          center: Offset(x + drift, top + step * i),
          label: shown[i].time,
        );
        nodes.add(node);
        byId[node.fragmentId] = node;
      }
      final path = Path();
      for (var i = 0; i < shown.length; i++) {
        final center = byId[shown[i].id]!.center;
        if (i == 0) {
          path.moveTo(center.dx, center.dy);
        } else {
          final previous = byId[shown[i - 1].id]!.center;
          path.cubicTo(
            previous.dx,
            (previous.dy + center.dy) / 2,
            center.dx,
            (previous.dy + center.dy) / 2,
            center.dx,
            center.dy,
          );
        }
      }
      branchPaths[branch] = path;
      for (final edge in branch.edges) {
        final source = byId[edge.relation.sourceFragmentId];
        final target = byId[edge.relation.targetFragmentId];
        if (source != null && target != null) {
          edges.add(_RiverEdge(
            branch: branch,
            source: source.center,
            target: target.center,
            direction: edge.direction,
          ));
        }
      }
    }
    return _BranchLayout(nodes, edges, branchPaths);
  }

  _RiverNode? hitNode(Offset point) {
    for (final node in nodes.reversed) {
      if ((point - node.center).distance <= 26) return node;
    }
    return null;
  }

  BranchVisualSummary? hitBranch(Offset point) {
    BranchVisualSummary? closest;
    var distance = double.infinity;
    for (final node in nodes) {
      final current = (point - node.center).distance;
      if (current < distance) {
        distance = current;
        closest = node.branch;
      }
    }
    return distance <= 54 ? closest : null;
  }
}

class _RiverNode {
  const _RiverNode({
    required this.branch,
    required this.fragmentId,
    required this.center,
    required this.label,
  });

  final BranchVisualSummary branch;
  final int fragmentId;
  final Offset center;
  final String label;
}

class _RiverEdge {
  const _RiverEdge({
    required this.branch,
    required this.source,
    required this.target,
    required this.direction,
  });

  final BranchVisualSummary branch;
  final Offset source;
  final Offset target;
  final RelationDirection direction;
}

class _BranchPainter extends CustomPainter {
  const _BranchPainter({
    required this.layout,
    required this.selectedBranch,
    required this.selectedNodeId,
    required this.progress,
    required this.theme,
  });

  final _BranchLayout layout;
  final BranchVisualSummary? selectedBranch;
  final int? selectedNodeId;
  final double progress;
  final NightTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < layout.branchPaths.length; i++) {
      final entry = layout.branchPaths.entries.elementAt(i);
      final color = _branchColor(i);
      final selected =
          selectedBranch == null || identical(selectedBranch, entry.key);
      final metrics = entry.value.computeMetrics().toList();
      if (metrics.isEmpty) continue;
      final metric = metrics.first;
      final visible = metric.extractPath(0, metric.length * progress);
      canvas.drawPath(
        visible,
        Paint()
          ..color = color.withValues(alpha: selected ? .52 : .12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.2 : 1.2
          ..strokeCap = StrokeCap.round,
      );
      _paintBranchName(canvas, entry.key, i, color, selected);
    }
    for (final edge in layout.edges) {
      final lane = layout.branchPaths.keys.toList().indexOf(edge.branch);
      final color = _branchColor(max(0, lane));
      final selected =
          selectedBranch == null || identical(selectedBranch, edge.branch);
      if (!selected) continue;
      _paintArrow(canvas, edge.source, edge.target, color,
          reverse: edge.direction == RelationDirection.bidirectional);
    }
    for (final node in layout.nodes) {
      final lane = layout.branchPaths.keys.toList().indexOf(node.branch);
      final color = _branchColor(max(0, lane));
      final branchSelected =
          selectedBranch == null || identical(selectedBranch, node.branch);
      final nodeSelected = selectedNodeId == node.fragmentId;
      final radius = nodeSelected ? 10.5 : 7.0;
      if (nodeSelected) {
        canvas.drawCircle(
          node.center,
          24,
          Paint()
            ..shader = RadialGradient(colors: [
              color.withValues(alpha: .32),
              color.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: node.center, radius: 24)),
        );
      }
      canvas.drawCircle(
        node.center,
        radius,
        Paint()..color = color.withValues(alpha: branchSelected ? .94 : .20),
      );
      canvas.drawCircle(
        node.center,
        radius + 4,
        Paint()
          ..color = theme.foreground.withValues(
              alpha: nodeSelected
                  ? .38
                  : branchSelected
                      ? .14
                      : .04)
          ..style = PaintingStyle.stroke,
      );
      if (nodeSelected) _paintNodeLabel(canvas, node);
    }
  }

  void _paintBranchName(Canvas canvas, BranchVisualSummary branch, int lane,
      Color color, bool selected) {
    final nodes = layout.nodes.where((node) => identical(node.branch, branch));
    if (nodes.isEmpty) return;
    final first = nodes.first.center;
    final text = TextPainter(
      text: TextSpan(
        text: branch.name,
        style: AppText.microLabel.copyWith(
          color: selected
              ? theme.foreground.withValues(alpha: .82)
              : theme.foregroundMuted.withValues(alpha: .18),
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 88);
    text.paint(canvas, Offset(first.dx - text.width / 2, 10 + lane * 2));
  }

  void _paintNodeLabel(Canvas canvas, _RiverNode node) {
    final text = TextPainter(
      text: TextSpan(
        text: node.label,
        style: AppText.microLabel.copyWith(color: theme.foreground),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, node.center + Offset(14, -text.height / 2));
  }

  void _paintArrow(Canvas canvas, Offset source, Offset target, Color color,
      {required bool reverse}) {
    final delta = target - source;
    if (delta.distance < 20) return;
    final direction = delta / delta.distance;
    final end = target - direction * 13;
    _arrowHead(canvas, end, direction, color);
    if (reverse) {
      final start = source + direction * 13;
      _arrowHead(canvas, start, -direction, color.withValues(alpha: .74));
    }
  }

  void _arrowHead(Canvas canvas, Offset tip, Offset direction, Color color) {
    final perpendicular = Offset(-direction.dy, direction.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((tip - direction * 7 + perpendicular * 3.5).dx,
          (tip - direction * 7 + perpendicular * 3.5).dy)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((tip - direction * 7 - perpendicular * 3.5).dx,
          (tip - direction * 7 - perpendicular * 3.5).dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  Color _branchColor(int index) => const [
        AppColors.teaGreen,
        AppColors.mistBlue,
        AppColors.lilac,
        AppColors.sunsetCoral,
      ][index % 4];

  @override
  bool shouldRepaint(covariant _BranchPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.selectedBranch != selectedBranch ||
      oldDelegate.selectedNodeId != selectedNodeId ||
      oldDelegate.progress != progress ||
      oldDelegate.theme != theme;
}
