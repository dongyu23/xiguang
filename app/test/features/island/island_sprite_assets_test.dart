import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/island/domain/island_visual_stage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every island family and growth stage has a bundled sprite', () async {
    for (var family = 0; family < 6; family++) {
      for (final stage in IslandVisualStage.values) {
        final data = await rootBundle.load(
          'assets/islands/family_$family/${stage.name}.png',
        );
        expect(
          data.lengthInBytes,
          greaterThan(0),
          reason: 'family_$family/${stage.name}',
        );
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 512, reason: 'family_$family/${stage.name}');
        expect(frame.image.height, 512, reason: 'family_$family/${stage.name}');
        frame.image.dispose();
        codec.dispose();
      }
    }
  });
}
