import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/features/emotion/application/emotions_controller.dart';
import 'package:xiguang/features/emotion/domain/audio_track.dart';
import 'package:xiguang/features/emotion/domain/emotion_repository.dart';
import 'package:xiguang/features/emotion/domain/user_emotion.dart';
import 'package:xiguang/features/fragment/application/fragment_list_controller.dart';
import 'package:xiguang/features/fragment/domain/fragment.dart';
import 'package:xiguang/features/fragment/presentation/pages/fragment_detail_page.dart';
import 'package:xiguang/features/relation/presentation/providers/relation_providers.dart';

void main() {
  testWidgets('detail page follows the light emotion media relation flow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fragment = Fragment(
      id: 42,
      contentText: '雨停以后，窗外忽然安静了。',
      emotion: '雨后空空',
      tags: const ['雨夜'],
      createdAt: DateTime(2026, 7, 10, 18, 44),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fragmentsProvider.overrideWith(
            () => _FakeFragmentsNotifier(fragment),
          ),
          emotionRepositoryProvider.overrideWithValue(
            const _FakeEmotionRepository(),
          ),
          fragmentRelationsProvider.overrideWith(
            (ref, fragmentId) async => const [],
          ),
        ],
        child: MaterialApp(
          theme: xiguangTheme(),
          home: const Scaffold(
            body: FragmentDetailPage(id: '42'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('雨后空空'), findsOneWidget);
    expect(find.text('画面与声音'), findsOneWidget);
    expect(find.text('和旧光发生联系'), findsOneWidget);
    expect(find.text('选择旧光并织线'), findsOneWidget);
    expect(find.text('附着的画面'), findsNothing);
  });
}

class _FakeFragmentsNotifier extends FragmentsNotifier {
  _FakeFragmentsNotifier(this.fragment);

  final Fragment fragment;

  @override
  Future<List<Fragment>> build() async => [fragment];
}

class _FakeEmotionRepository implements EmotionRepositoryPort {
  const _FakeEmotionRepository();

  static const emotions = <UserEmotion>[
    UserEmotion(
      id: 1,
      name: '平静',
      color: Color(0xFF72A58F),
      description: '内心安静，没有波澜',
      isDefault: true,
      sortOrder: 0,
    ),
    UserEmotion(
      id: 2,
      name: '开心',
      color: Color(0xFFF0C78E),
      description: '有一点点想笑',
      isDefault: true,
      sortOrder: 1,
    ),
    UserEmotion(
      id: 3,
      name: '疲惫',
      color: Color(0xFF9EBBCC),
      description: '身体或心里有点累',
      isDefault: true,
      sortOrder: 2,
    ),
    UserEmotion(
      id: 4,
      name: '焦虑',
      color: Color(0xFFE9A18B),
      description: '心悬着，不太安稳',
      isDefault: true,
      sortOrder: 3,
    ),
    UserEmotion(
      id: 5,
      name: '失落',
      color: Color(0xFFC4C4C4),
      description: '空空的，说不上来',
      isDefault: true,
      sortOrder: 4,
    ),
    UserEmotion(
      id: 6,
      name: '被击中',
      color: Color(0xFFE8B88A),
      description: '被什么触动了',
      isDefault: true,
      sortOrder: 5,
    ),
    UserEmotion(
      id: 7,
      name: '混乱',
      color: Color(0xFFD9CCE8),
      description: '一团乱，理不清楚',
      isDefault: true,
      sortOrder: 6,
    ),
    UserEmotion(
      id: 8,
      name: '雨后空空',
      color: Color(0xFF91AEB8),
      description: '雨停后忽然空下来的感觉',
      isDefault: false,
      sortOrder: 7,
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
      9;

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
