import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_state.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../fragment/domain/fragment.dart';
import '../../application/universe_overview_provider.dart';
import '../../application/island_layout_controller.dart';
import '../../domain/island_layout_preferences.dart';
import '../../domain/island_model.dart';
import '../../domain/island_visual_stage.dart';
import '../../domain/universe_overview.dart';
import '../widgets/branch_river_canvas.dart';
import '../widgets/all_seas_overview_canvas.dart';
import '../widgets/island_archipelago_canvas.dart';
import '../widgets/island_sprite_visual.dart';

// PAGE_SIZE_EXEMPT: 本轮保留海域切换、岛屿交互与分支视图的统一状态编排；
// 后续将场景工具栏、岛屿详情层和各模式内容拆为独立 widgets 后移除此豁免。
enum _UniverseMode { islands, branches }

enum IslandSceneMode { currentSea, allSeas }

class UniversePage extends ConsumerStatefulWidget {
  const UniversePage({
    super.key,
    this.showBranches = false,
    this.revealIslandKey,
  });

  final bool showBranches;
  final String? revealIslandKey;

  @override
  ConsumerState<UniversePage> createState() => _UniversePageState();
}

class _UniversePageState extends ConsumerState<UniversePage> {
  late _UniverseMode _mode;
  bool _listMode = false;
  IslandSceneMode _islandSceneMode = IslandSceneMode.currentSea;
  int _currentSeaIndex = 0;
  IslandSeaViewportSnapshot? _currentSeaViewport;
  int? _overviewExitSeaIndex;
  IslandVisualNode? _selectedIsland;
  BranchVisualSummary? _selectedBranch;
  int? _selectedNodeId;
  String? _pendingRevealIslandKey;

  @override
  void initState() {
    super.initState();
    _mode =
        widget.showBranches ? _UniverseMode.branches : _UniverseMode.islands;
    _pendingRevealIslandKey = widget.revealIslandKey;
  }

  @override
  void didUpdateWidget(covariant UniversePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealIslandKey != oldWidget.revealIslandKey) {
      _pendingRevealIslandKey = widget.revealIslandKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(universeOverviewProvider);
    final layoutPreferences = ref.watch(islandLayoutPreferencesProvider);
    final islandLayout =
        layoutPreferences.valueOrNull ?? const IslandLayoutPreferences();
    final theme = NightTheme.of(context);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: _islandSceneMode != IslandSceneMode.allSeas,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _islandSceneMode == IslandSceneMode.allSeas) {
          _handleOverviewBack();
        }
      },
      child: XiguangPage(
        scrollable: false,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s18,
          AppSpacing.s12,
          AppSpacing.s18,
          AppSpacing.pageBottomNav + bottomSafe,
        ),
        backgroundLayer: const _UniverseAtmosphere(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          overview.when(
            data: (data) => _Header(
              overview: data,
              mode: _mode,
              listMode: _listMode,
              islandSceneMode: _islandSceneMode,
              onToggleOverview: _toggleOverview,
              onToggleList: _toggleListMode,
              onGroupSuggestions: ref.watch(aiEnabledProvider)
                  ? () => context.push('/ai/island-groups')
                  : null,
            ),
            loading: () => _Header.loading(
              mode: _mode,
              listMode: _listMode,
              islandSceneMode: _islandSceneMode,
              onToggleOverview: _toggleOverview,
              onToggleList: _toggleListMode,
              onGroupSuggestions: null,
            ),
            error: (_, __) => _Header.loading(
              mode: _mode,
              listMode: _listMode,
              islandSceneMode: _islandSceneMode,
              onToggleOverview: _toggleOverview,
              onToggleList: _toggleListMode,
              onGroupSuggestions: null,
            ),
          ),
          const SizedBox(height: AppSpacing.s14),
          Center(
            child: _ModeSwitch(
              mode: _mode,
              onChanged: (mode) => setState(() {
                _mode = mode;
                if (mode == _UniverseMode.branches) {
                  _islandSceneMode = IslandSceneMode.currentSea;
                  _overviewExitSeaIndex = null;
                }
                _selectedIsland = null;
                _selectedBranch = null;
                _selectedNodeId = null;
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.s10),
          Expanded(
            child: overview.when(
              data: (data) {
                final islands = _orderedIslands(data.islands, islandLayout);
                return Stack(children: [
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: AppMotion.slow,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _listMode
                          ? _UniverseList(
                              key: ValueKey('list-$_mode'),
                              mode: _mode,
                              islands: islands,
                              branches: data.branches,
                              favoriteKeys: islandLayout.favorites,
                              onIslandTap: _openIsland,
                              onBranchTap: _selectBranch,
                            )
                          : _mode == _UniverseMode.islands
                              ? Stack(
                                  key: const ValueKey('island-scene-layer'),
                                  children: [
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        ignoring: _islandSceneMode ==
                                            IslandSceneMode.allSeas,
                                        child: TickerMode(
                                          enabled: _islandSceneMode ==
                                              IslandSceneMode.currentSea,
                                          child: Opacity(
                                            opacity: _islandSceneMode ==
                                                    IslandSceneMode.currentSea
                                                ? 1
                                                : 0,
                                            child: IslandArchipelagoCanvas(
                                              key: const ValueKey(
                                                  'island-canvas'),
                                              islands: islands,
                                              selected: _selectedIsland,
                                              onSelect: _selectIsland,
                                              initialSeaIndex: _currentSeaIndex,
                                              onSeaChanged: (index) =>
                                                  _currentSeaIndex = index,
                                              onViewportChanged: (snapshot) {
                                                _currentSeaViewport = snapshot;
                                              },
                                              revealIslandKey:
                                                  _pendingRevealIslandKey,
                                              onRevealHandled: () {
                                                if (_pendingRevealIslandKey !=
                                                    null) {
                                                  setState(() =>
                                                      _pendingRevealIslandKey =
                                                          null);
                                                }
                                              },
                                              onReorder: (visualKey,
                                                      targetVisualKey) =>
                                                  ref
                                                      .read(
                                                          islandLayoutPreferencesProvider
                                                              .notifier)
                                                      .swap(
                                                        visualKey,
                                                        targetVisualKey,
                                                        islands
                                                            .map((island) =>
                                                                island
                                                                    .visualKey)
                                                            .toList(
                                                                growable:
                                                                    false),
                                                      ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_islandSceneMode ==
                                        IslandSceneMode.allSeas)
                                      Positioned.fill(
                                        child: AllSeasOverviewCanvas(
                                          key:
                                              const ValueKey('all-seas-canvas'),
                                          islands: islands,
                                          currentSeaIndex: _currentSeaIndex,
                                          sourceViewport: _currentSeaViewport,
                                          selectedIsland: _selectedIsland,
                                          favoriteKeys: islandLayout.favorites,
                                          exitSeaIndex: _overviewExitSeaIndex,
                                          onIslandSelected:
                                              (island, seaIndex) =>
                                                  setState(() {
                                            _selectedIsland = island;
                                          }),
                                          onExitCompleted:
                                              _completeOverviewExit,
                                        ),
                                      ),
                                  ],
                                )
                              : BranchRiverCanvas(
                                  key: const ValueKey('branch-canvas'),
                                  branches: data.branches,
                                  selectedBranch: _selectedBranch,
                                  selectedNodeId: _selectedNodeId,
                                  onSelectBranch: _selectBranch,
                                  onSelectNode: (id) =>
                                      setState(() => _selectedNodeId = id),
                                ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedSwitcher(
                      key: const ValueKey('island-focus-switcher'),
                      duration: AppMotion.islandModeForward,
                      reverseDuration: AppMotion.normal,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild
                        ],
                      ),
                      transitionBuilder: (child, animation) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                          reverseCurve: Curves.easeInCubic,
                        );
                        return FadeTransition(
                          opacity: curved,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, .14),
                              end: Offset.zero,
                            ).animate(curved),
                            child: ScaleTransition(
                              alignment: Alignment.bottomCenter,
                              scale: Tween<double>(begin: .94, end: 1)
                                  .animate(curved),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: _selectedIsland == null
                          ? const SizedBox.shrink(
                              key: ValueKey('island-focus-empty'),
                            )
                          : _islandSceneMode == IslandSceneMode.allSeas
                              ? _OverviewIslandPanel(
                                  key: ValueKey(
                                    'overview-island-${_selectedIsland!.visualKey}',
                                  ),
                                  island: _selectedIsland!,
                                  onClose: () => _selectIsland(null),
                                  onOpen: () => _openIsland(_selectedIsland!),
                                )
                              : _IslandFocusPanel(
                                  key: ValueKey(
                                    'island-focus-${_selectedIsland!.visualKey}',
                                  ),
                                  island: _selectedIsland!,
                                  favorite: islandLayout
                                      .isFavorite(_selectedIsland!.visualKey),
                                  onClose: () => _selectIsland(null),
                                  onFavorite: () => ref
                                      .read(islandLayoutPreferencesProvider
                                          .notifier)
                                      .toggleFavorite(
                                          _selectedIsland!.visualKey),
                                  onDelete: () =>
                                      _confirmDeleteIsland(_selectedIsland!),
                                  onOpen: () => _openIsland(_selectedIsland!),
                                  onWeave: () =>
                                      _weaveFromIsland(_selectedIsland!),
                                ),
                    ),
                  ),
                  if (_selectedBranch != null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _BranchFocusPanel(
                        branch: _selectedBranch!,
                        selectedNode: _selectedFragment(_selectedBranch!),
                        onClose: () => _selectBranch(null),
                        onOpen: () => context.push(
                          '/branches/${Uri.encodeComponent(_selectedBranch!.publicId)}',
                        ),
                        onAdd: () => _weaveFromBranch(_selectedBranch!),
                      ),
                    ),
                  if (_selectedIsland == null &&
                      _selectedBranch == null &&
                      _islandSceneMode == IslandSceneMode.currentSea)
                    Positioned(
                      right: AppSpacing.s6,
                      bottom: AppSpacing.s6,
                      child: _CreateButton(
                        mode: _mode,
                        onTap: () => _mode == _UniverseMode.islands
                            ? context.push('/islands/create')
                            : _createBranch(data),
                      ),
                    ),
                ]);
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: theme.accent),
              ),
              error: (_, __) => _LoadError(
                onRetry: () => ref.invalidate(universeOverviewProvider),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _selectIsland(IslandVisualNode? island) {
    setState(() {
      _selectedIsland = island;
      _selectedBranch = null;
      _selectedNodeId = null;
    });
  }

  void _toggleListMode() {
    setState(() {
      _listMode = !_listMode;
      _selectedIsland = null;
      _selectedBranch = null;
      _selectedNodeId = null;
    });
  }

  void _toggleOverview() {
    if (_mode != _UniverseMode.islands) return;
    if (_islandSceneMode == IslandSceneMode.allSeas) {
      if (_listMode) {
        setState(() => _listMode = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _beginOverviewExit(_currentSeaIndex);
          }
        });
        return;
      }
      _beginOverviewExit(_currentSeaIndex);
      return;
    }
    setState(() {
      _listMode = false;
      _islandSceneMode = IslandSceneMode.allSeas;
      _overviewExitSeaIndex = null;
      _selectedIsland = null;
      _selectedBranch = null;
      _selectedNodeId = null;
    });
  }

  void _handleOverviewBack() {
    if (_listMode) {
      _toggleListMode();
      return;
    }
    if (_selectedIsland != null) {
      _selectIsland(null);
      return;
    }
    _beginOverviewExit(_currentSeaIndex);
  }

  void _beginOverviewExit(int seaIndex) {
    setState(() {
      _selectedIsland = null;
      _overviewExitSeaIndex = seaIndex;
    });
  }

  void _completeOverviewExit(int seaIndex) {
    if (!mounted || _overviewExitSeaIndex != seaIndex) return;
    setState(() {
      _currentSeaIndex = seaIndex;
      _islandSceneMode = IslandSceneMode.currentSea;
      _overviewExitSeaIndex = null;
      _selectedIsland = null;
    });
  }

  void _openIsland(IslandVisualNode island) {
    context.push(
      _islandDetailPath(island.island),
      extra: island,
    );
  }

  Future<void> _confirmDeleteIsland(IslandVisualNode island) async {
    final islandId = island.island.islandId;
    if (islandId <= 0) {
      _showNotice('这座本地聚合的小岛暂时不能删除。');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = NightTheme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.surfaceHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          title: Text(
            '删除「${island.island.name}」？',
            style: AppText.titleMedium.copyWith(color: theme.foreground),
          ),
          content: Text(
            '只会删除这座小岛，岛内的光片仍会保留在线和其他小岛中。',
            style: AppText.body.copyWith(color: theme.foregroundMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除小岛'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(universeActionsProvider).deleteIsland(islandId);
      if (!mounted) return;
      setState(() => _selectedIsland = null);
      _showNotice('小岛已删除，里面的光仍然保留。');
    } catch (_) {
      if (mounted) _showNotice('暂时无法删除这座小岛，请稍后再试。');
    }
  }

  void _selectBranch(BranchVisualSummary? branch) {
    setState(() {
      _selectedBranch = branch;
      _selectedIsland = null;
      if (branch == null) _selectedNodeId = null;
    });
  }

  Fragment? _selectedFragment(BranchVisualSummary branch) {
    final id = _selectedNodeId;
    if (id == null) return null;
    return branch.fragments.where((fragment) => fragment.id == id).firstOrNull;
  }

  void _weaveFromIsland(IslandVisualNode island) {
    if (island.fragments.isEmpty) {
      _showNotice('这座岛还没有可以织线的光。');
      return;
    }
    final recent = [...island.fragments]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    context.push('/weave/${recent.first.id}');
  }

  void _weaveFromBranch(BranchVisualSummary branch) {
    if (branch.fragments.isEmpty) return;
    context.push('/weave/${branch.fragments.last.id}');
  }

  void _createBranch(UniverseOverview overview) {
    if (overview.fragments.isEmpty) {
      _showNotice('先捕下一束光，再从它织出支线。');
      context.go('/capture');
      return;
    }
    final fragments = [...overview.fragments]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    context.push('/weave/${fragments.first.id}');
  }

  void _showNotice(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.overview,
    required this.mode,
    required this.listMode,
    required this.islandSceneMode,
    required this.onToggleOverview,
    required this.onToggleList,
    required this.onGroupSuggestions,
  }) : loading = false;

  const _Header.loading({
    required this.mode,
    required this.listMode,
    required this.islandSceneMode,
    required this.onToggleOverview,
    required this.onToggleList,
    required this.onGroupSuggestions,
  })  : overview = null,
        loading = true;

  final UniverseOverview? overview;
  final bool loading;
  final _UniverseMode mode;
  final bool listMode;
  final IslandSceneMode islandSceneMode;
  final VoidCallback onToggleOverview;
  final VoidCallback onToggleList;
  final VoidCallback? onGroupSuggestions;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final data = overview;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'PRIVATE SKY',
            style: AppText.eyebrow.copyWith(color: theme.accent),
          ),
          const SizedBox(height: AppSpacing.s6),
          Text('屿', style: AppText.hero.copyWith(color: theme.foreground)),
          const SizedBox(height: AppSpacing.s6),
          Text(
            '标签、情绪和旧光慢慢连成一张只属于你的星图。',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(color: theme.foreground),
          ),
          const SizedBox(height: AppSpacing.s6),
          AnimatedSwitcher(
            duration: AppMotion.normal,
            child: Text(
              loading || data == null
                  ? '正在看见你的世界…'
                  : '${data.islandCount} 座岛 · ${data.branchCount} 条支线 · ${data.fragmentCount} 束光',
              key: ValueKey(
                  '${data?.islandCount}-${data?.branchCount}-${data?.fragmentCount}'),
              style: AppText.caption.copyWith(color: theme.foregroundMuted),
            ),
          ),
        ]),
      ),
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (mode == _UniverseMode.islands && onGroupSuggestions != null)
          IconButton(
            tooltip: '看看哪些岛可以成群',
            onPressed: onGroupSuggestions,
            icon: Icon(Icons.hub_outlined, color: theme.accent),
          ),
        if (mode == _UniverseMode.islands)
          Semantics(
            button: true,
            label:
                islandSceneMode == IslandSceneMode.allSeas ? '返回当前海域' : '俯瞰全海域',
            child: ExcludeSemantics(
              child: IconButton(
                tooltip: islandSceneMode == IslandSceneMode.allSeas
                    ? '返回当前海域'
                    : '俯瞰全海域',
                onPressed: onToggleOverview,
                icon: AnimatedSwitcher(
                  duration: AppMotion.quick,
                  child: Icon(
                    islandSceneMode == IslandSceneMode.allSeas
                        ? Icons.center_focus_strong_rounded
                        : Icons.public_rounded,
                    key: ValueKey(islandSceneMode),
                    color: theme.foreground,
                  ),
                ),
              ),
            ),
          ),
        Semantics(
          button: true,
          label: listMode ? '返回图景' : '列表查看',
          child: ExcludeSemantics(
            child: IconButton(
              tooltip: listMode ? '返回图景' : '列表查看',
              onPressed: onToggleList,
              icon: AnimatedSwitcher(
                duration: AppMotion.quick,
                child: Icon(
                  listMode
                      ? Icons.map_outlined
                      : Icons.format_list_bulleted_rounded,
                  key: ValueKey(listMode),
                  color: theme.foreground,
                ),
              ),
            ),
          ),
        ),
      ]),
    ]);
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final _UniverseMode mode;
  final ValueChanged<_UniverseMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: theme.surfaceHigh.withValues(alpha: theme.isNight ? .48 : .72),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _ModeItem(
          label: '小岛',
          icon: Icons.terrain_outlined,
          selected: mode == _UniverseMode.islands,
          onTap: () => onChanged(_UniverseMode.islands),
        ),
        _ModeItem(
          label: '支线',
          icon: Icons.route_rounded,
          selected: mode == _UniverseMode.branches,
          onTap: () => onChanged(_UniverseMode.branches),
        ),
      ]),
    );
  }
}

class _ModeItem extends StatelessWidget {
  const _ModeItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: Curves.easeOutCubic,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14),
          decoration: BoxDecoration(
            color: selected ? theme.accent.withValues(alpha: .22) : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(children: [
            Icon(icon,
                size: 16,
                color: selected ? theme.foreground : theme.foregroundMuted),
            const SizedBox(width: AppSpacing.s6),
            Text(label,
                style: AppText.captionStrong.copyWith(
                  color: selected ? theme.foreground : theme.foregroundMuted,
                )),
          ]),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.mode, required this.onTap});

  final _UniverseMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final island = mode == _UniverseMode.islands;
    return Semantics(
      button: true,
      label: island ? '新建小岛' : '新建支线',
      child: Material(
        color: theme.accent,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              island ? Icons.add_location_alt_outlined : Icons.add_link_rounded,
              color: theme.background,
              size: 23,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewIslandPanel extends StatelessWidget {
  const _OverviewIslandPanel({
    super.key,
    required this.island,
    required this.onClose,
    required this.onOpen,
  });

  final IslandVisualNode island;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s14,
              AppSpacing.s10,
              AppSpacing.sm,
              AppSpacing.s10,
            ),
            color: theme.surfaceHigh.withValues(
              alpha: theme.isNight ? .76 : .86,
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      island.island.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(
                        color: theme.foreground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Text(
                      '${island.fragmentCount} 束光',
                      style: AppText.caption.copyWith(
                        color: theme.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const ValueKey('open-overview-island'),
                onPressed: onOpen,
                child: const Text('打开小岛'),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: onClose,
                icon: Icon(Icons.close_rounded,
                    size: 19, color: theme.foregroundMuted),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _IslandFocusPanel extends StatelessWidget {
  const _IslandFocusPanel({
    super.key,
    required this.island,
    required this.favorite,
    required this.onClose,
    required this.onFavorite,
    required this.onDelete,
    required this.onOpen,
    required this.onWeave,
  });

  final IslandVisualNode island;
  final bool favorite;
  final VoidCallback onClose;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;
  final VoidCallback onOpen;
  final VoidCallback onWeave;

  @override
  Widget build(BuildContext context) {
    return _FocusPanel(
      onClose: onClose,
      headerAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FocusIconAction(
            key: const ValueKey('favorite-island-button'),
            tooltip: favorite ? '取消收藏' : '收藏到第一片海域',
            icon: favorite
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            onPressed: onFavorite,
          ),
          _FocusIconAction(
            key: const ValueKey('delete-island-button'),
            tooltip: '删除小岛',
            icon: Icons.delete_outline_rounded,
            danger: true,
            onPressed: onDelete,
          ),
        ],
      ),
      title: island.island.name,
      subtitle: _islandRange(island),
      stats: [
        _VisualStat(Icons.notes_rounded, island.textCount),
        _VisualStat(Icons.image_outlined, island.imageCount),
        _VisualStat(Icons.graphic_eq_rounded, island.audioCount),
      ],
      previews:
          island.fragments.take(3).map((fragment) => fragment.title).toList(),
      primaryLabel: '打开小岛',
      secondaryLabel: '从这里织支线',
      onPrimary: onOpen,
      onSecondary: onWeave,
    );
  }
}

class _FocusIconAction extends StatelessWidget {
  const _FocusIconAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 30,
          child: IconButton(
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            visualDensity: VisualDensity.compact,
            onPressed: onPressed,
            icon: Icon(
              icon,
              size: 18,
              color: danger ? theme.danger : theme.foregroundMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _BranchFocusPanel extends StatelessWidget {
  const _BranchFocusPanel({
    required this.branch,
    required this.selectedNode,
    required this.onClose,
    required this.onOpen,
    required this.onAdd,
  });

  final BranchVisualSummary branch;
  final Fragment? selectedNode;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final direction = branch.hasBidirectional ? '含双向连接' : '顺向发展';
    return _FocusPanel(
      onClose: onClose,
      title: branch.name,
      subtitle: selectedNode?.title ?? '按时间展开 · $direction',
      stats: [
        _VisualStat(Icons.trip_origin_rounded, branch.fragmentCount),
        _VisualStat(Icons.alt_route_rounded, branch.edgeCount),
      ],
      previews:
          branch.fragments.take(3).map((fragment) => fragment.title).toList(),
      primaryLabel: '展开支线',
      secondaryLabel: '添加一束光',
      onPrimary: onOpen,
      onSecondary: onAdd,
    );
  }
}

class _FocusPanel extends StatelessWidget {
  const _FocusPanel({
    required this.onClose,
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.previews,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    this.headerAction,
  });

  final VoidCallback onClose;
  final String title;
  final String subtitle;
  final List<_VisualStat> stats;
  final List<String> previews;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(AppSpacing.s6),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.s12, AppSpacing.md, AppSpacing.s14),
          decoration: BoxDecoration(
            color: theme.surface.withValues(alpha: theme.isNight ? .86 : .82),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: theme.border.withValues(alpha: .38)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.titleSmall
                              .copyWith(color: theme.foreground)),
                      const SizedBox(height: AppSpacing.s3),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption
                              .copyWith(color: theme.foregroundMuted)),
                    ]),
              ),
              ...stats.map((stat) => Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.s10),
                    child: Row(children: [
                      Icon(stat.icon, size: 14, color: theme.foregroundMuted),
                      const SizedBox(width: AppSpacing.s3),
                      Text('${stat.value}',
                          style: AppText.microLabel
                              .copyWith(color: theme.foregroundMuted)),
                    ]),
                  )),
              if (headerAction != null) headerAction!,
              Semantics(
                button: true,
                label: '关闭预览',
                child: ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: 30,
                    child: IconButton(
                      tooltip: '关闭',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 30, height: 30),
                      visualDensity: VisualDensity.compact,
                      onPressed: onClose,
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: theme.foregroundMuted),
                    ),
                  ),
                ),
              ),
            ]),
            if (previews.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s6),
              SizedBox(
                height: 24,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: previews.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.s6),
                  itemBuilder: (_, index) => Text(
                    previews[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: theme.foreground.withValues(alpha: .72),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: onPrimary,
                  child: Text(primaryLabel),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _VisualStat {
  const _VisualStat(this.icon, this.value);
  final IconData icon;
  final int value;
}

class _UniverseList extends StatelessWidget {
  const _UniverseList({
    super.key,
    required this.mode,
    required this.islands,
    required this.branches,
    required this.favoriteKeys,
    required this.onIslandTap,
    required this.onBranchTap,
  });

  final _UniverseMode mode;
  final List<IslandVisualNode> islands;
  final List<BranchVisualSummary> branches;
  final Set<String> favoriteKeys;
  final ValueChanged<IslandVisualNode> onIslandTap;
  final ValueChanged<BranchVisualSummary> onBranchTap;

  @override
  Widget build(BuildContext context) {
    if (mode == _UniverseMode.islands) {
      final seas = buildIslandSeaPages(islands);
      if (seas.isEmpty) {
        return const _UniverseListEmpty(
          icon: Icons.terrain_outlined,
          text: '第一座小岛会在这里出现',
        );
      }
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          0,
          AppSpacing.s6,
          0,
          AppSpacing.universeListBottom,
        ),
        itemCount: seas.length,
        itemBuilder: (context, seaIndex) {
          final bottomPadding =
              seaIndex == seas.length - 1 ? 0.0 : AppSpacing.s14;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: _IslandSeaList(
              seaIndex: seaIndex,
              islands: seas[seaIndex],
              favoriteKeys: favoriteKeys,
              onTap: onIslandTap,
            ),
          );
        },
      );
    }
    if (branches.isEmpty) {
      return const _UniverseListEmpty(
        icon: Icons.route_rounded,
        text: '织好的支线会在这里依次展开',
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          0, AppSpacing.s10, 0, AppSpacing.universeListBottom),
      itemCount: branches.length,
      itemBuilder: (_, index) {
        final item = branches[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s10),
          child: _BranchListRow(
            branch: item,
            onTap: () => onBranchTap(item),
          ),
        );
      },
    );
  }
}

class _IslandSeaList extends StatelessWidget {
  const _IslandSeaList({
    required this.seaIndex,
    required this.islands,
    required this.favoriteKeys,
    required this.onTap,
  });

  final int seaIndex;
  final List<IslandVisualNode> islands;
  final Set<String> favoriteKeys;
  final ValueChanged<IslandVisualNode> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final favorites = islands
        .where((island) => favoriteKeys.contains(island.visualKey))
        .length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s6,
          0,
          AppSpacing.s6,
          AppSpacing.s7,
        ),
        child: Row(children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: .82),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.s6),
          Text(
            '第${seaIndex + 1}片海域',
            style: AppText.captionStrong.copyWith(color: theme.foreground),
          ),
          const Spacer(),
          if (favorites > 0) ...[
            Icon(Icons.bookmark_rounded, size: 13, color: theme.accent),
            const SizedBox(width: AppSpacing.s3),
          ],
          Text(
            favorites > 0
                ? '$favorites 座常驻 · 共 ${islands.length} 座'
                : '${islands.length} 座小岛',
            style: AppText.microLabel.copyWith(color: theme.foregroundMuted),
          ),
        ]),
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.surfaceHigh.withValues(
              alpha: theme.isNight ? .30 : .64,
            ),
          ),
          child: Column(children: [
            for (var index = 0; index < islands.length; index++) ...[
              _IslandListRow(
                island: islands[index],
                favorite: favoriteKeys.contains(islands[index].visualKey),
                onTap: () => onTap(islands[index]),
              ),
              if (index != islands.length - 1)
                Divider(
                  height: 1,
                  indent: 82,
                  color: theme.border.withValues(alpha: .26),
                ),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _IslandListRow extends StatelessWidget {
  const _IslandListRow({
    required this.island,
    required this.favorite,
    required this.onTap,
  });

  final IslandVisualNode island;
  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Semantics(
      button: true,
      label: '打开小岛 ${island.island.name}',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s10,
              AppSpacing.s7,
              AppSpacing.s10,
              AppSpacing.s7,
            ),
            child: Row(children: [
              SizedBox(
                width: 58,
                height: 54,
                child: IslandSpriteVisual(
                  island: island,
                  width: 58,
                  height: 54,
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                          island.island.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyStrong.copyWith(
                            color: theme.foreground,
                          ),
                        ),
                      ),
                      if (favorite) ...[
                        const SizedBox(width: AppSpacing.s6),
                        Icon(
                          Icons.bookmark_rounded,
                          size: 14,
                          color: theme.accent,
                        ),
                      ],
                    ]),
                    const SizedBox(height: AppSpacing.s5),
                    Row(children: [
                      Text(
                        _islandStageLabel(island.visualStage),
                        style: AppText.microLabel.copyWith(
                          color: theme.accent,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s9),
                      if (island.fragmentCount == 0)
                        Text(
                          '还没有光片',
                          style: AppText.caption.copyWith(
                            color: theme.foregroundMuted,
                          ),
                        )
                      else ...[
                        _MiniStat(
                          icon: Icons.auto_awesome_rounded,
                          value: island.fragmentCount,
                        ),
                        if (island.imageCount > 0)
                          _MiniStat(
                            icon: Icons.image_outlined,
                            value: island.imageCount,
                          ),
                        if (island.audioCount > 0)
                          _MiniStat(
                            icon: Icons.graphic_eq_rounded,
                            value: island.audioCount,
                          ),
                      ],
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: theme.foregroundMuted.withValues(alpha: .66),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s9),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: theme.foregroundMuted),
        const SizedBox(width: AppSpacing.s3),
        Text(
          '$value',
          style: AppText.microLabel.copyWith(color: theme.foregroundMuted),
        ),
      ]),
    );
  }
}

class _BranchListRow extends StatelessWidget {
  const _BranchListRow({required this.branch, required this.onTap});

  final BranchVisualSummary branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Material(
      color: theme.surfaceHigh.withValues(alpha: theme.isNight ? .30 : .64),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(Icons.route_rounded, color: theme.accent, size: 22),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(color: theme.foreground),
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Row(children: [
                    Text(
                      _branchOrderLabel(branch.orderMode),
                      style: AppText.microLabel.copyWith(color: theme.accent),
                    ),
                    const SizedBox(width: AppSpacing.s9),
                    _MiniStat(
                      icon: Icons.radio_button_checked_rounded,
                      value: branch.fragmentCount,
                    ),
                    _MiniStat(
                      icon: branch.hasBidirectional
                          ? Icons.sync_alt_rounded
                          : Icons.arrow_downward_rounded,
                      value: branch.edgeCount,
                    ),
                  ]),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: theme.foregroundMuted.withValues(alpha: .66),
            ),
          ]),
        ),
      ),
    );
  }
}

class _UniverseListEmpty extends StatelessWidget {
  const _UniverseListEmpty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 34, color: theme.accent.withValues(alpha: .72)),
        const SizedBox(height: AppSpacing.s10),
        Text(
          text,
          style: AppText.bodyMuted.copyWith(color: theme.foregroundMuted),
        ),
      ]),
    );
  }
}

String _islandStageLabel(IslandVisualStage stage) => switch (stage) {
      IslandVisualStage.shoal => '初生浅滩',
      IslandVisualStage.sprouting => '开始萌芽',
      IslandVisualStage.growing => '正在生长',
      IslandVisualStage.formed => '已经成岛',
      IslandVisualStage.dormant => '暂时沉静',
      IslandVisualStage.relit => '重新亮起',
    };

String _branchOrderLabel(BranchOrderMode mode) => switch (mode) {
      BranchOrderMode.chronological => '时间顺序',
      BranchOrderMode.development => '发展顺序',
      BranchOrderMode.custom => '自定义顺序',
    };

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Center(
      child: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text('重新看见这片世界',
            style: AppText.body.copyWith(color: theme.foreground)),
      ),
    );
  }
}

class _UniverseAtmosphere extends StatelessWidget {
  const _UniverseAtmosphere();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(.35, -.28),
          radius: 1.18,
          colors: [
            theme.accent.withValues(alpha: theme.isNight ? .10 : .08),
            theme.background.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

List<IslandVisualNode> _orderedIslands(
  List<IslandVisualNode> islands,
  IslandLayoutPreferences preferences,
) {
  final indexed = islands.indexed.toList();
  final orderIndex = {
    for (final entry in preferences.order.indexed) entry.$2: entry.$1,
  };
  indexed.sort((a, b) {
    final aFavorite = preferences.isFavorite(a.$2.visualKey);
    final bFavorite = preferences.isFavorite(b.$2.visualKey);
    if (aFavorite != bFavorite) return aFavorite ? -1 : 1;
    final aOrder = orderIndex[a.$2.visualKey];
    final bOrder = orderIndex[b.$2.visualKey];
    if (aOrder != null || bOrder != null) {
      if (aOrder == null) return 1;
      if (bOrder == null) return -1;
      final comparison = aOrder.compareTo(bOrder);
      if (comparison != 0) return comparison;
    }
    return a.$1.compareTo(b.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

String _islandDetailPath(IslandModel island) {
  final routeId = island.islandId > 0 ? '${island.islandId}' : island.name;
  return '/islands/${Uri.encodeComponent(routeId)}';
}

String _islandRange(IslandVisualNode island) {
  final first = island.firstAt?.toLocal();
  final last = island.lastAt?.toLocal();
  if (first == null || last == null) return '${island.fragmentCount} 束光';
  String date(DateTime value) => '${value.month}月${value.day}日';
  return first.year == last.year &&
          first.month == last.month &&
          first.day == last.day
      ? '${date(first)} · ${island.fragmentCount} 束光'
      : '${date(first)}—${date(last)} · ${island.fragmentCount} 束光';
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
