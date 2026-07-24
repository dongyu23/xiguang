import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/features/fragment/domain/fragment.dart';
import 'package:xiguang/features/island/domain/island_model.dart';
import 'package:xiguang/features/island/domain/universe_overview.dart';
import 'package:xiguang/features/island/presentation/widgets/island_archipelago_canvas.dart';

void main() {
  testWidgets('island stage change plays and settles the growth animation',
      (tester) async {
    final islands = ValueNotifier<List<IslandVisualNode>>([
      _island(status: 'star_point'),
    ]);
    addTearDown(islands.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: xiguangTheme(nightMode: true),
        home: Scaffold(
          body: ValueListenableBuilder<List<IslandVisualNode>>(
            valueListenable: islands,
            builder: (context, value, _) => IslandArchipelagoCanvas(
              islands: value,
              selected: null,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    islands.value = [_island(status: 'growing')];
    await tester.pump();
    expect(_growthProgress(tester), 0);
    expect(_growingIslandCount(tester), 1);

    await tester.pump(const Duration(milliseconds: 180));
    expect(_growthProgress(tester), greaterThan(0));
    expect(_growthProgress(tester), lessThan(1));
    expect(_growingIslandCount(tester), 1);

    await tester.pump(const Duration(milliseconds: 740));
    expect(_growthProgress(tester), 1);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_growingIslandCount(tester), 0);
    expect(tester.takeException(), isNull);
  });
}

IslandVisualNode _island({required String status}) {
  return IslandVisualNode(
    island: IslandModel(
      islandId: 77,
      name: '会生长的岛',
      status: status,
      fragmentCount: 1,
      description: '',
    ),
    fragments: [
      Fragment(
        id: 1,
        publicId: 'growth-fragment',
        contentText: '第一束光',
        createdAt: DateTime.utc(2026, 7, 12),
      ),
    ],
  );
}

dynamic _archipelagoPainter(WidgetTester tester) {
  for (final paint
      in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
    final painter = paint.painter;
    if (painter != null &&
        painter.runtimeType.toString() == '_ArchipelagoPainter') {
      return painter;
    }
  }
  fail('Archipelago painter was not found');
}

double _growthProgress(WidgetTester tester) {
  final dynamic painter = _archipelagoPainter(tester);
  return painter.growth as double;
}

int _growingIslandCount(WidgetTester tester) {
  final dynamic painter = _archipelagoPainter(tester);
  return (painter.growingKeys as Set<Object?>).length;
}
