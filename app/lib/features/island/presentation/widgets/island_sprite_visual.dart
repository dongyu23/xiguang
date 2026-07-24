import 'package:flutter/material.dart';

import '../../../../design/tokens/motion.dart';
import '../../domain/island_visual_stage.dart';
import '../../domain/universe_overview.dart';

const islandSpriteColorFilter = ColorFilter.matrix([
  .88,
  .04,
  .04,
  0,
  7,
  .04,
  .88,
  .04,
  0,
  7,
  .04,
  .04,
  .88,
  0,
  7,
  0,
  0,
  0,
  1,
  0,
]);

String islandSpriteAsset(IslandVisualNode island) {
  final family = island.visualFamily % 6;
  return 'assets/islands/family_$family/${island.visualStage.name}.png';
}

String islandHeroTag(IslandVisualNode island) =>
    'island-visual-${island.visualKey}';

RectTween islandHeroRectTween(Rect? begin, Rect? end) =>
    _IslandHeroRectTween(begin: begin, end: end);

HeroFlightShuttleBuilder islandHeroFlightShuttle(IslandVisualNode island) {
  return (flightContext, animation, direction, fromContext, toContext) {
    return FittedBox(
      fit: BoxFit.contain,
      child: IslandSpriteVisual(
        island: island,
        width: 512,
        height: 512,
      ),
    );
  };
}

Widget islandHeroPlaceholder(
  BuildContext context,
  Size heroSize,
  Widget child,
) {
  return SizedBox.fromSize(size: heroSize);
}

class _IslandHeroRectTween extends RectTween {
  _IslandHeroRectTween({required super.begin, required super.end});

  @override
  Rect lerp(double t) {
    final from = begin!;
    final to = end!;
    final travelT = AppMotion.microMovement.transform(t);
    final center = Offset.lerp(from.center, to.center, travelT)!;
    final width = from.width + (to.width - from.width) * travelT;
    final height = from.height + (to.height - from.height) * travelT;
    return Rect.fromCenter(center: center, width: width, height: height);
  }
}

class IslandSpriteVisual extends StatelessWidget {
  const IslandSpriteVisual({
    super.key,
    required this.island,
    required this.width,
    required this.height,
  });

  final IslandVisualNode island;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: islandSpriteColorFilter,
      child: Image.asset(
        islandSpriteAsset(island),
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
