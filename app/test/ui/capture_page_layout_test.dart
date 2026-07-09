import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiguang/app/providers.dart';
import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/design/tokens/colors.dart';
import 'package:xiguang/features/emotion/domain/audio_track.dart';
import 'package:xiguang/features/emotion/domain/emotion_repository.dart';
import 'package:xiguang/features/emotion/domain/user_emotion.dart';
import 'package:xiguang/features/fragment/presentation/pages/capture_page.dart';

void main() {
  testWidgets('capture actions remain visible on a common mobile viewport',
      (tester) async {
    await _pumpCapturePage(tester, const Size(360, 800));

    expect(tester.takeException(), isNull);
    expect(find.text('图片'), findsOneWidget);
    expect(find.text('声音'), findsOneWidget);
    expect(find.text('捕光'), findsOneWidget);
    expect(tester.getBottomRight(find.text('捕光')).dy, lessThan(700));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/capture_page_night.png'),
    );
  });

  testWidgets(
      'more emotions sheet keeps its add action intact on a short screen',
      (tester) async {
    await _pumpCapturePage(tester, const Size(320, 640));

    await tester.tap(find.text('更多'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('更多心绪'), findsOneWidget);
    expect(find.text('给此刻一个自己的名字'), findsOneWidget);
    expect(find.byTooltip('新增心绪'), findsOneWidget);
    expect(
      tester.getBottomRight(find.byTooltip('新增心绪')).dy,
      lessThanOrEqualTo(640),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/emotion_more_sheet_short.png'),
    );
  });
}

Future<void> _pumpCapturePage(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        emotionRepositoryProvider.overrideWithValue(_FakeEmotionRepository()),
      ],
      child: MaterialApp(
        theme: xiguangTheme(nightMode: true),
        home: const Scaffold(body: CapturePage()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

class _FakeEmotionRepository implements EmotionRepositoryPort {
  static const emotions = <UserEmotion>[
    UserEmotion(
      id: 1,
      name: '平静',
      color: AppColors.emotionCalm,
      description: '内心安静，没有波澜',
      isDefault: true,
      sortOrder: 0,
    ),
    UserEmotion(
      id: 2,
      name: '开心',
      color: AppColors.emotionHappy,
      description: '有一点点想笑',
      isDefault: true,
      sortOrder: 1,
    ),
    UserEmotion(
      id: 3,
      name: '疲惫',
      color: AppColors.emotionTired,
      description: '身体或心里有点累',
      isDefault: true,
      sortOrder: 2,
    ),
    UserEmotion(
      id: 4,
      name: '焦虑',
      color: AppColors.emotionAnxious,
      description: '心悬着，不太安稳',
      isDefault: true,
      sortOrder: 3,
    ),
    UserEmotion(
      id: 5,
      name: '失落',
      color: AppColors.emotionLost,
      description: '空空的，说不上来',
      isDefault: true,
      sortOrder: 4,
    ),
    UserEmotion(
      id: 6,
      name: '被击中',
      color: AppColors.emotionStruck,
      description: '被什么触动了',
      isDefault: true,
      sortOrder: 5,
    ),
    UserEmotion(
      id: 7,
      name: '混乱',
      color: AppColors.emotionChaos,
      description: '一团乱，理不清楚',
      isDefault: true,
      sortOrder: 6,
    ),
    UserEmotion(
      id: 8,
      name: '说不清',
      color: AppColors.emotionUnclear,
      description: '暂时不需要说清楚',
      isDefault: true,
      sortOrder: 7,
    ),
  ];

  @override
  Future<List<UserEmotion>> getAll() async => emotions;

  @override
  Future<int> addCustom(String name,
          {String? description, String? soundKey}) async =>
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
