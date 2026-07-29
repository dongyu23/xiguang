import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _goldenPixelTolerance = 0.04;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final comparator = goldenFileComparator;
  if (comparator is LocalFileComparator) {
    goldenFileComparator = _CrossPlatformGoldenComparator(
      comparator.basedir,
      precisionTolerance: _goldenPixelTolerance,
    );
  }
  await testMain();
}

/// Keeps meaningful layout regressions gated while tolerating the small font
/// rasterization and Skia differences between Windows authoring and Linux CI.
class _CrossPlatformGoldenComparator extends LocalFileComparator {
  _CrossPlatformGoldenComparator(
    Uri basedir, {
    required double precisionTolerance,
  })  : _precisionTolerance = precisionTolerance,
        super(basedir.resolve('_golden_comparator.dart'));

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _precisionTolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
