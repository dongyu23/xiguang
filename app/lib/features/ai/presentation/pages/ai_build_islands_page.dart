import 'dart:async';

// PAGE_SIZE_EXEMPT: migration in progress; AI request flow and island preview cards will be extracted.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';

import '../../application/ai_build_islands_controller.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_chip.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../../ui/spaces/space_canvas.dart';

class AiBuildIslandsPage extends ConsumerStatefulWidget {
  const AiBuildIslandsPage({super.key});

  @override
  ConsumerState<AiBuildIslandsPage> createState() => _AiBuildIslandsPageState();
}

class _AiBuildIslandsPageState extends ConsumerState<AiBuildIslandsPage> {
  int _phase = 0;
  String? _error;
  String? _outcomeStatus;
  Map<String, dynamic>? _result;
  final _selectedIslandKeys = <String>{};
  final _createdIslandKeys = <String>{};
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    final phases = ['正在读你的光片…', '发现了一些隐秘的联系…', '正在给它们取名字…'];
    for (var i = 0; i < phases.length; i++) {
      if (!mounted) return;
      setState(() => _phase = i);
      // 每段提示停留 2s——语义类比 SnackBar 展示时长，复用 AppMotion.snackbar
      // 避免为单一阶段流程膨胀 token 库
      await Future.delayed(AppMotion.snackbar);
    }

    try {
      final body =
          await ref.read(aiBuildIslandsControllerProvider.notifier).analyze();
      if (!mounted) return;
      if (body['status'] == 'rate_limited') {
        setState(() {
          _outcomeStatus = 'rate_limited';
          _error = body['message'] as String? ?? '今天已经整理过啦。';
        });
      } else if (body['status'] == 'not_enough') {
        setState(() {
          _outcomeStatus = 'not_enough';
          _error = body['message'] as String? ?? '光还不够多。';
        });
      } else if (body['status'] == 'error' || body['status'] == 'parse_error') {
        setState(() {
          _outcomeStatus = 'error';
          _error = body['message'] as String? ?? '星图管理员暂时无法工作。';
        });
      } else {
        final islands = (body['islands'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        setState(() {
          _outcomeStatus = body['status'] as String? ?? 'success';
          _result = body;
          _selectedIslandKeys
            ..clear()
            ..addAll(List.generate(
              islands.length,
              (index) => _islandKey(index, islands[index]),
            ));
          _createdIslandKeys.clear();
          _confirming = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _outcomeStatus = 'error';
        _error = '星图管理员暂时无法工作。请稍后再试。';
      });
    }
  }

  Future<bool> _createIsland(Map<String, dynamic> island) async {
    final name = island['name'] as String;
    try {
      await ref
          .read(aiBuildIslandsControllerProvider.notifier)
          .createIsland(island);
      return true;
    } catch (_) {
      if (mounted) {
        showOverlaySnackBar(
          context,
          SnackBar(content: Text('创建「$name」失败，请稍后再试。')),
        );
      }
      return false;
    }
  }

  Future<void> _confirmSelectedIslands(
    List<Map<String, dynamic>> islands,
  ) async {
    if (_confirming) return;
    final pending = islands.asMap().entries.where((entry) {
      final key = _islandKey(entry.key, entry.value);
      return _selectedIslandKeys.contains(key) &&
          !_createdIslandKeys.contains(key);
    }).toList();
    if (pending.isEmpty) return;

    setState(() => _confirming = true);
    var createdCount = 0;
    for (final entry in pending) {
      final key = _islandKey(entry.key, entry.value);
      final created = await _createIsland(entry.value);
      if (!mounted) return;
      if (created) {
        createdCount += 1;
        setState(() => _createdIslandKeys.add(key));
      }
    }
    if (!mounted) return;
    setState(() => _confirming = false);
    if (createdCount > 0) {
      showOverlaySnackBar(
        context,
        SnackBar(content: Text('已把 $createdCount 座岛屿加入你的宇宙。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return XiguangPage(
      scrollable: false,
      backgroundLayer: const AtmosphereBackground(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s22,
        AppSpacing.s12,
        AppSpacing.s22,
        AppSpacing.pageBottomNav,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AiBuildHeader(
            onBack: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _result != null
                ? _buildResults()
                : _error != null
                    ? _buildError()
                    : _buildAnalyzing(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzing() {
    final theme = NightTheme.of(context);
    final phases = ['正在读你的光片…', '发现了一些隐秘的联系…', '正在给它们取名字…'];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              color: AppColors.lilac.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.lilac.withValues(alpha: .24),
              ),
            ),
            child: Icon(
              Icons.auto_awesome_outlined,
              size: 44,
              color: theme.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            phases[_phase.clamp(0, phases.length - 1)],
            style: AppText.titleSmall.copyWith(color: theme.foreground),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          LinearProgressIndicator(
            value: (_phase + 1) / phases.length,
            color: theme.accent,
            backgroundColor: AppColors.teaGreen.withValues(alpha: .12),
          ),
        ]),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: XiguangEmptyState(
        title: '星图管理员暂时没有回应',
        description: _error!,
        icon: Icons.auto_awesome_outlined,
        action: Column(mainAxisSize: MainAxisSize.min, children: [
          XiguangButton(
            label: _outcomeStatus == 'not_enough' ? '重新看看' : '再试一次',
            expand: false,
            onPressed: () {
              setState(() {
                _error = null;
                _outcomeStatus = null;
                _phase = 0;
                _selectedIslandKeys.clear();
                _createdIslandKeys.clear();
                _confirming = false;
              });
              _startAnalysis();
            },
            leading: const Icon(Icons.refresh_rounded),
          ),
          if (_outcomeStatus == 'not_enough') ...[
            const SizedBox(height: AppSpacing.s10),
            TextButton.icon(
              onPressed: () => context.go('/capture'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('去捕一束光'),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildResults() {
    final theme = NightTheme.of(context);
    final islands = (_result!['islands'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (islands.isEmpty) {
      return Center(
        child: XiguangEmptyState(
          title: '暂时没有明显的星座',
          description:
              _result!['message'] as String? ?? '这些光各自散落着，也可以先让它们安静待着。',
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _result!['message'] as String? ?? '发现了一些联系。',
            style: AppText.titleSmall.copyWith(color: theme.foreground),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '先挑一挑想留下的岛，最后再正式加入你的宇宙。',
            style: AppText.body.copyWith(color: theme.foregroundMuted),
          ),
          const SizedBox(height: AppSpacing.s20),
          ...islands.asMap().entries.map(
                (entry) => _buildIslandCard(entry.value, entry.key),
              ),
          _buildConfirmPanel(islands),
        ],
      ),
    );
  }

  Widget _buildIslandCard(Map<String, dynamic> island, int index) {
    final theme = NightTheme.of(context);
    final name = island['name'] as String;
    final key = _islandKey(index, island);
    final selected = _selectedIslandKeys.contains(key);
    final created = _createdIslandKeys.contains(key);
    final fragmentIds = (island['fragment_ids'] as List<dynamic>)
        .map((e) => (e as num).toInt())
        .toList();
    final confidence = island['confidence'] as String? ?? 'medium';

    return XiguangCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.s14),
      selected: selected || created,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(
              width: 42,
              height: 42,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.emotionColor(name),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  created ? Icons.check_rounded : Icons.auto_awesome_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppText.titleSmall.copyWith(color: theme.foreground),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${fragmentIds.length} 束光 · ${_confidenceLabel(confidence)}',
                    style:
                        AppText.caption.copyWith(color: theme.foregroundMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            XiguangChip(
              label: created
                  ? '已加入'
                  : selected
                      ? '待加入'
                      : '已跳过',
              selected: selected || created,
            ),
          ]),
          const SizedBox(height: AppSpacing.s12),
          Text(
            island['description'] as String? ?? '',
            style: AppText.body.copyWith(color: theme.foreground),
          ),
          if (!created) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (selected) {
                      _selectedIslandKeys.remove(key);
                    } else {
                      _selectedIslandKeys.add(key);
                    }
                  });
                },
                icon: Icon(
                  selected
                      ? Icons.remove_circle_outline
                      : Icons.add_circle_outline,
                ),
                label: Text(selected ? '跳过' : '恢复加入'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmPanel(List<Map<String, dynamic>> islands) {
    final theme = NightTheme.of(context);
    final pendingCount = islands.asMap().entries.where((entry) {
      final key = _islandKey(entry.key, entry.value);
      return _selectedIslandKeys.contains(key) &&
          !_createdIslandKeys.contains(key);
    }).length;
    final createdCount = _createdIslandKeys.length;
    final label = pendingCount > 0
        ? '确认加入 $pendingCount 座岛屿'
        : createdCount > 0
            ? '已加入宇宙'
            : '选择岛屿后再确认';

    return XiguangCard(
      margin: const EdgeInsets.only(top: AppSpacing.s2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('最后确认',
            style: AppText.titleSmall.copyWith(color: theme.foreground)),
        const SizedBox(height: AppSpacing.s6),
        Text(
          pendingCount > 0
              ? '确认后，星图管理员才会把选中的岛屿和光片关系写入你的宇宙。'
              : '可以恢复上面的岛屿，再一起加入。',
          style: AppText.bodyMuted.copyWith(color: theme.foregroundMuted),
        ),
        const SizedBox(height: AppSpacing.s14),
        XiguangButton(
          label: _confirming ? '正在加入...' : label,
          loading: _confirming,
          leading: const Icon(Icons.check_rounded),
          onPressed: pendingCount == 0 || _confirming
              ? null
              : () => _confirmSelectedIslands(islands),
        ),
      ]),
    );
  }

  String _islandKey(int index, Map<String, dynamic> island) {
    return '$index:${island['name'] as String? ?? ''}';
  }

  String _confidenceLabel(String confidence) {
    return switch (confidence) {
      'high' => '联系很强',
      'low' => '联系较弱',
      _ => '有些联系',
    };
  }
}

class _AiBuildHeader extends StatelessWidget {
  const _AiBuildHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(
      children: [
        PageBackButton(onTap: onBack),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('星图管理员',
                  style: AppText.titleMedium.copyWith(color: theme.foreground)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '读光片、找联系、给出候选小岛。',
                style: AppText.caption.copyWith(color: theme.foregroundMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
