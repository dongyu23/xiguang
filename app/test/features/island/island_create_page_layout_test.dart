import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/features/fragment/domain/fragment.dart';
import 'package:xiguang/features/island/application/island_providers.dart';
import 'package:xiguang/features/island/domain/island_model.dart';
import 'package:xiguang/features/island/domain/island_repository.dart';
import 'package:xiguang/features/island/presentation/pages/island_create_page.dart';
import 'package:xiguang/ui/composites/xiguang_card.dart';

void main() {
  testWidgets('new island page is a visual naming flow without a form card',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: xiguangTheme(nightMode: true),
          home: const Scaffold(body: IslandCreatePage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byKey(const ValueKey('new-island-preview')), findsOneWidget);
    expect(find.text('让一座岛浮起来'), findsOneWidget);
    expect(find.text('一座还没有名字的小岛'), findsOneWidget);
    expect(find.byType(XiguangCard), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('创建这座小岛'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '午夜咖啡馆');
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('new-island-preview')),
        matching: find.text('午夜咖啡馆'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating an island returns to the universe root',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/islands/create',
      routes: [
        GoRoute(
          path: '/islands/create',
          builder: (_, __) => const Scaffold(body: IslandCreatePage()),
        ),
        GoRoute(
          path: '/universe',
          builder: (_, __) => const Scaffold(body: Text('屿主页')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          islandRepositoryProvider.overrideWithValue(_FakeIslandRepository()),
        ],
        child: MaterialApp.router(
          theme: xiguangTheme(nightMode: true),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '新岛');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-island-submit')));
    await tester.pumpAndSettle();

    expect(find.text('屿主页'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/universe');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['reveal'],
      'island-1',
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeIslandRepository implements IslandRepositoryPort {
  @override
  Future<IslandModel> createIsland(String name, String description) async {
    return IslandModel(
      islandId: 1,
      name: name,
      status: 'star_point',
      fragmentCount: 0,
      description: description,
      manual: true,
    );
  }

  @override
  Future<void> deleteIsland(int islandId) async {}

  @override
  Future<IslandModel> addFragments(int islandId, List<int> fragmentIds) =>
      throw UnimplementedError();

  @override
  List<IslandModel> computeIslandsFromFragments(List<Fragment> fragments) =>
      const [];

  @override
  Future<IslandModel?> getIsland(String name) async => null;

  @override
  Future<List<IslandModel>> listIslands(
          {List<Fragment>? cachedFragments}) async =>
      const [];

  @override
  Future<List<Fragment>> listIslandFragments(String name,
          {int? islandId}) async =>
      const [];

  @override
  Future<IslandModel> removeFragments(int islandId, List<int> fragmentIds) =>
      throw UnimplementedError();

  @override
  Future<List<IslandModel>?> tryListRemoteIslands() async => const [];
}
