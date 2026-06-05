import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiguang/main.dart';

void main() {
  testWidgets('mobile preview frames', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const XiguangApp());
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(XiguangApp),
      matchesGoldenFile('goldens/01_capture.png'),
    );

    await tester.tap(find.text('时间线'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(XiguangApp),
      matchesGoldenFile('goldens/02_timeline.png'),
    );

    await tester.tap(find.text('小宇宙'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(XiguangApp),
      matchesGoldenFile('goldens/03_universe.png'),
    );
  });
}
