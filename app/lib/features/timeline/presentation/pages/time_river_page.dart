import 'package:flutter/material.dart';

import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/light_card.dart';
import '../../../../ui/composites/tag_chip.dart';
import '../../../../ui/spaces/space_canvas.dart';

/// 时间河流页 — 按时间自然铺展的光片流
///
/// "这些碎片不用被整理成答案，它们先按时间流动。"
class TimeRiverPage extends StatelessWidget {
  const TimeRiverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _TimeRiverBody();
  }
}

class _TimeRiverBody extends StatelessWidget {
  // TODO: replace mock data with Riverpod provider + API
  static final _fragments = [
    LightFragment(time: '23:48', date: '今天', title: '雨声把窗台变得很近',
      text: '本来只是想睡前看一眼窗外，结果突然觉得今天没有那么糟。',
      emotion: '松了一口气', tags: ['雨天', '失眠', '微光'], color: AppColors.mistBlue),
    LightFragment(time: '18:16', date: '今天', title: '一杯青提茶',
      text: '冰块、杯壁上的水珠、路边很亮的橱窗。好像被小小地接住了一下。',
      emotion: '被安放', tags: ['通勤', '奶茶', '小小救命'], color: AppColors.teaGreen),
    LightFragment(time: '01:22', date: '昨天', title: '凌晨突然想到的片名',
      text: '如果把这段时间剪成一支短片，名字也许叫：慢慢亮起来的房间。',
      emotion: '有一点期待', tags: ['灵感', '电影', '种子'], color: AppColors.sunsetCoral),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 104),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Header(),
                const SizedBox(height: 18),
                // 筛选条
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    TagChip(label: '全部', filled: true),
                    TagChip(label: '雨天'),
                    TagChip(label: '灵感'),
                    TagChip(label: '奶茶'),
                    TagChip(label: '失眠'),
                  ]),
                ),
                const SizedBox(height: 20),
                // 日期分组
                _DateRail(label: '今天', count: '2 束光'),
                ..._fragments.where((f) => f.date == '今天').map((f) => LightFragmentCard(fragment: f)),
                const SizedBox(height: 8),
                _DateRail(label: '昨天', count: '1 束光'),
                ..._fragments.where((f) => f.date == '昨天').map((f) => LightFragmentCard(fragment: f)),
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
      Text('TIME RIVER', style: AppText.eyebrow),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text('时间河', style: AppText.hero)),
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: AppColors.white.withValues(alpha: .86), shape: BoxShape.circle),
          child: const Icon(Icons.nights_stay_outlined, color: AppColors.ink)),
      ]),
      const SizedBox(height: 8),
      Text('这些碎片不用被整理成答案，它们先按时间流动。', style: AppText.body),
    ]);
  }
}

class _DateRail extends StatelessWidget {
  const _DateRail({required this.label, required this.count});
  final String label, count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.teaGreen, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: AppText.titleSmall),
        const SizedBox(width: 8),
        Text(count, style: AppText.caption),
      ]),
    );
  }
}
