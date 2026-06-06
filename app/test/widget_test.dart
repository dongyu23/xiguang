import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xiguang/app/app.dart';
import 'package:xiguang/app/providers.dart';

import 'test_auth_repository.dart';

void main() {
  testWidgets('Xiguang MVP renders CLAUDE navigation and can capture a light',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
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
    expect(find.text('创建账号'), findsOneWidget);
    expect(find.text('本地试用'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('go-register')));
    await tester.tap(find.text('创建账号'));
    await _pumpUntilFound(
        tester, find.byKey(const ValueKey('register-username')));
    await tester.enterText(
        find.byKey(const ValueKey('register-username')), 'first_user');
    await tester.enterText(
        find.byKey(const ValueKey('register-nickname')), '第一个账号');
    await tester.enterText(
        find.byKey(const ValueKey('register-password')), 'xiguang-pass');
    await tester.tap(find.widgetWithText(FilledButton, '创建并进入'));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('nav-timeline')));

    expect(find.text('隙'), findsWidgets);
    expect(find.text('线'), findsOneWidget);
    expect(find.text('屿'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('捕光'), findsWidgets);

    await tester.enterText(
        find.byKey(const ValueKey('capture-content')), '测试里落下的一束光');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('清空草稿'), findsOneWidget);
    await tester.ensureVisible(find.text('图片'));
    expect(find.text('图片'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '音频'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('停止'), findsOneWidget);
    expect(find.textContaining('正在贴近这一刻的声音'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '停止'));
    await tester.tap(find.widgetWithText(OutlinedButton, '停止'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('声音已贴近'), findsOneWidget);
    expect(find.textContaining('贴近这一刻的声音'), findsOneWidget);
    await tester.ensureVisible(find.text('疲惫'));
    await tester.tap(find.text('疲惫'));
    await tester.ensureVisible(find.widgetWithText(FilledButton, '捕光').first);
    await tester.tap(find.widgetWithText(FilledButton, '捕光').first);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('刚刚留下的光'), findsNothing);
    expect(find.text('去织线'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nav-timeline')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('TIME RIVER'), findsNothing);
    expect(find.byKey(const ValueKey('timeline-compact-title')), findsNothing);
    expect(find.textContaining('测试里落下'), findsWidgets);

    final timelineCard = find.byKey(const ValueKey('timeline-card-100'));
    expect(timelineCard, findsOneWidget);
    await tester.ensureVisible(timelineCard);
    await tester.tap(timelineCard);
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    expect(find.text('织线'), findsOneWidget);
    expect(find.text('当前这束光'), findsOneWidget);
    expect(find.text('选择另一束光'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

    await tester.tap(find.byKey(const ValueKey('nav-universe')));
    await _pumpUntilFound(tester, find.text('小宇宙'));
    expect(find.text('小宇宙'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-mine')));
    await _pumpUntilFound(tester, find.text('数据边界'));
    expect(find.text('数据边界'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-edit-toggle')));
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(
        find.byKey(const ValueKey('profile-nickname')), '测试试光者');
    await tester.tap(find.byKey(const ValueKey('profile-ai-enabled')));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.byKey(const ValueKey('profile-save')));
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('测试试光者'), findsWidgets);
    expect(find.text('已同步到后端。'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('logout-button')));
    await tester.tap(find.byKey(const ValueKey('logout-button')));
    await _pumpUntilFound(tester, find.text('登录并捕光'));
    expect(find.text('登录并捕光'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('login-username')), 'second_user');
    await tester.enterText(
        find.byKey(const ValueKey('login-password')), 'xiguang-pass');
    await tester.tap(find.widgetWithText(FilledButton, '登录并捕光'));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('nav-mine')));
    await tester.tap(find.byKey(const ValueKey('nav-mine')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('第二个账号'), findsWidgets);
  });

  testWidgets('capture draft is restored and cleared after saving',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'capture_draft_text': '还没写完的一束光',
      'capture_draft_emotion': '自定义',
      'capture_draft_custom_emotion': '松了一口气',
    });
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
    await tester.tap(find.byKey(const ValueKey('go-register')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.enterText(
        find.byKey(const ValueKey('register-username')), 'draft_user');
    await tester.enterText(
        find.byKey(const ValueKey('register-nickname')), '草稿账号');
    await tester.enterText(
        find.byKey(const ValueKey('register-password')), 'xiguang-pass');
    await tester.tap(find.widgetWithText(FilledButton, '创建并进入'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));

    final draftStatusCount = tester.widgetList(find.text('已找回上次没写完的光')).length +
        tester.widgetList(find.text('已轻轻存下草稿')).length;
    expect(draftStatusCount, 1);
    expect(find.text('还没写完的一束光'), findsOneWidget);
    expect(find.text('松了一口气'), findsOneWidget);
    expect(find.text('清空草稿'), findsOneWidget);

    await tester.tap(find.text('清空草稿'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('还没写完的一束光'), findsNothing);
    expect(find.text('可以只留一句'), findsNothing);

    final clearedPrefs = await SharedPreferences.getInstance();
    expect(clearedPrefs.getString('capture_draft_text'), isNull);

    await tester.enterText(
        find.byKey(const ValueKey('capture-content')), '清空后重新落下的一束光');

    await tester.ensureVisible(find.widgetWithText(FilledButton, '捕光').first);
    await tester.tap(find.widgetWithText(FilledButton, '捕光').first);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('刚刚留下的光'), findsNothing);
    expect(find.text('去织线'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('capture_draft_text'), isNull);
  });
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}
