import 'package:flutter_test/flutter_test.dart';

import 'package:xiguang/main.dart';

void main() {
  testWidgets('Xiguang prototype renders primary mobile tabs', (tester) async {
    await tester.pumpWidget(const XiguangApp());

    expect(find.text('写下此刻'), findsOneWidget);
    expect(find.text('记录'), findsOneWidget);
    expect(find.text('时间线'), findsOneWidget);
    expect(find.text('小宇宙'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    await tester.tap(find.text('时间线'));
    await tester.pumpAndSettle();
    expect(find.text('雨声把窗台变得很近'), findsOneWidget);

    await tester.tap(find.text('小宇宙'));
    await tester.pumpAndSettle();
    expect(find.text('近期星图'), findsOneWidget);
  });
}
