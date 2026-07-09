import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/ui/composites/xiguang_button.dart';
import 'package:xiguang/ui/composites/xiguang_card.dart';
import 'package:xiguang/ui/composites/xiguang_chip.dart';
import 'package:xiguang/ui/composites/xiguang_input.dart';
import 'package:xiguang/ui/composites/xiguang_section.dart';

void main() {
  testWidgets('Xiguang core components preserve a coherent interaction surface',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        theme: xiguangTheme(),
        home: Scaffold(
          body: XiguangCard(
            child: XiguangSection(
              title: '一束光',
              description: '组件从主题读取语义色。',
              child: Column(
                children: [
                  XiguangInput(controller: controller, hint: '写下一句话'),
                  XiguangChip(label: '平静', selected: true),
                  XiguangButton(label: '捕光', onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '测试光片');
    expect(controller.text, '测试光片');
    expect(find.text('捕光'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
