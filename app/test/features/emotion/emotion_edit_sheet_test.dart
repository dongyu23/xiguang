import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/features/emotion/application/emotions_controller.dart';
import 'package:xiguang/features/emotion/domain/audio_track.dart';
import 'package:xiguang/features/emotion/domain/emotion_repository.dart';
import 'package:xiguang/features/emotion/domain/user_emotion.dart';
import 'package:xiguang/features/emotion/presentation/widgets/emotion_edit_sheet.dart';

void main() {
  const emotion = UserEmotion(
    id: 1,
    name: '焦虑',
    color: Color(0xFFE9A18B),
    description: '心悬着，不太安稳',
    isDefault: true,
    sortOrder: 0,
    soundKey: 'soothing',
  );

  testWidgets('keeps close and save actions above the keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await _openSheet(tester, emotion);
    await tester.tap(find.byType(TextField).last);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final saveButton = find.widgetWithText(FilledButton, '保存');
    expect(saveButton, findsOneWidget);
    expect(tester.getBottomRight(saveButton).dy, lessThanOrEqualTo(524));
    expect(find.byTooltip('关闭'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('编辑心情'), findsNothing);
  });

  testWidgets('keyboard done action ends description editing', (tester) async {
    await _openSheet(tester, emotion);
    await tester.tap(find.byType(TextField).last);
    await tester.pump();

    final description =
        tester.widgetList<EditableText>(find.byType(EditableText)).last;
    expect(description.focusNode.hasFocus, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(description.focusNode.hasFocus, isFalse);
  });
}

Future<void> _openSheet(WidgetTester tester, UserEmotion emotion) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        emotionRepositoryProvider.overrideWithValue(
          _FakeEmotionRepository(emotion),
        ),
      ],
      child: MaterialApp(
        theme: xiguangTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => EmotionEditSheet(existing: emotion),
                ),
                child: const Text('编辑'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('编辑'));
  await tester.pumpAndSettle();
}

class _FakeEmotionRepository implements EmotionRepositoryPort {
  _FakeEmotionRepository(this.emotion);

  final UserEmotion emotion;

  @override
  Future<List<UserEmotion>> getAll() async => [emotion];

  @override
  Future<int> addCustom(
    String name, {
    String? description,
    String? soundKey,
  }) async =>
      2;

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> update(UserEmotion emotion) async {}

  @override
  Future<void> setUserDefault(int id) async {}

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
