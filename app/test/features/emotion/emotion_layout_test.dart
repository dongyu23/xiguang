import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/features/emotion/application/emotions_controller.dart';
import 'package:xiguang/features/emotion/domain/audio_track.dart';
import 'package:xiguang/features/emotion/domain/emotion_repository.dart';
import 'package:xiguang/features/emotion/domain/user_emotion.dart';
import 'package:xiguang/features/emotion/presentation/pages/emotion_manage_page.dart';
import 'package:xiguang/ui/composites/emotion_picker.dart';

void main() {
  testWidgets('manage header keeps title and actions separated on phones',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(const EmotionManagePage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final title = find.text('管理心情');
    final addEmotion = find.text('添加心情');
    final addMusic = find.text('添加音乐');
    expect(title, findsOneWidget);
    expect(addEmotion, findsOneWidget);
    expect(addMusic, findsOneWidget);
    expect(
      tester.getBottomRight(title).dy,
      lessThan(tester.getTopLeft(addEmotion).dy),
    );
    expect(
      tester.getBottomRight(addEmotion).dx,
      lessThan(tester.getTopLeft(addMusic).dx),
    );
  });

  testWidgets('more emotions sheet is pushed on the root navigator',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rootObserver = _PushObserver();
    final branchObserver = _PushObserver();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emotionRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: MaterialApp(
          theme: xiguangTheme(),
          navigatorObservers: [rootObserver],
          home: Scaffold(
            body: Stack(children: [
              Positioned.fill(
                child: Navigator(
                  observers: [branchObserver],
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: Padding(
                        padding: EdgeInsets.all(24),
                        child: EmotionPicker(
                          selected: '平静',
                          onSelected: _ignoreSelection,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  key: ValueKey('fake-bottom-navigation'),
                  height: 80,
                  width: double.infinity,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rootPushesBefore = rootObserver.pushes;
    final branchPushesBefore = branchObserver.pushes;

    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();

    expect(find.text('更多心绪'), findsOneWidget);
    expect(rootObserver.pushes, rootPushesBefore + 1);
    expect(branchObserver.pushes, branchPushesBefore);
  });
}

void _ignoreSelection(String _) {}

Widget _testApp(Widget child) {
  return ProviderScope(
    overrides: [
      emotionRepositoryProvider.overrideWithValue(_FakeRepository()),
    ],
    child: MaterialApp(theme: xiguangTheme(), home: child),
  );
}

class _PushObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

class _FakeRepository implements EmotionRepositoryPort {
  static const emotions = [
    UserEmotion(
      id: 1,
      name: '平静',
      color: Color(0xFF77C8B1),
      description: '内心安静，没有波澜',
      isDefault: true,
      sortOrder: 0,
    ),
    UserEmotion(
      id: 2,
      name: '开心',
      color: Color(0xFFF0BD77),
      description: '有一点点想笑',
      isDefault: true,
      sortOrder: 1,
    ),
  ];

  @override
  Future<List<UserEmotion>> getAll() async => emotions;

  @override
  Future<int> addCustom(
    String name, {
    String? description,
    String? soundKey,
  }) async =>
      3;

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> update(UserEmotion emotion) async {}

  @override
  Future<void> setHidden(int id, bool hidden) async {}

  @override
  Future<List<AudioTrack>> getAllAudioTracks() async => const [];

  @override
  Future<int> addAudioTrack({
    required String key,
    required String name,
    required String filePath,
  }) async =>
      0;

  @override
  Future<void> deleteAudioTrack(int id) async {}
}
