import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiguang/app/app.dart';
import 'package:xiguang/app/providers.dart';

import 'test_auth_repository.dart';

void main() {
  testWidgets('Xiguang MVP renders CLAUDE navigation and can capture a light',
      (tester) async {
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

    expect(find.text('登录并捕光'), findsOneWidget);
    expect(find.text('注册新账号'), findsOneWidget);
    expect(find.text('本地试用'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('go-register')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.enterText(
        find.byKey(const ValueKey('register-username')), 'first_user');
    await tester.enterText(
        find.byKey(const ValueKey('register-nickname')), '第一个账号');
    await tester.enterText(
        find.byKey(const ValueKey('register-password')), 'xiguang-pass');
    await tester.tap(find.widgetWithText(FilledButton, '创建并进入'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

    expect(find.text('隙'), findsWidgets);
    expect(find.text('线'), findsOneWidget);
    expect(find.text('屿'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('捕光'), findsWidgets);

    await tester.enterText(find.byType(EditableText).first, '测试里落下的一束光');
    await tester.ensureVisible(find.text('疲惫'));
    await tester.tap(find.text('疲惫'));
    await tester.ensureVisible(find.widgetWithText(FilledButton, '捕光').first);
    await tester.tap(find.widgetWithText(FilledButton, '捕光').first);
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('测试里落下'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('nav-timeline')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('TIME RIVER'), findsOneWidget);
    expect(find.textContaining('测试里落下'), findsWidgets);

    final timelineCard = find.byKey(const ValueKey('timeline-card-100'));
    expect(timelineCard, findsOneWidget);
    await tester.ensureVisible(timelineCard);
    await tester.tap(timelineCard);
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    expect(find.text('光片详情'), findsOneWidget);
    expect(find.text('织线'), findsOneWidget);
    expect(find.text('和另一束光织在一起'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

    await tester.tap(find.byKey(const ValueKey('nav-universe')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('近期星图'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-mine')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('数据边界'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-edit-toggle')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.enterText(
        find.byKey(const ValueKey('profile-nickname')), '测试试光者');
    await tester.tap(find.byKey(const ValueKey('profile-ai-enabled')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.ensureVisible(find.byKey(const ValueKey('profile-save')));
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('测试试光者'), findsWidgets);
    expect(find.text('已同步到后端。'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('logout-button')));
    await tester.tap(find.byKey(const ValueKey('logout-button')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('登录并捕光'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('login-username')), 'second_user');
    await tester.enterText(
        find.byKey(const ValueKey('login-password')), 'xiguang-pass');
    await tester.tap(find.widgetWithText(FilledButton, '登录并捕光'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.tap(find.byKey(const ValueKey('nav-mine')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('第二个账号'), findsWidgets);
  });
}
