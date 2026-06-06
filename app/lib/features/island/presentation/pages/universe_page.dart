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
import '../../../../ui/composites/night_mode_button.dart';
import '../../../../ui/spaces/space_canvas.dart';

/// 小宇宙页 — 主题岛、星点、柔光整理入口
class UniversePage extends ConsumerWidget {
  const UniversePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final islands = ref.watch(islandsProvider);
    final emotionDensity = ref.watch(emotionDensityProvider);
    final freqWords = ref.watch(freqWordsProvider);
    final nightMode = ref.watch(nightModeProvider);
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
                    _Header(nightMode: nightMode),
                    const SizedBox(height: 20),
                    islands.when(
                      data: (items) => _UniverseSkyBanner(
                        topicCount: items.length,
                        wovenHintCount: items
                            .where((item) =>
                                item.status == 'formed' ||
                                item.status == 'growing')
                            .length,
                      ),
                      loading: () => const _UniverseSkyBanner(),
                      error: (_, __) => const _UniverseSkyBanner(),
                    ),
                    const SizedBox(height: 20),
                    _SectionTitle(
                        title: '正在生长的主题',
                        action: '轻轻回看',
                        nightMode: nightMode,
                        onTap: () => context.push('/starmap')),
                    const SizedBox(height: 12),
                    islands.when(
                      data: (items) => _TopicIslandGrid(
                        items: items,
                        nightMode: nightMode,
                      ),
                      loading: () => _TopicIslandGrid(
                        items: const [],
                        nightMode: nightMode,
                      ),
                      error: (_, __) => _TopicIslandGrid(
                        items: const [],
                        nightMode: nightMode,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: nightMode
                          ? _nightPanelDecoration()
                          : softDecoration(AppColors.white),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('近期微光',
                              style: AppText.onNight(
                                  AppText.titleMedium, nightMode)),
                          const SizedBox(height: 12),
                          freqWords.when(
                            data: (result) => result.words.isEmpty
                                ? Text('高频主题会在这里慢慢浮现。',
                                    style: AppText.onNight(
                                        AppText.caption, nightMode))
                                : FreqWordsCloud(
                                    words: result.words
                                        .take(8)
                                        .map((word) =>
                                            '${word.text} · ${word.count}')
                                        .toList(),
                                  ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) => Text('高频主题暂时不可用。',
                                style: AppText.onNight(
                                    AppText.caption, nightMode)),
                          ),
                          const SizedBox(height: 14),
                          emotionDensity.when(
                            data: (density) => density.emotions.isEmpty
                                ? Text('情绪密度会在留下更多光后出现。',
                                    style: AppText.onNight(
                                        AppText.caption, nightMode))
                                : EmotionDensityChart(
                                    values: {
                                      for (final item
                                          in density.emotions.take(6))
                                        item.name: item.percentage,
                                    },
                                  ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => Text('情绪密度暂时不可用。',
                                style: AppText.onNight(
                                    AppText.caption, nightMode)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SoftAiPanel(nightMode: nightMode),
                  ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PRIVATE SKY', style: AppText.onNight(AppText.eyebrow, nightMode)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: Text('屿', style: AppText.onNight(AppText.hero, nightMode)),
        ),
        TextButton.icon(
          onPressed: () => context.push('/islands/create'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('新建小岛'),
        ),
        const NightModeButton(),
      ]),
      const SizedBox(height: 8),
      Text(
        '标签、情绪和旧光慢慢连成一张只属于你的星图。',
        style: AppText.onNight(AppText.body, nightMode),
      ),
    ]);
  }
}

class _UniverseSkyBanner extends StatelessWidget {
  const _UniverseSkyBanner({this.topicCount = 0, this.wovenHintCount = 0});

  final int topicCount;
  final int wovenHintCount;

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
            right: 20,
            child: Row(children: [
              Expanded(child: Text('近期星图', style: AppText.inverseTitle)),
              _SkyPillButton(
                label: '已织线',
                icon: Icons.timeline_rounded,
                onTap: () => context.push('/starmap'),
              ),
            ])),
        Positioned(
          left: 20,
          top: 58,
          child: Row(children: [
            _SkyMetric(value: '$topicCount', label: '主题星点'),
            const SizedBox(width: 8),
            _SkyMetric(value: '$wovenHintCount', label: '线索靠近'),
          ]),
        ),
        Positioned(
            left: 20,
            bottom: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('反复出现的标签会先变成主题星点，靠近之后会被织成一条线。',
                    style: AppText.inverseBody),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _SkyActionButton(
                      label: '查看已织线',
                      icon: Icons.account_tree_outlined,
                      onTap: () => context.push('/starmap'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SkyActionButton(
                      label: '聊聊星图',
                      icon: Icons.auto_awesome_outlined,
                      onTap: () => context.push('/glow-organize'),
                    ),
                  ),
                ]),
              ],
            )),
      ]),
    );
  }
}

class _SkyMetric extends StatelessWidget {
  const _SkyMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.white.withValues(alpha: .16)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: AppText.inverseBody.copyWith(
              fontWeight: FontWeight.w800,
              height: 1,
            )),
        const SizedBox(width: 5),
        Text(label,
            style: AppText.inverseBody.copyWith(
              fontSize: 11,
              color: AppColors.white.withValues(alpha: .82),
            )),
      ]),
    );
  }
}

class _SkyPillButton extends StatelessWidget {
  const _SkyPillButton(
      {required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: AppColors.ink),
          const SizedBox(width: 5),
          Text(label,
              style: AppText.chip.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              )),
        ]),
      ),
    );
  }
}

class _SkyActionButton extends StatelessWidget {
  const _SkyActionButton(
      {required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.ink,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
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
      Offset(size.width * .18, size.height * .38),
      Offset(size.width * .40, size.height * .28),
      Offset(size.width * .70, size.height * .42),
      Offset(size.width * .34, size.height * .62),
      Offset(size.width * .76, size.height * .72),
      Offset(size.width * .58, size.height * .56),
    ];
    final lp = Paint()
      ..color = AppColors.white.withValues(alpha: .24)
      ..strokeWidth = 1.2;
    final pairs = [
      (0, 1),
      (1, 2),
      (2, 5),
      (5, 3),
      (3, 4),
      (3, 0),
    ];
    for (final pair in pairs) {
      canvas.drawLine(pts[pair.$1], pts[pair.$2], lp);
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
  const _TopicIsland({
    required this.island,
    required this.width,
    required this.nightMode,
    this.onTap,
  });
  final IslandModel island;
  final double width;
  final bool nightMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.emotionColor(island.name);
    final count = island.fragmentCount.clamp(1, 8);
    final statusLabel = _islandStatusLabel(island);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
          width: width,
          padding: const EdgeInsets.all(14),
          decoration: nightMode
              ? _nightPanelDecoration()
              : softDecoration(AppColors.white),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 34 + count * 4,
                  height: 34 + count * 4,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                  child: const Icon(Icons.blur_on_rounded,
                      color: Colors.white, size: 18)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  size: 18,
                  color: nightMode
                      ? AppText.nightInkMuted.withValues(alpha: .72)
                      : AppColors.inkMuted.withValues(alpha: .72)),
            ]),
            const SizedBox(height: 12),
            Text('#${island.name}',
                style: AppText.onNight(AppText.titleSmall, nightMode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 7),
            _TopicStatusPill(status: island.status, nightMode: nightMode),
            const SizedBox(height: 8),
            Text(
              statusLabel,
              style: AppText.onNight(AppText.caption, nightMode),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ])),
    );
  }

  static String _islandStatusLabel(IslandModel island) {
    final count = island.fragmentCount;
    return switch (island.status) {
      'formed' => '$count 条记录已织出线索',
      'growing' => '$count 条记录，线索正在生长',
      _ => '$count 条记录，星点正在靠近',
    };
  }
}

class _TopicIslandGrid extends StatelessWidget {
  const _TopicIslandGrid({required this.items, required this.nightMode});

  final List<IslandModel> items;
  final bool nightMode;

  static const _fallbackItems = [
    IslandModel(
        name: '微光',
        status: 'star_point',
        fragmentCount: 1,
        description: '先有一束光就好。'),
    IslandModel(
        name: '通勤',
        status: 'star_point',
        fragmentCount: 1,
        description: '这个主题星点正在靠近更多旧光。'),
    IslandModel(
        name: '奶茶',
        status: 'star_point',
        fragmentCount: 1,
        description: '这个主题星点正在靠近更多旧光。'),
    IslandModel(
        name: '小小救命',
        status: 'star_point',
        fragmentCount: 1,
        description: '这个主题星点正在靠近更多旧光。'),
  ];

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.isEmpty ? _fallbackItems : items;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: visibleItems
              .map((island) => _TopicIsland(
                    island: island,
                    width: width,
                    nightMode: nightMode,
                    onTap: () => context
                        .push('/islands/${Uri.encodeComponent(island.name)}'),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _TopicStatusPill extends StatelessWidget {
  const _TopicStatusPill({required this.status, required this.nightMode});

  final String status;
  final bool nightMode;

  bool get _isFormed => status == 'formed';
  bool get _isGrowing => status == 'growing';

  @override
  Widget build(BuildContext context) {
    final bool active = _isFormed || _isGrowing;
    final String label;
    final IconData icon;
    if (_isFormed) {
      label = '已织线';
      icon = Icons.account_tree_outlined;
    } else if (_isGrowing) {
      label = '生长中';
      icon = Icons.auto_awesome_outlined;
    } else {
      label = '正在靠近';
      icon = Icons.motion_photos_on_outlined;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: nightMode
            ? (active
                ? AppColors.teaGreen.withValues(alpha: .18)
                : AppColors.white.withValues(alpha: .08))
            : (active
                ? AppColors.teaGreen.withValues(alpha: .14)
                : AppColors.paper.withValues(alpha: .88)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: nightMode
              ? (active
                  ? AppColors.teaGreen.withValues(alpha: .34)
                  : AppColors.white.withValues(alpha: .12))
              : (active
                  ? AppColors.teaGreen.withValues(alpha: .32)
                  : AppColors.line),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          icon,
          size: 13,
          color: active
              ? (nightMode ? AppText.nightAccent : AppColors.teaGreen)
              : (nightMode ? AppText.nightInkMuted : AppColors.inkMuted),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppText.caption.copyWith(
            height: 1,
            fontWeight: FontWeight.w700,
            color: active
                ? (nightMode ? AppText.nightAccent : AppColors.teaGreen)
                : (nightMode ? AppText.nightInkMuted : AppColors.inkMuted),
          ),
        ),
      ]),
    );
  }
}

class _SoftAiPanel extends StatelessWidget {
  const _SoftAiPanel({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/glow-organize'),
      child: Container(
          padding: const EdgeInsets.all(18),
          decoration: nightMode
              ? _nightPanelDecoration()
              : softDecoration(AppColors.white),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              Expanded(
                  child: Text('AI 星图对话',
                      style: AppText.onNight(AppText.titleMedium, nightMode))),
              Icon(Icons.chevron_right_rounded,
                  color:
                      nightMode ? AppText.nightInkMuted : AppColors.inkMuted),
            ]),
            const SizedBox(height: 12),
            Text('可以从这里问：这些线为什么靠近？哪个主题先继续写？我只在你点开时回应。',
                style: AppText.onNight(AppText.body, nightMode)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(
                color: nightMode
                    ? AppColors.white.withValues(alpha: .08)
                    : AppColors.paper.withValues(alpha: .86),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: nightMode
                        ? AppColors.white.withValues(alpha: .12)
                        : AppColors.line),
              ),
              child: Row(children: [
                Expanded(
                  child: Text('聊聊这些已织好的线...',
                      style: AppText.onNight(AppText.placeholder, nightMode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.teaGreen.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      size: 18, color: AppColors.teaGreen),
                ),
              ]),
            ),
          ])),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
      {required this.title,
      required this.action,
      required this.nightMode,
      required this.onTap});
  final String title, action;
  final bool nightMode;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child: Text(title,
              style: AppText.onNight(AppText.titleMedium, nightMode))),
      TextButton(onPressed: onTap, child: Text(action)),
    ]);
  }
}

BoxDecoration _nightPanelDecoration() {
  return BoxDecoration(
    color: const Color(0xFF213433).withValues(alpha: .78),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppColors.white.withValues(alpha: .13)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .16),
        blurRadius: 24,
        offset: const Offset(0, 14),
      ),
    ],
  );
}
