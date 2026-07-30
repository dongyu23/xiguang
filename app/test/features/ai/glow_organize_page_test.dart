import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/app/app_state.dart';
import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/features/ai/domain/ai_request.dart';
import 'package:xiguang/features/ai/presentation/pages/glow_organize_page.dart';

void main() {
  testWidgets('AI off keeps the workbench non-blocking and hides start action',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [aiEnabledProvider.overrideWith((ref) => false)],
        child: MaterialApp(
          theme: xiguangTheme(),
          home: const GlowOrganizePage(
            initialScope: AIScope.fragments([1, 2]),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('星图管理员已关闭。捕光、回看和织线仍可正常使用。'), findsOneWidget);
    expect(find.text('开始整理'), findsNothing);
    expect(find.textContaining('选中的 2 束光'), findsWidgets);
    expect(find.byType(TextField), findsNothing);
  });
}
