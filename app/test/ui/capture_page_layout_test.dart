import 'package:file_picker/file_picker.dart';
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
import 'package:xiguang/ui/composites/emotion_more_sheet.dart';

void main() {
  testWidgets('capture actions remain visible on a common mobile viewport',
      (tester) async {
    await _pumpCapturePage(tester, const Size(360, 800));

    expect(tester.takeException(), isNull);
    expect(find.text('图片'), findsOneWidget);
    expect(find.text('声音'), findsOneWidget);
    expect(find.text('捕光'), findsOneWidget);
    expect(tester.getBottomRight(find.text('捕光')).dy, lessThan(700));
    expect(
      tester.getTopLeft(find.text('心绪收录')).dy,
      greaterThan(tester.getBottomRight(find.text('捕光')).dy),
    );
    expect(find.byType(SingleChildScrollView), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/capture_page_night.png'),
    );
  });

  testWidgets('430px phone layout keeps banner compact and editor flexible',
      (tester) async {
    await _pumpCapturePage(tester, const Size(430, 932));

    expect(
      tester
          .getSize(find.byKey(const ValueKey('breathing-light-banner')))
          .height,
      96,
    );
    final tallEditorHeight =
        tester.getSize(find.byKey(const ValueKey('capture-content'))).height;
    expect(find.byType(SingleChildScrollView), findsNothing);

    tester.view.physicalSize = const Size(430, 812);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final shortEditorHeight =
        tester.getSize(find.byKey(const ValueKey('capture-content'))).height;

    expect(shortEditorHeight, lessThan(tallEditorHeight));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('breathing-light-banner')))
          .height,
      96,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture action stays available while the keyboard is open',
      (tester) async {
    await _pumpCapturePage(tester, const Size(360, 800));
    addTearDown(tester.view.resetViewInsets);

    await tester.tap(find.byKey(const ValueKey('capture-content')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final captureAction = find.text('捕光');
    expect(tester.takeException(), isNull);
    expect(captureAction, findsOneWidget);
    expect(captureAction.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(captureAction).dy, greaterThan(300));
    expect(tester.getBottomRight(captureAction).dy, lessThan(500));
    expect(
      tester.getTopLeft(find.text('心绪收录')).dy,
      greaterThan(tester.getBottomRight(captureAction).dy),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/capture_page_keyboard.png'),
    );
  });

  testWidgets('adding an image keeps the emotion rail fixed', (tester) async {
    FilePicker.platform = _FakeImageFilePicker();
    await _pumpCapturePage(tester, const Size(360, 800));

    final emotion = find.text('平静');
    final emotionTopBefore = tester.getTopLeft(emotion).dy;

    await tester.tap(find.text('图片'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('image-rail-1')), findsOneWidget);
    expect(find.byTooltip('用系统预览打开'), findsOneWidget);
    expect(tester.getTopLeft(emotion).dy, emotionTopBefore);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/capture_page_with_image.png'),
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

  testWidgets('emotion limit snackbar overlays without shifting the sheet',
      (tester) async {
    await _pumpCapturePage(tester, const Size(390, 844));

    await tester.tap(find.text('更多'));
    await tester.pump(const Duration(milliseconds: 500));

    final sheet = find.byType(EmotionMoreSheet);
    final firstEmotion = find.descendant(
      of: sheet,
      matching: find.text('平静'),
    );
    await tester.ensureVisible(firstEmotion);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(firstEmotion);
    await tester.pump(const Duration(milliseconds: 500));
    final emotionTopBefore = tester.getTopLeft(firstEmotion).dy;
    final sheetSizeBefore = tester.getSize(sheet);
    await tester.tap(firstEmotion);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('最多展示 7 个心绪，请先取消其他。'), findsOneWidget);
    expect(tester.getTopLeft(firstEmotion).dy, emotionTopBefore);
    expect(tester.getSize(sheet), sheetSizeBefore);
  });
}

class _FakeImageFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return FilePickerResult([
      PlatformFile(
        name: 'nav_gap.png',
        path: 'assets/nav_icons/nav_gap.png',
        size: 1,
      ),
    ]);
  }
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
