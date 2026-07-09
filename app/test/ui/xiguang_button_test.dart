import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/ui/composites/xiguang_button.dart';

void main() {
  testWidgets('compact primary button keeps its intrinsic width',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: xiguangTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: Row(
              children: [
                const Expanded(child: Text('管理心情')),
                XiguangButton(
                  label: '新增',
                  expand: false,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.widgetWithText(FilledButton, '新增')).width,
      lessThan(120),
    );
    expect(tester.getSize(find.text('管理心情')).height, lessThan(40));
  });
}
