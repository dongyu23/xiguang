import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../features/stats/presentation/providers/stats_provider.dart';
import '../../../../features/stats/presentation/widgets/emotion_density_chart.dart';
import '../../../../features/stats/presentation/widgets/freq_words_cloud.dart';
import '../../data/island_repository.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../../../ui/composites/tag_chip.dart';

/// 小宇宙页 — 主题岛、星点、柔光整理入口
class UniversePage extends ConsumerWidget {
  const UniversePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final islands = ref.watch(islandsProvider);
    final emotionDensity = ref.watch(emotionDensityProvider);
    final freqWords = ref.watch(freqWordsProvider);
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 104),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Header(),
                    const SizedBox(height: 20),
                    _UniverseSkyBanner(),
                    const SizedBox(height: 20),
                    _SectionTitle(
                        title: '正在生长的主题',
                        action: '轻轻回看',
                        onTap: () => context.push('/starmap')),
                    const SizedBox(height: 12),
                    islands.when(
                      data: (items) => Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: items.isEmpty
                            ? [
                                _TopicIsland(
                                    island: const IslandModel(
                                        name: '微光',
                                        status: 'star_point',
                                        fragmentCount: 1,
                                        description: '先有一束光就好。'),
                                    onTap: () => context.push(
                                        '/islands/${Uri.encodeComponent('微光')}'))
                              ]
                            : items
                                .map((island) => _TopicIsland(
                                      island: island,
                                      onTap: () => context.push(
                                          '/islands/${Uri.encodeComponent(island.name)}'),
                                    ))
                                .toList(),
                      ),
                      loading: () => const Center(
                          child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator())),
                      error: (error, _) =>
                          Text('小宇宙暂时只在本地发光：$error', style: AppText.body),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: softDecoration(AppColors.white),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('近期微光', style: AppText.titleMedium),
                          const SizedBox(height: 12),
                          freqWords.when(
                            data: (result) => result.words.isEmpty
                                ? Text('高频主题会在这里慢慢浮现。', style: AppText.caption)
                                : FreqWordsCloud(
                                    words: result.words
                                        .take(8)
                                        .map((word) =>
                                            '${word.text} · ${word.count}')
                                        .toList(),
                                  ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) =>
                                Text('高频主题暂时不可用。', style: AppText.caption),
                          ),
                          const SizedBox(height: 14),
                          emotionDensity.when(
                            data: (density) => density.emotions.isEmpty
                                ? Text('情绪密度会在留下更多光后出现。',
                                    style: AppText.caption)
                                : EmotionDensityChart(
                                    values: {
                                      for (final item
                                          in density.emotions.take(6))
                                        item.name: item.percentage,
                                    },
                                  ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) =>
                                Text('情绪密度暂时不可用。', style: AppText.caption),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SoftAiPanel(),
                  ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PRIVATE SKY', style: AppText.eyebrow),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text('屿', style: AppText.hero)),
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: .86),
                shape: BoxShape.circle),
            child:
                const Icon(Icons.nights_stay_outlined, color: AppColors.ink)),
      ]),
      const SizedBox(height: 8),
      Text('标签、情绪和旧光慢慢连成一张只属于你的星图。', style: AppText.body),
    ]);
  }
}

class _UniverseSkyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 286,
      decoration: softDecoration(AppColors.ink)
          .copyWith(gradient: AppColors.gradientNight),
      child: Stack(children: [
        const Positioned.fill(child: _StarMapPainterWidget()),
        Positioned(
            left: 20,
            top: 18,
            child: Text('近期星图', style: AppText.inverseTitle)),
        Positioned(
            left: 20,
            bottom: 20,
            right: 20,
            child: Row(children: [
              Expanded(
                  child: Text('规则提示：反复出现的标签会先变成主题星点，再慢慢形成小岛。',
                      style: AppText.inverseBody)),
              const SizedBox(width: 12),
              SizedBox(
                width: 86,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.ink,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  onPressed: () => context.push('/glow-organize'),
                  child: const Text('柔光'),
                ),
              ),
            ])),
      ]),
    );
  }
}

class _StarMapPainterWidget extends StatelessWidget {
  const _StarMapPainterWidget();
  @override
  Widget build(_) =>
      CustomPaint(painter: _StarMapPainter(), child: const SizedBox.expand());
}

class _StarMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pts = [
      Offset(size.width * .18, size.height * .34),
      Offset(size.width * .44, size.height * .22),
      Offset(size.width * .68, size.height * .38),
      Offset(size.width * .36, size.height * .56),
      Offset(size.width * .72, size.height * .66)
    ];
    final lp = Paint()
      ..color = AppColors.white.withValues(alpha: .24)
      ..strokeWidth = 1.2;
    for (var i = 0; i < pts.length - 1; i++) {
      canvas.drawLine(pts[i], pts[i + 1], lp);
    }
    final gp = Paint()..color = AppColors.white.withValues(alpha: .22);
    final sp = Paint()..color = AppColors.white.withValues(alpha: .86);
    for (var i = 0; i < pts.length; i++) {
      canvas.drawCircle(pts[i], 18 + i * 2, gp);
      canvas.drawCircle(pts[i], 5 + i.toDouble(), sp);
    }
    final tp = Paint()..color = AppColors.white.withValues(alpha: .12);
    for (var i = 0; i < 22; i++) {
      final x = (i * 37 % size.width).toDouble();
      final y = (i * 53 % size.height).toDouble();
      canvas.drawCircle(Offset(x, y), i.isEven ? 1.4 : 2.1, tp);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _TopicIsland extends StatelessWidget {
  const _TopicIsland({required this.island, this.onTap});
  final IslandModel island;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.emotionColor(island.name);
    final count = island.fragmentCount.clamp(1, 8);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
          width: 154,
          padding: const EdgeInsets.all(14),
          decoration: softDecoration(AppColors.white),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 34 + count * 4,
                height: 34 + count * 4,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(Icons.blur_on_rounded,
                    color: Colors.white, size: 18)),
            const SizedBox(height: 14),
            Text(island.name, style: AppText.titleSmall),
            const SizedBox(height: 4),
            Text('${island.fragmentCount} 条记录正在靠近', style: AppText.caption),
          ])),
    );
  }
}

class _SoftAiPanel extends StatelessWidget {
  const _SoftAiPanel();
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: softDecoration(AppColors.white),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: AppColors.lilac,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.auto_awesome_outlined,
                    color: AppColors.ink)),
            const SizedBox(width: 12),
            Expanded(child: Text('AI 星图管理员', style: AppText.titleMedium)),
          ]),
          const SizedBox(height: 12),
          Text('柔光整理是主动触发的预留能力。现在不会后台解释你，只把可能的入口轻轻放在这里。', style: AppText.body),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            TagChip(label: '轻轻命名', filled: true),
            TagChip(label: '帮我织线'),
            TagChip(label: '不解释我'),
          ]),
        ]));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
      {required this.title, required this.action, required this.onTap});
  final String title, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(title, style: AppText.titleMedium)),
      TextButton(onPressed: onTap, child: Text(action)),
    ]);
  }
}
