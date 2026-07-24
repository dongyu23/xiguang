import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiguang/design/themes/theme.dart';
import 'package:xiguang/features/fragment/domain/fragment.dart';
import 'package:xiguang/features/island/application/island_layout_controller.dart';
import 'package:xiguang/features/island/application/universe_overview_provider.dart';
import 'package:xiguang/features/island/domain/island_model.dart';
import 'package:xiguang/features/island/domain/island_visual_stage.dart';
import 'package:xiguang/features/island/domain/universe_overview.dart';
import 'package:xiguang/features/island/presentation/pages/universe_page.dart';
import 'package:xiguang/features/island/presentation/widgets/all_seas_overview_canvas.dart';
import 'package:xiguang/features/island/presentation/widgets/island_archipelago_canvas.dart';
import 'package:xiguang/features/island/presentation/widgets/island_sprite_visual.dart';
import 'package:xiguang/features/relation/domain/relation.dart';

void main() {
  testWidgets('visual universe fits a phone viewport and separates modes',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          universeOverviewProvider.overrideWith((ref) async => _overview()),
        ],
        child: MaterialApp(
          theme: xiguangTheme(nightMode: true),
          home: const Scaffold(body: UniversePage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('PRIVATE SKY'), findsOneWidget);
    expect(find.text('屿'), findsOneWidget);
    expect(find.text('标签、情绪和旧光慢慢连成一张只属于你的星图。'), findsOneWidget);
    expect(find.text('小岛'), findsOneWidget);
    expect(find.text('支线'), findsOneWidget);
    expect(find.text('1 座岛 · 1 条支线 · 3 束光'), findsOneWidget);
    expect(find.byTooltip('列表查看'), findsOneWidget);
    expect(find.byKey(const ValueKey('island-canvas')), findsOneWidget);

    final canvasBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('island-canvas')),
    );
    await tester.tapAt(
      canvasBox.localToGlobal(
        Offset(canvasBox.size.width * .5, canvasBox.size.height * .43),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('打开小岛'), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-island-button')), findsOneWidget);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('favorite-island-button')),
      ),
      const Size.square(30),
    );
    expect(
      find.byKey(const ValueKey('island-focus-switcher')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 400));
    final selectedScale = find.byKey(const ValueKey('selected-island-scale'));
    expect(selectedScale, findsOneWidget);
    expect(
        _scaleOf(tester.widget<Transform>(selectedScale)), closeTo(1.18, .01));
    await tester.tap(find.byTooltip('关闭'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(selectedScale, findsOneWidget);
    final shrinkingScale = _scaleOf(tester.widget<Transform>(selectedScale));
    expect(shrinkingScale, greaterThan(1));
    expect(shrinkingScale, lessThan(1.18));
    await tester.pump(const Duration(milliseconds: 300));
    expect(selectedScale, findsNothing);

    await tester.tap(find.text('支线'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('branch-canvas')), findsOneWidget);

    await tester.tap(find.byTooltip('列表查看'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('关于「第一件事」'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'more than seven islands switch sea areas with a horizontal swipe',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final islands = List.generate(
      9,
      (index) => IslandVisualNode(
        island: IslandModel(
          name: '小岛 ${index + 1}',
          status: 'star_point',
          fragmentCount: 0,
          description: '',
        ),
        fragments: const [],
      ),
    );

    await tester.pumpWidget(MaterialApp(
      theme: xiguangTheme(nightMode: true),
      home: Scaffold(
        body: IslandArchipelagoCanvas(
          islands: islands,
          selected: null,
          onSelect: (_) {},
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('archipelago-page-indicator-1')),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const ValueKey('archipelago-pager')),
      const Offset(-320, 0),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(const ValueKey('archipelago-page-indicator-2')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-seas overview keeps the header and returns to its sea',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final islands = List.generate(
      9,
      (index) => IslandVisualNode(
        island: IslandModel(
          islandId: index + 1,
          name: '全景岛 ${index + 1}',
          status: 'star_point',
          fragmentCount: 0,
          description: '',
        ),
        fragments: const [],
      ),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        universeOverviewProvider.overrideWith((ref) async => UniverseOverview(
              islands: islands,
              branches: const [],
              fragments: const [],
              relations: const [],
            )),
      ],
      child: MaterialApp(
        theme: xiguangTheme(nightMode: true),
        home: const Scaffold(body: UniversePage()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byTooltip('俯瞰全海域'), findsOneWidget);
    final localCanvasState = tester.state(
      find.byKey(const ValueKey('island-canvas')),
    );
    final localIslandCenter = tester.getCenter(
      find.byKey(const ValueKey('island-slot-island-1')),
    );
    await tester.tap(find.byTooltip('俯瞰全海域'));
    await tester.pump();
    final initialGlobalCenter = tester.getCenter(
      find.byKey(const ValueKey('global-island-center-island-1')),
    );
    expect((initialGlobalCenter - localIslandCenter).distance, lessThan(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    final settledGlobalCenter = tester.getCenter(
      find.byKey(const ValueKey('global-island-center-island-1')),
    );
    await tester.pump(const Duration(milliseconds: 700));
    final ambientGlobalCenter = tester.getCenter(
      find.byKey(const ValueKey('global-island-center-island-1')),
    );
    expect(
      (ambientGlobalCenter - settledGlobalCenter).distance,
      lessThan(.01),
    );

    expect(find.byType(AllSeasOverviewCanvas), findsOneWidget);
    expect(find.byType(IslandArchipelagoCanvas), findsOneWidget);
    expect(find.text('PRIVATE SKY'), findsOneWidget);
    expect(find.text('屿'), findsOneWidget);
    expect(find.textContaining('片海域'), findsNothing);
    expect(find.byTooltip('返回当前海域'), findsOneWidget);
    expect(find.byIcon(Icons.add_location_alt_outlined), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('global-island-center-island-1')),
    );
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byKey(const ValueKey('open-overview-island')), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('open-overview-island')), findsNothing);

    await tester.tap(find.byTooltip('返回当前海域'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(IslandArchipelagoCanvas), findsOneWidget);
    expect(
      tester.state(find.byKey(const ValueKey('island-canvas'))),
      same(localCanvasState),
    );
    expect(find.byType(AllSeasOverviewCanvas), findsNothing);
    expect(find.byTooltip('俯瞰全海域'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one continuous ocean remains stable with one hundred islands',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final islands = List.generate(
      100,
      (index) => IslandVisualNode(
        island: IslandModel(
          islandId: index + 1,
          name: '全局岛 ${index + 1}',
          status: index % 5 == 0 ? 'formed' : 'star_point',
          fragmentCount: 0,
          description: '',
        ),
        fragments: const [],
      ),
    );

    await tester.pumpWidget(MaterialApp(
      theme: xiguangTheme(nightMode: true),
      home: Scaffold(
        body: AllSeasOverviewCanvas(
          islands: islands,
          currentSeaIndex: 0,
          selectedIsland: null,
          favoriteKeys: const {},
          onIslandSelected: (_, __) {},
          onExitCompleted: (_) {},
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.byType(AllSeasOverviewCanvas), findsOneWidget);
    expect(
        find.byKey(const ValueKey('all-seas-gesture-layer')), findsOneWidget);
    expect(find.textContaining('片海域'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('list view returns to the all-seas scene it was opened from',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(ProviderScope(
      overrides: [
        universeOverviewProvider.overrideWith((ref) async => _overview()),
      ],
      child: MaterialApp(
        theme: xiguangTheme(nightMode: true),
        home: const Scaffold(body: UniversePage()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('俯瞰全海域'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('列表查看'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AllSeasOverviewCanvas), findsNothing);
    expect(find.byTooltip('返回图景'), findsOneWidget);
    await tester.tap(find.byTooltip('返回图景'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AllSeasOverviewCanvas), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('island list reuses sea grouping and real island artwork',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final light = Fragment(
      id: 10,
      publicId: 'list-light',
      contentText: '一束光',
      createdAt: DateTime.utc(2026, 7, 14, 8),
    );
    final islands = [
      IslandVisualNode(
        island: const IslandModel(
          name: '空岛',
          status: 'star_point',
          fragmentCount: 0,
          description: '',
        ),
        fragments: const [],
      ),
      IslandVisualNode(
        island: const IslandModel(
          name: '有光岛',
          status: 'star_point',
          fragmentCount: 1,
          description: '',
        ),
        fragments: [light],
      ),
    ];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: UniversePage()),
        ),
        GoRoute(
          path: '/islands/:id',
          builder: (_, state) => Scaffold(
            body: Text('小岛详情 ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        universeOverviewProvider.overrideWith((ref) async => UniverseOverview(
              islands: islands,
              branches: const [],
              fragments: [light],
              relations: const [],
            )),
      ],
      child: MaterialApp.router(
        theme: xiguangTheme(nightMode: true),
        routerConfig: router,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('列表查看'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('第1片海域'), findsOneWidget);
    expect(find.byType(IslandSpriteVisual), findsNWidgets(2));
    expect(find.text('初生浅滩'), findsOneWidget);
    expect(find.text('开始萌芽'), findsOneWidget);
    expect(find.text('还没有光片'), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);

    await tester.tap(find.text('空岛'));
    await tester.pumpAndSettle();
    expect(find.text('小岛详情 空岛'), findsOneWidget);
    expect(find.text('打开小岛'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mature islands reduce the visual capacity of one sea area',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final islands = List.generate(
      4,
      (index) => IslandVisualNode(
        island: IslandModel(
          name: '成形小岛 ${index + 1}',
          status: 'formed',
          fragmentCount: 8,
          description: '',
        ),
        fragments: const [],
      ),
    );

    await tester.pumpWidget(MaterialApp(
      theme: xiguangTheme(nightMode: true),
      home: Scaffold(
        body: IslandArchipelagoCanvas(
          islands: islands,
          selected: null,
          onSelect: (_) {},
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.bySemanticsLabel('海域 1/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mixed island sizes never overlap after automatic reordering',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fragments = List.generate(
      4,
      (index) => Fragment(
        id: index + 1,
        publicId: 'layout-fragment-$index',
        contentText: '光 $index',
        createdAt: DateTime.utc(2026, 7, 14, 8, index),
      ),
    );
    final source = [
      for (var index = 0; index < 5; index++)
        IslandVisualNode(
          island: IslandModel(
            name: '布局岛 ${index + 1}',
            status: 'star_point',
            fragmentCount: index >= 3 ? 2 : 0,
            description: '',
          ),
          fragments: index == 3
              ? fragments.take(2).toList()
              : index == 4
                  ? fragments.skip(2).toList()
                  : const [],
        ),
    ];
    final islands = [source[3], source[0], source[4], source[1], source[2]];

    await tester.pumpWidget(MaterialApp(
      theme: xiguangTheme(nightMode: true),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 390,
            height: 500,
            child: IslandArchipelagoCanvas(
              islands: islands,
              selected: null,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final bounds = [
      for (final island in islands)
        tester.getRect(find.byKey(
          ValueKey('island-bounds-${island.visualKey}'),
        )),
    ];
    for (var first = 0; first < bounds.length; first++) {
      for (var second = first + 1; second < bounds.length; second++) {
        expect(
          bounds[first].inflate(4).overlaps(bounds[second]),
          isFalse,
          reason: 'first=${bounds[first]} second=${bounds[second]}',
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newly created island opens on its own sea area',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final islands = List.generate(
      8,
      (index) => IslandVisualNode(
        island: IslandModel(
          name: '小岛 ${index + 1}',
          status: 'star_point',
          fragmentCount: 0,
          description: '',
        ),
        fragments: const [],
      ),
    );

    await tester.pumpWidget(MaterialApp(
      theme: xiguangTheme(nightMode: true),
      home: Scaffold(
        body: IslandArchipelagoCanvas(
          islands: islands,
          selected: null,
          revealIslandKey: 'name-小岛 8',
          onSelect: (_) {},
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('archipelago-page-indicator-2')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('moving a selected island to the front follows it to first sea',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = List.generate(
      6,
      (index) => IslandVisualNode(
        island: IslandModel(
          name: '小岛 ${index + 1}',
          status: 'star_point',
          fragmentCount: 0,
          description: '',
        ),
        fragments: const [],
      ),
    );
    var islands = original;
    IslandVisualNode? selected;
    late StateSetter update;

    await tester.pumpWidget(MaterialApp(
      theme: xiguangTheme(nightMode: true),
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return IslandArchipelagoCanvas(
            islands: islands,
            selected: selected,
            onSelect: (value) => setState(() => selected = value),
          );
        }),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(
      find.byKey(const ValueKey('archipelago-pager')),
      const Offset(-320, 0),
    );
    await tester.pump(const Duration(milliseconds: 500));

    update(() => selected = original.last);
    await tester.pump(const Duration(milliseconds: 400));
    update(() => islands = [original.last, ...original.take(5)]);
    await tester.pump();
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      find.byKey(const ValueKey('archipelago-page-indicator-1')),
      findsOneWidget,
    );
    expect(selected?.visualKey, original.last.visualKey);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a dimmed island clears focus instead of switching',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final islands = List.generate(
      2,
      (index) => IslandVisualNode(
        island: IslandModel(
          name: '小岛 ${index + 1}',
          status: 'star_point',
          fragmentCount: 0,
          description: '',
        ),
        fragments: const [],
      ),
    );
    IslandVisualNode? selected;

    await tester.pumpWidget(MaterialApp(
      theme: xiguangTheme(nightMode: true),
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return IslandArchipelagoCanvas(
            key: const ValueKey('blur-dismiss-canvas'),
            islands: islands,
            selected: selected,
            onSelect: (value) => setState(() => selected = value),
          );
        }),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final canvasBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('blur-dismiss-canvas')),
    );
    await tester.tapAt(canvasBox.localToGlobal(Offset(
      canvasBox.size.width * .30,
      canvasBox.size.height * .43,
    )));
    await tester.pump(const Duration(milliseconds: 400));
    expect(selected?.visualKey, islands.first.visualKey);

    await tester.tapAt(canvasBox.localToGlobal(Offset(
      canvasBox.size.width * .875,
      canvasBox.size.height * .38,
    )));
    await tester.pump(const Duration(milliseconds: 300));

    expect(selected, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press reorders islands and reflows them into fixed slots',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = [
      IslandVisualNode(
        island: const IslandModel(
          name: '拖动岛',
          status: 'star_point',
          fragmentCount: 0,
          description: '',
        ),
        fragments: const [],
      ),
      IslandVisualNode(
        island: const IslandModel(
          name: '让位岛',
          status: 'star_point',
          fragmentCount: 0,
          description: '',
        ),
        fragments: const [],
      ),
    ];
    var islands = original;
    String? movedKey;
    String? targetKey;

    await tester.pumpWidget(MaterialApp(
      theme: xiguangTheme(nightMode: true),
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return IslandArchipelagoCanvas(
            key: const ValueKey('drag-island-canvas'),
            islands: islands,
            selected: null,
            onSelect: (_) {},
            onReorder: (visualKey, targetVisualKey) {
              movedKey = visualKey;
              targetKey = targetVisualKey;
              setState(() => islands = [original.last, original.first]);
            },
          );
        }),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final dragged = find.byKey(
      ValueKey('island-slot-${original.first.visualKey}'),
    );
    final displaced = find.byKey(
      ValueKey('island-slot-${original.last.visualKey}'),
    );
    final draggedStart = tester.getCenter(dragged);
    final displacedStart = tester.getCenter(displaced);
    final gesture = await tester.startGesture(draggedStart);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(displacedStart);
    await tester.pump(const Duration(milliseconds: 80));
    await gesture.up();
    await tester.pump();

    expect(movedKey, original.first.visualKey);
    expect(targetKey, original.last.visualKey);
    expect(islands, [original.last, original.first]);

    await tester.pump(const Duration(milliseconds: 200));
    final displacedMidway = tester.getCenter(displaced);
    expect(displacedMidway.dx, lessThan(displacedStart.dx));
    expect(displacedMidway.dx, greaterThan(draggedStart.dx));

    await tester.pump(const Duration(milliseconds: 240));
    final displacedEnd = tester.getCenter(displaced);
    expect(displacedEnd.dx, closeTo(draggedStart.dx, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('favoriting from the canvas persists on the first sea',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final islands = List.generate(
      6,
      (index) => IslandVisualNode(
        island: IslandModel(
          name: '小岛 ${index + 1}',
          status: 'star_point',
          fragmentCount: 0,
          description: '',
        ),
        fragments: const [],
      ),
    );
    final container = ProviderContainer(overrides: [
      universeOverviewProvider.overrideWith((ref) async => UniverseOverview(
            islands: islands,
            branches: const [],
            fragments: const [],
            relations: const [],
          )),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: xiguangTheme(nightMode: true),
          home: const Scaffold(body: UniversePage()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byTooltip('整理小岛'), findsNothing);

    final canvasBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('island-canvas')),
    );
    await tester.tapAt(canvasBox.localToGlobal(Offset(
      canvasBox.size.width * .27,
      canvasBox.size.height * .18,
    )));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('favorite-island-button')));
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.byKey(const ValueKey('archipelago-page-indicator-1')),
      findsOneWidget,
    );
    expect(find.byTooltip('取消收藏'), findsOneWidget);
    expect(
      container
          .read(islandLayoutPreferencesProvider)
          .requireValue
          .isFavorite(islands.first.visualKey),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('edge island recenters above the focus panel when selected',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final islands = List.generate(
      5,
      (index) => IslandVisualNode(
        island: IslandModel(
          name: '小岛 ${index + 1}',
          status: 'star_point',
          fragmentCount: 0,
          description: '',
        ),
        fragments: const [],
      ),
    );
    IslandVisualNode? selected;

    await tester.pumpWidget(MaterialApp(
      theme: xiguangTheme(nightMode: true),
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return IslandArchipelagoCanvas(
            key: const ValueKey('focus-canvas'),
            islands: islands,
            selected: selected,
            onSelect: (value) => setState(() => selected = value),
          );
        }),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final canvas = find.byKey(const ValueKey('focus-canvas'));
    final canvasBox = tester.renderObject<RenderBox>(canvas);
    await tester.tapAt(canvasBox.localToGlobal(Offset(
      canvasBox.size.width * .64,
      canvasBox.size.height * .73,
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));

    final selectedIsland = find.byKey(
      const ValueKey('selected-island-scale'),
    );
    final selectedCenter = tester.getCenter(selectedIsland);
    final expectedCenter = canvasBox.localToGlobal(Offset(
      canvasBox.size.width * .5,
      canvasBox.size.height * .38,
    ));
    expect(selectedCenter.dx, closeTo(expectedCenter.dx, 1));
    expect(selectedCenter.dy, closeTo(expectedCenter.dy, 1));
    expect(tester.takeException(), isNull);
  });
}

double _scaleOf(Transform transform) => transform.transform.storage.first;

UniverseOverview _overview() {
  final fragments = [
    Fragment(
      id: 1,
      publicId: 'f1',
      contentText: '第一件事',
      tags: const ['考试周'],
      createdAt: DateTime.utc(2026, 7, 10, 8),
    ),
    Fragment(
      id: 2,
      publicId: 'f2',
      contentText: '开始复习',
      tags: const ['考试周'],
      mediaUrls: const ['photo.jpg'],
      createdAt: DateTime.utc(2026, 7, 11, 8),
    ),
    Fragment(
      id: 3,
      publicId: 'f3',
      contentText: '考完了',
      tags: const ['考试周'],
      createdAt: DateTime.utc(2026, 7, 12, 8),
    ),
  ];
  const relation = Relation(
    id: 1,
    publicId: 'r1',
    sourceFragmentId: 1,
    targetFragmentId: 2,
    relationType: 'cause',
  );
  return UniverseOverview(
    islands: [
      IslandVisualNode(
        island: const IslandModel(
          name: '考试周',
          status: 'formed',
          fragmentCount: 3,
          description: '',
        ),
        fragments: fragments,
      ),
    ],
    branches: [
      BranchVisualSummary(
        publicId: 'r1',
        name: '关于「第一件事」',
        fragments: fragments.take(2).toList(),
        edges: const [
          BranchVisualEdge(
            relation: relation,
            direction: RelationDirection.forward,
          ),
        ],
      ),
    ],
    fragments: fragments,
    relations: const [relation],
  );
}
