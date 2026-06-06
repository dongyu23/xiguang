import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xiguang/app/app.dart';
import 'package:xiguang/app/providers.dart';

import 'test_auth_repository.dart';

void main() {
  testWidgets('CLAUDE bottom navigation keeps weave contextual only',
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
    expect(find.text('本地试用'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('go-register')));
    await tester.tap(find.text('创建账号'));
    await _pumpUntilFound(
        tester, find.byKey(const ValueKey('register-username')));
    await tester.enterText(
        find.byKey(const ValueKey('register-username')), 'claude_user');
    await tester.enterText(
        find.byKey(const ValueKey('register-nickname')), '约束账号');
    await tester.enterText(
        find.byKey(const ValueKey('register-password')), 'xiguang-pass');
    await tester.tap(find.widgetWithText(FilledButton, '创建并进入'));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('nav-timeline')));

    for (final label in ['隙', '线', '屿', '我的']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('织'), findsNothing);
    expect(find.widgetWithText(FloatingActionButton, '捕光'), findsNothing);

    for (final navKey in [
      'nav-timeline',
      'nav-universe',
      'nav-mine',
    ]) {
      await tester.tap(find.byKey(ValueKey(navKey)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('织'), findsNothing);
      expect(find.widgetWithText(FloatingActionButton, '捕光'), findsNothing);
    }

    expect(find.widgetWithText(FloatingActionButton, '捕光'), findsNothing);
  });

  test('CLAUDE router and Flutter stack constraints are pinned', () {
    final router = File('lib/app/router.dart').readAsStringSync();
    expect(router, contains('StatefulShellRoute.indexedStack'));
    expect(router, contains("path: '/login'"));
    expect(router, contains("path: '/register'"));
    expect(router, contains("path: '/capture'"));
    expect(router, contains("path: '/fragments/:id'"));
    expect(router, contains("path: '/fragments/:id/edit'"));
    expect(router, contains("path: '/timeline'"));
    expect(router, contains("path: '/universe'"));
    expect(router, contains("path: '/islands/:id'"));
    expect(router, contains("path: '/mine'"));
    expect(router, contains("path: '/settings'"));
    expect(router, contains("path: '/space'"));
    expect(router, contains("path: '/whitenoise'"));
    expect(router, contains("path: '/glow-organize'"));
    expect(router, isNot(contains("path: '/weave'")));
  });

  test('CLAUDE Flutter dependency choices remain present', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final dependency in [
      'flutter_riverpod:',
      'go_router:',
      'dio:',
      'drift:',
      'sqlite3_flutter_libs:',
      'freezed_annotation:',
      'json_annotation:',
      'image_picker:',
      'flutter_image_compress:',
      'record:',
      'just_audio:',
      'audio_session:',
      'flutter_secure_storage:',
      'permission_handler:',
      'sentry_flutter:',
    ]) {
      expect(pubspec, contains(dependency));
    }
  });

  test('CLAUDE Flutter feature folders use domain-oriented structure', () {
    for (final feature in [
      'auth',
      'fragment',
      'island',
      'relation',
      'space',
      'starmap',
      'stats',
      'sync',
      'timeline',
      'whitenoise',
      'ai',
    ]) {
      expect(Directory('lib/features/$feature').existsSync(), isTrue,
          reason: '$feature feature folder should exist');
      expect(Directory('lib/features/$feature/domain').existsSync(), isTrue,
          reason: '$feature domain layer should exist');
    }
  });

  test('CLAUDE Flutter file manifest has real architecture files', () {
    const files = [
      'lib/design/tokens/colors.dart',
      'lib/design/tokens/spacing.dart',
      'lib/design/tokens/radius.dart',
      'lib/design/tokens/typography.dart',
      'lib/design/tokens/shadows.dart',
      'lib/design/tokens/blur.dart',
      'lib/design/tokens/motion.dart',
      'lib/design/themes/theme.dart',
      'lib/design/themes/extensions/blur_theme.dart',
      'lib/design/themes/extensions/glow_theme.dart',
      'lib/design/themes/extensions/space_theme.dart',
      'lib/ui/primitives/blur_box.dart',
      'lib/ui/primitives/glow_button.dart',
      'lib/ui/primitives/ripple_tap.dart',
      'lib/ui/primitives/breathing_widget.dart',
      'lib/ui/primitives/morandi_card.dart',
      'lib/ui/composites/emotion_picker.dart',
      'lib/ui/composites/light_card.dart',
      'lib/ui/composites/time_river_item.dart',
      'lib/ui/composites/tag_chip.dart',
      'lib/ui/composites/image_grid.dart',
      'lib/ui/spaces/space_canvas.dart',
      'lib/ui/spaces/starry_space.dart',
      'lib/ui/spaces/ocean_space.dart',
      'lib/ui/spaces/island_space.dart',
      'lib/features/auth/domain/user.dart',
      'lib/features/auth/domain/token.dart',
      'lib/features/auth/domain/auth_repository.dart',
      'lib/features/auth/data/auth_api.dart',
      'lib/features/auth/data/token_storage.dart',
      'lib/features/auth/data/auth_repository_impl.dart',
      'lib/features/auth/presentation/providers/auth_provider.dart',
      'lib/features/auth/presentation/pages/login_page.dart',
      'lib/features/auth/presentation/pages/register_page.dart',
      'lib/features/fragment/domain/fragment.dart',
      'lib/features/fragment/domain/fragment_status.dart',
      'lib/features/fragment/domain/emotion.dart',
      'lib/features/fragment/domain/create_params.dart',
      'lib/features/fragment/domain/fragment_repository.dart',
      'lib/features/fragment/data/local/fragment_dao.dart',
      'lib/features/fragment/data/local/fragment_drift.dart',
      'lib/features/fragment/data/local/fragment_local_ds.dart',
      'lib/features/fragment/data/remote/fragment_api.dart',
      'lib/features/fragment/data/remote/fragment_remote_ds.dart',
      'lib/features/fragment/data/media_uploader.dart',
      'lib/features/fragment/data/fragment_repository_impl.dart',
      'lib/features/fragment/sync/oplog_generator.dart',
      'lib/features/fragment/sync/conflict_resolver.dart',
      'lib/features/fragment/presentation/providers/fragment_list_provider.dart',
      'lib/features/fragment/presentation/providers/fragment_detail_provider.dart',
      'lib/features/fragment/presentation/providers/capture_provider.dart',
      'lib/features/fragment/presentation/pages/capture_page.dart',
      'lib/features/fragment/presentation/pages/fragment_detail_page.dart',
      'lib/features/fragment/presentation/pages/fragment_edit_page.dart',
      'lib/features/fragment/presentation/widgets/capture_input.dart',
      'lib/features/fragment/presentation/widgets/media_picker.dart',
      'lib/features/fragment/presentation/widgets/emotion_picker_sheet.dart',
      'lib/features/fragment/presentation/widgets/tag_input.dart',
      'lib/features/timeline/domain/timeline_query.dart',
      'lib/features/timeline/domain/date_group.dart',
      'lib/features/timeline/domain/timeline_repository.dart',
      'lib/features/timeline/data/timeline_api.dart',
      'lib/features/timeline/data/timeline_local_dao.dart',
      'lib/features/timeline/data/timeline_repository_impl.dart',
      'lib/features/timeline/presentation/providers/timeline_provider.dart',
      'lib/features/timeline/presentation/providers/filter_provider.dart',
      'lib/features/timeline/presentation/pages/time_river_page.dart',
      'lib/features/timeline/presentation/widgets/date_group_widget.dart',
      'lib/features/timeline/presentation/widgets/timeline_light_card.dart',
      'lib/features/timeline/presentation/widgets/filter_bar.dart',
      'lib/features/stats/domain/emotion_density.dart',
      'lib/features/stats/domain/freq_words.dart',
      'lib/features/stats/domain/stats_repository.dart',
      'lib/features/stats/data/stats_api.dart',
      'lib/features/stats/data/stats_repository_impl.dart',
      'lib/features/stats/presentation/providers/stats_provider.dart',
      'lib/features/stats/presentation/widgets/emotion_density_chart.dart',
      'lib/features/stats/presentation/widgets/freq_words_cloud.dart',
      'lib/features/relation/domain/relation.dart',
      'lib/features/relation/domain/relation_type.dart',
      'lib/features/relation/domain/relation_repository.dart',
      'lib/features/relation/data/relation_api.dart',
      'lib/features/relation/data/relation_local_dao.dart',
      'lib/features/relation/data/relation_repository_impl.dart',
      'lib/features/relation/presentation/providers/relation_provider.dart',
      'lib/features/relation/presentation/pages/weave_page.dart',
      'lib/features/relation/presentation/pages/relation_select_page.dart',
      'lib/features/relation/presentation/widgets/relation_type_picker.dart',
      'lib/features/relation/presentation/widgets/relation_note_input.dart',
      'lib/features/starmap/domain/star_node.dart',
      'lib/features/starmap/domain/star_edge.dart',
      'lib/features/starmap/domain/star_graph.dart',
      'lib/features/starmap/domain/starmap_repository.dart',
      'lib/features/starmap/data/starmap_api.dart',
      'lib/features/starmap/data/starmap_repository_impl.dart',
      'lib/features/starmap/presentation/providers/starmap_provider.dart',
      'lib/features/starmap/presentation/widgets/starmap_canvas.dart',
      'lib/features/starmap/presentation/widgets/star_node_widget.dart',
      'lib/features/starmap/presentation/widgets/edge_painter.dart',
      'lib/features/island/domain/island.dart',
      'lib/features/island/domain/island_status.dart',
      'lib/features/island/domain/island_repository.dart',
      'lib/features/island/data/island_api.dart',
      'lib/features/island/data/island_repository_impl.dart',
      'lib/features/island/presentation/providers/island_provider.dart',
      'lib/features/island/presentation/pages/universe_page.dart',
      'lib/features/island/presentation/pages/island_detail_page.dart',
      'lib/features/island/presentation/widgets/island_card.dart',
      'lib/features/island/presentation/widgets/island_canvas.dart',
      'lib/features/space/domain/space_theme.dart',
      'lib/features/space/domain/space_repository.dart',
      'lib/features/space/data/space_api.dart',
      'lib/features/space/data/space_repository_impl.dart',
      'lib/features/space/presentation/providers/space_provider.dart',
      'lib/features/space/presentation/pages/space_page.dart',
      'lib/features/whitenoise/domain/noise_audio.dart',
      'lib/features/whitenoise/domain/whitenoise_repository.dart',
      'lib/features/whitenoise/data/whitenoise_api.dart',
      'lib/features/whitenoise/data/whitenoise_assets.dart',
      'lib/features/whitenoise/data/whitenoise_repository_impl.dart',
      'lib/features/whitenoise/presentation/providers/whitenoise_provider.dart',
      'lib/features/whitenoise/presentation/pages/whitenoise_page.dart',
      'lib/features/whitenoise/presentation/widgets/noise_player.dart',
      'lib/features/whitenoise/presentation/widgets/noise_selector.dart',
      'lib/features/sync/domain/oplog.dart',
      'lib/features/sync/domain/sync_status.dart',
      'lib/features/sync/engine/sync_engine.dart',
      'lib/features/sync/engine/conflict_resolver.dart',
      'lib/features/ai/domain/ai_request.dart',
      'lib/features/ai/domain/ai_response.dart',
      'lib/features/ai/data/ai_api.dart',
      'lib/features/ai/data/ai_repository_impl.dart',
      'lib/features/ai/presentation/providers/ai_provider.dart',
      'lib/features/ai/presentation/pages/glow_organize_page.dart',
      'lib/features/ai/presentation/widgets/glow_suggestion_card.dart',
    ];

    for (final path in files) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path should exist');
      expect(file.readAsStringSync().trim(), isNotEmpty,
          reason: '$path should not be an empty placeholder');
    }
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
