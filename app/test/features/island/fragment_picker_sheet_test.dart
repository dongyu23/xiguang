import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/features/fragment/application/fragment_list_controller.dart';
import 'package:xiguang/features/fragment/domain/fragment.dart';
import 'package:xiguang/features/island/presentation/widgets/fragment_picker_sheet.dart';
import 'package:xiguang/ui/composites/xiguang_chip.dart';

void main() {
  testWidgets('picker uses selectable light rows and a fixed confirm action',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _FakeFragmentsNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [fragmentsProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          theme: xiguangTheme(nightMode: true),
          home: Scaffold(
            body: FragmentPickerSheet(onConfirm: (_) async => true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('把光放进小岛'), findsOneWidget);
    expect(find.text('选择想放入的光片'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('今天下载了隙光APP，好开心'), findsOneWidget);
    expect(find.text('你好'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('fragment-picker-filter-toggle')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('fragment-picker-filter-panel')),
      findsOneWidget,
    );
    expect(find.text('情绪'), findsOneWidget);
    expect(find.text('时间'), findsOneWidget);
    expect(find.text('媒介'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('顺序'), findsOneWidget);

    await tester.tap(find.widgetWithText(XiguangChip, '开心'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('你好'), findsNothing);
    expect(find.text('筛选 · 1'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('fragment-picker-filter-toggle')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fragment-picker-row-1')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('已选 1'), findsOneWidget);
    expect(find.text('放入小岛 · 1 束'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeFragmentsNotifier extends FragmentsNotifier {
  @override
  Future<List<Fragment>> build() async => [
        Fragment(
          id: 1,
          contentText: '今天下载了隙光APP，好开心',
          emotion: '开心',
          tags: const ['隙光初见'],
          createdAt: DateTime(2026, 7, 13, 8, 30),
        ),
        Fragment(
          id: 2,
          contentText: '你好',
          emotion: '平静',
          createdAt: DateTime(2026, 7, 12, 21, 10),
        ),
      ];
}
