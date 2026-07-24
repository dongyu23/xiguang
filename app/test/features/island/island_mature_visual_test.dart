import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/features/fragment/domain/fragment.dart';
import 'package:xiguang/features/island/domain/island_model.dart';
import 'package:xiguang/features/island/domain/universe_overview.dart';
import 'package:xiguang/features/island/presentation/widgets/island_archipelago_canvas.dart';

void main() {
  testWidgets('mature island families stay readable on a phone canvas',
      (tester) async {
    tester.view.physicalSize = const Size(390, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: xiguangTheme(nightMode: true),
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('mature-island-preview'),
            child: IslandArchipelagoCanvas(
              islands: [
                _matureIsland(id: 3, name: 'Lake Garden', count: 8),
                _matureIsland(id: 1, name: 'Long Bay', count: 5),
                _matureIsland(id: 2, name: 'Mist Grove', count: 11),
              ],
              selected: null,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (_loadedFamilyCount(tester) == 6) break;
    }

    expect(tester.takeException(), isNull);
    expect(_loadedFamilyCount(tester), 6);
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byKey(const ValueKey('mature-island-preview')),
      matchesGoldenFile('goldens/island_mature_families.png'),
    );
  });
}

int _loadedFamilyCount(WidgetTester tester) {
  for (final paint
      in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
    final painter = paint.painter;
    if (painter != null &&
        painter.runtimeType.toString() == '_ArchipelagoPainter') {
      final dynamic archipelagoPainter = painter;
      return (archipelagoPainter.spriteFamilies as Map<Object?, Object?>)
          .length;
    }
  }
  return 0;
}

IslandVisualNode _matureIsland({
  required int id,
  required String name,
  required int count,
}) {
  return IslandVisualNode(
    island: IslandModel(
      islandId: id,
      name: name,
      status: 'formed',
      fragmentCount: count,
      description: '',
    ),
    fragments: List.generate(
      count,
      (index) => Fragment(
        id: id * 100 + index,
        publicId: '$id-$index',
        contentText: '光片 $index',
        createdAt: DateTime.utc(2026, 7, 12),
      ),
    ),
  );
}
