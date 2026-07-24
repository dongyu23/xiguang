import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/features/island/domain/island_model.dart';
import 'package:xiguang/features/island/domain/universe_overview.dart';
import 'package:xiguang/features/island/presentation/widgets/island_detail_hero.dart';
import 'package:xiguang/features/island/presentation/widgets/island_sprite_visual.dart';

void main() {
  testWidgets('empty manual island is one visual hero with one clear action',
      (tester) async {
    const island = IslandVisualNode(
      island: IslandModel(
        name: '考试周',
        status: 'star_point',
        fragmentCount: 0,
        description: '',
        manual: true,
      ),
      fragments: [],
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: xiguangTheme(nightMode: true),
        home: Scaffold(
          body: IslandDetailHero(
            island: island,
            onAdd: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('island-detail-hero')), findsOneWidget);
    expect(find.text('考试周'), findsOneWidget);
    expect(find.text('初生浅滩 · 0 束光'), findsOneWidget);
    expect(find.text('放入第一束光'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, islandHeroTag(island));
    expect(hero.flightShuttleBuilder, isNotNull);
    expect(hero.placeholderBuilder, isNotNull);
    expect(tester.takeException(), isNull);
  });

  test('island hero tween moves its center and scales continuously', () {
    const begin = Rect.fromLTWH(38, 350, 92, 92);
    const end = Rect.fromLTWH(81, 112, 228, 228);
    final tween = islandHeroRectTween(begin, end);

    expect(tween.lerp(0), begin);
    expect(tween.lerp(1), end);

    final middle = tween.lerp(.5)!;
    expect(middle.center.dx, inExclusiveRange(begin.center.dx, end.center.dx));
    expect(middle.center.dy, inExclusiveRange(end.center.dy, begin.center.dy));
    expect(middle.width, inExclusiveRange(begin.width, end.width));
    expect(middle.height, inExclusiveRange(begin.height, end.height));

    final moved = (middle.center.dy - begin.center.dy) /
        (end.center.dy - begin.center.dy);
    final scaled = (middle.width - begin.width) / (end.width - begin.width);
    expect(moved, closeTo(scaled, .001));
  });
}
