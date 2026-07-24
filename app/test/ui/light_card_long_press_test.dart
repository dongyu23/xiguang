import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/ui/composites/light_card.dart';

void main() {
  testWidgets('timeline light card eases into its long-press state',
      (tester) async {
    var longPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: xiguangTheme(),
        home: Scaffold(
          body: LightFragmentCard(
            fragment: const LightFragment(
              time: '19:43',
              date: '今天',
              title: '一束测试光',
              text: '风从窗边轻轻经过。',
              emotion: '平静',
              tags: ['夜晚'],
              color: Color(0xFF9EBBCC),
            ),
            dense: true,
            onTap: () {},
            onLongPress: () => longPressed = true,
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(LightFragmentCard));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 200));

    final pressScale = find.byKey(const ValueKey('light-card-press-scale'));
    expect(tester.widget<AnimatedScale>(pressScale).scale, closeTo(.988, .001));

    await tester.pump(kLongPressTimeout);
    expect(longPressed, isTrue);
    expect(tester.widget<AnimatedScale>(pressScale).scale, closeTo(.972, .001));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(pressScale).scale, 1);
  });

  testWidgets('selection control centers and shifts card content smoothly',
      (tester) async {
    var selectionMode = false;
    late StateSetter update;

    Widget buildCard() {
      return MaterialApp(
        theme: xiguangTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return LightFragmentCard(
                fragment: const LightFragment(
                  time: '19:43',
                  date: '今天',
                  title: '一束测试光',
                  text: '风从窗边轻轻经过。',
                  emotion: '平静',
                  tags: ['夜晚'],
                  color: Color(0xFF9EBBCC),
                ),
                dense: true,
                selectionMode: selectionMode,
                showSelectionControl: selectionMode,
                selected: selectionMode,
                onSelectionTap: () {},
                onTap: () {},
              );
            },
          ),
        ),
      );
    }

    await tester.pumpWidget(buildCard());
    final slot = find.byKey(const ValueKey('light-card-selection-slot'));
    final media = find.byKey(const ValueKey('light-card-media-thumb'));
    final row = find.byKey(const ValueKey('light-card-content-row'));
    final startX = tester.getTopLeft(media).dx;

    update(() => selectionMode = true);
    await tester.pump();
    expect(tester.getSize(slot).width, 0);
    expect(tester.getTopLeft(media).dx, startX);

    await tester.pump(const Duration(milliseconds: 130));
    final middleWidth = tester.getSize(slot).width;
    final middleX = tester.getTopLeft(media).dx;
    expect(middleWidth, greaterThan(0));
    expect(middleWidth, lessThan(34));
    expect(middleX, greaterThan(startX));

    await tester.pumpAndSettle();
    expect(tester.getSize(slot).width, 34);
    expect(tester.getTopLeft(media).dx, greaterThan(middleX));
    expect(
      tester.getCenter(slot).dy,
      closeTo(tester.getCenter(row).dy, .5),
    );
  });
}
