import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiguang/app/app.dart';
import 'package:xiguang/app/providers.dart';

import 'test_auth_repository.dart';

void main() {
  testWidgets('mobile preview tabs do not overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authRepository = FakeAuthRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
      child: const XiguangApp(),
    ));
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('go-register')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.enterText(
        find.byKey(const ValueKey('register-username')), 'golden_user');
    await tester.enterText(
        find.byKey(const ValueKey('register-nickname')), '预览账号');
    await tester.enterText(
        find.byKey(const ValueKey('register-password')), 'xiguang-pass');
    await tester.tap(find.widgetWithText(FilledButton, '创建并进入'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

    for (final label in ['线', '屿', '我的']) {
      await tester.tap(find.text(label));
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    }
  });
}
