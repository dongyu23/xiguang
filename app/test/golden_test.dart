import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/design/tokens/spacing.dart';
import 'package:xiguang/ui/composites/xiguang_bottom_sheet.dart';
import 'package:xiguang/ui/composites/xiguang_button.dart';
import 'package:xiguang/ui/composites/xiguang_card.dart';
import 'package:xiguang/ui/composites/xiguang_chip.dart';
import 'package:xiguang/ui/composites/xiguang_empty_state.dart';
import 'package:xiguang/ui/composites/xiguang_input.dart';
import 'package:xiguang/ui/composites/xiguang_page.dart';
import 'package:xiguang/ui/composites/xiguang_section.dart';

void main() {
  testWidgets('mobile component frame does not overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: xiguangTheme(),
        home: const Scaffold(
          body: XiguangPage(
            child: XiguangEmptyState(
              title: '这里还没有光',
              description: '当你愿意时，把这一刻轻轻放进来。',
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('这里还没有光'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/xiguang_empty_state.png'),
    );
  });

  for (final nightMode in [false, true]) {
    testWidgets('core component catalog ${nightMode ? 'night' : 'day'} golden',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController(text: '把这一刻轻轻放在这里');
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        theme: xiguangTheme(nightMode: nightMode),
        home: Scaffold(
          body: XiguangPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                XiguangSection(
                  title: '今日微光',
                  description: '固定的标题、说明和操作节奏',
                  action: TextButton(onPressed: () {}, child: const Text('回看')),
                  child: const XiguangCard(
                    child: Text('风从窗边经过，房间安静了一会儿。'),
                  ),
                ),
                const SizedBox(height: AppSpacing.s18),
                XiguangInput(
                  controller: controller,
                  label: '这一刻',
                  hint: '写一点什么…',
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.s14),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    XiguangChip(
                      label: '平静',
                      selected: true,
                      onSelected: (_) {},
                    ),
                    XiguangChip(
                      label: '说不清',
                      selected: false,
                      onSelected: (_) {},
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s14),
                XiguangButton(label: '捕光', onPressed: () {}),
                const SizedBox(height: AppSpacing.sm),
                XiguangButton(
                  label: '暂时不用',
                  variant: XiguangButtonVariant.secondary,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                XiguangButton(
                  label: '删除这束光',
                  variant: XiguangButtonVariant.destructive,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.s18),
                const XiguangEmptyState(
                  title: '这里还没有光',
                  description: '当你愿意时，再把这一刻放进来。',
                ),
                const SizedBox(height: AppSpacing.s18),
                const XiguangBottomSheet(
                  child: Text('底部操作会保持相同的表面、边框与留白。'),
                ),
              ],
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/xiguang_components_${nightMode ? 'night' : 'day'}.png',
        ),
      );
    });
  }
}
