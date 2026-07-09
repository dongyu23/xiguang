import 'package:flutter/foundation.dart';

class StarNode {
  const StarNode({
    required this.fragmentId,
    required this.x,
    required this.y,
    required this.label,
  });

  final int fragmentId;
  final double x;
  final double y;
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarNode &&
          fragmentId == other.fragmentId &&
          x == other.x &&
          y == other.y &&
          label == other.label;

  @override
  int get hashCode => Object.hash(fragmentId, x, y, label);
}
