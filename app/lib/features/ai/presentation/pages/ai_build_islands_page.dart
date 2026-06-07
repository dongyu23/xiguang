import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../data/ai_api.dart';

class AiBuildIslandsPage extends ConsumerStatefulWidget {
  const AiBuildIslandsPage({super.key});

  @override
  ConsumerState<AiBuildIslandsPage> createState() => _AiBuildIslandsPageState();
}

class _AiBuildIslandsPageState extends ConsumerState<AiBuildIslandsPage>
    with TickerProviderStateMixin {
  int _phase = 0;
  String? _error;
  String? _outcomeStatus;
  Map<String, dynamic>? _result;
  final _selectedIslandKeys = <String>{};
  final _createdIslandKeys = <String>{};
  bool _confirming = false;
  late final AnimationController _starController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _startAnalysis();
  }

  @override
  void dispose() {
    _starController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    final api = AIApi(ref.read(apiClientProvider));

    final phases = ['正在读你的光片…', '发现了一些隐秘的联系…', '正在给它们取名字…'];
    for (var i = 0; i < phases.length; i++) {
      if (!mounted) return;
      setState(() => _phase = i);
      await Future.delayed(const Duration(seconds: 2));
    }

    try {
      final body = await api.buildIslands();
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
    final repo = ref.read(islandRepositoryProvider);
    final fragmentIds = (island['fragment_ids'] as List<dynamic>)
        .map((e) => (e as num).toInt())
        .toList();

    try {
      final created = await repo.createIsland(
        name,
        island['description'] as String? ?? '',
      );
      if (created.islandId > 0 && fragmentIds.isNotEmpty) {
        await repo.addFragments(created.islandId, fragmentIds);
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
    ref.invalidate(islandsProvider);
    if (!mounted) return;
    setState(() => _confirming = false);
    if (createdCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已把 $createdCount 座岛屿加入你的宇宙。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('星图管理员'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: _result != null
              ? _buildResults()
              : _error != null
                  ? _buildError()
                  : _buildAnalyzing(),
        ),
      ),
    ]);
  }

  Widget _buildAnalyzing() {
    final phases = ['正在读你的光片…', '发现了一些隐秘的联系…', '正在给它们取名字…'];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Animated star field
          SizedBox(
            width: 200,
            height: 200,
            child: AnimatedBuilder(
              animation: Listenable.merge([_starController, _pulseController]),
              builder: (_, __) => CustomPaint(
                  painter: _AnalyzingPainter(
                progress: _starController.value,
                pulse: _pulseController.value,
              )),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            phases[_phase.clamp(0, phases.length - 1)],
            style: AppText.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (_phase + _starController.value) / phases.length,
            color: AppColors.teaGreen,
            backgroundColor: AppColors.teaGreen.withValues(alpha: .12),
          ),
        ]),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome_outlined,
              size: 64, color: AppColors.inkMuted),
          const SizedBox(height: 24),
          Text(_error!, style: AppText.body, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
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
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_outcomeStatus == 'not_enough' ? '重新看看' : '再试一次'),
          ),
          if (_outcomeStatus == 'not_enough') ...[
            const SizedBox(height: 10),
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
    final islands = (_result!['islands'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (islands.isEmpty) {
      return Center(
        child: Text(
          _result!['message'] as String? ?? '这些光各自散落着，暂时没有明显的星座。',
          style: AppText.body,
          textAlign: TextAlign.center,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 104),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _result!['message'] as String? ?? '发现了一些联系。',
                style: AppText.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '先挑一挑想留下的岛，最后再正式加入你的宇宙。',
                style: AppText.body,
              ),
              const SizedBox(height: 20),
              ...islands.asMap().entries.map(
                    (entry) => _buildIslandCard(entry.value, entry.key),
                  ),
              _buildConfirmPanel(islands),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIslandCard(Map<String, dynamic> island, int index) {
    final name = island['name'] as String;
    final key = _islandKey(index, island);
    final selected = _selectedIslandKeys.contains(key);
    final created = _createdIslandKeys.contains(key);
    final fragmentIds = (island['fragment_ids'] as List<dynamic>)
        .map((e) => (e as num).toInt())
        .toList();
    final confidence = island['confidence'] as String? ?? 'medium';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: softDecoration(created
          ? AppColors.teaGreen.withValues(alpha: .08)
          : selected
              ? AppColors.white
              : AppColors.paper),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  created ? Icons.check_rounded : Icons.auto_awesome_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppText.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${fragmentIds.length} 束光 · ${_confidenceLabel(confidence)}',
                    style: AppText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _IslandStatusPill(
              label: created
                  ? '已加入'
                  : selected
                      ? '待加入'
                      : '已跳过',
              selected: selected || created,
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            island['description'] as String? ?? '',
            style: AppText.body,
          ),
          if (!created) ...[
            const SizedBox(height: 8),
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

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(18),
      decoration: softDecoration(AppColors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('最后确认', style: AppText.titleSmall),
        const SizedBox(height: 6),
        Text(
          pendingCount > 0
              ? '确认后，星图管理员才会把选中的岛屿和光片关系写入你的宇宙。'
              : '可以恢复上面的岛屿，再一起加入。',
          style: AppText.bodyMuted,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: pendingCount == 0 || _confirming
                ? null
                : () => _confirmSelectedIslands(islands),
            style: FilledButton.styleFrom(backgroundColor: AppColors.teaGreen),
            icon: _confirming
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_confirming ? '正在加入...' : label),
          ),
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

class _IslandStatusPill extends StatelessWidget {
  const _IslandStatusPill({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.teaGreen : AppColors.inkMuted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? .12 : .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .26)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: AppText.chip.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _AnalyzingPainter extends CustomPainter {
  _AnalyzingPainter({required this.progress, required this.pulse});

  final double progress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rng = Random(42);
    final dotPaint = Paint()..color = AppColors.teaGreen.withValues(alpha: .18);

    // Star particles
    for (var i = 0; i < 30; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist = rng.nextDouble() * min(size.width, size.height) * 0.45;
      final x = center.dx + cos(angle + progress * 2 * pi) * dist;
      final y = center.dy + sin(angle + progress * 2 * pi) * dist;
      final radius = 1.2 + rng.nextDouble() * 2.0 + pulse * 0.6;
      canvas.drawCircle(Offset(x, y), radius, dotPaint);
    }

    // Central glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.teaGreen.withValues(alpha: .22 + pulse * .1),
          AppColors.teaGreen.withValues(alpha: .04),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 60));
    canvas.drawCircle(center, 60, glowPaint);

    // Connecting lines between some particles
    final linePaint = Paint()
      ..color = AppColors.teaGreen.withValues(alpha: .08)
      ..strokeWidth = 0.8;
    for (var i = 0; i < 8; i++) {
      final a1 = rng.nextDouble() * 2 * pi;
      final d1 = rng.nextDouble() * min(size.width, size.height) * 0.4;
      final a2 = rng.nextDouble() * 2 * pi;
      final d2 = rng.nextDouble() * min(size.width, size.height) * 0.4;
      canvas.drawLine(
        Offset(center.dx + cos(a1) * d1, center.dy + sin(a1) * d1),
        Offset(center.dx + cos(a2) * d2, center.dy + sin(a2) * d2),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnalyzingPainter old) =>
      old.progress != progress || old.pulse != pulse;
}
