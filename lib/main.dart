import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() {
  runApp(const XiguangApp());
}

class XiguangApp extends StatelessWidget {
  const XiguangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '隙光',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.teaGreen,
          brightness: Brightness.light,
          surface: AppColors.paper,
        ),
        fontFamily: 'PingFang SC',
      ),
      home: const XiguangHome(),
    );
  }
}

class XiguangHome extends StatefulWidget {
  const XiguangHome({super.key});

  @override
  State<XiguangHome> createState() => _XiguangHomeState();
}

class _XiguangHomeState extends State<XiguangHome> {
  int _index = 0;

  final List<LightFragment> _fragments = [
    LightFragment(
      time: '23:48',
      date: '今天',
      title: '雨声把窗台变得很近',
      text: '本来只是想睡前看一眼窗外，结果突然觉得今天没有那么糟。',
      emotion: '松了一口气',
      tags: ['雨天', '失眠', '微光'],
      color: AppColors.mistBlue,
      relation: '想起了它',
    ),
    LightFragment(
      time: '18:16',
      date: '今天',
      title: '一杯青提茶',
      text: '冰块、杯壁上的水珠、路边很亮的橱窗。好像被小小地接住了一下。',
      emotion: '被安放',
      tags: ['通勤', '奶茶', '小小救命'],
      color: AppColors.teaGreen,
      relation: '情绪延续',
    ),
    LightFragment(
      time: '01:22',
      date: '昨天',
      title: '凌晨突然想到的片名',
      text: '如果把这段时间剪成一支短片，名字也许叫：慢慢亮起来的房间。',
      emotion: '有一点期待',
      tags: ['灵感', '电影', '种子'],
      color: AppColors.sunsetCoral,
      relation: '灵感来源',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      CapturePage(fragments: _fragments),
      TimelinePage(fragments: _fragments),
      UniversePage(fragments: _fragments),
      const MinePage(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AtmosphereBackground()),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: pages[_index],
            ),
          ),
        ],
      ),
      bottomNavigationBar: XiguangNavBar(
        selectedIndex: _index,
        onTap: (value) => setState(() => _index = value),
      ),
    );
  }
}

class CapturePage extends StatelessWidget {
  const CapturePage({super.key, required this.fragments});

  final List<LightFragment> fragments;

  @override
  Widget build(BuildContext context) {
    return XiguangPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            label: 'CAPTURE LIGHT',
            title: '写下此刻',
            subtitle: '不用解释，也不用整理。先把这一束光轻轻放下。',
          ),
          const SizedBox(height: 22),
          const BreathingLightCard(),
          const SizedBox(height: 18),
          const QuickRecordComposer(),
          const SizedBox(height: 22),
          SectionTitle(
            title: '刚刚留下的光',
            action: '3 条',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          ...fragments.take(2).map((fragment) => LightFragmentCard(
                fragment: fragment,
                compact: true,
              )),
        ],
      ),
    );
  }
}

class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key, required this.fragments});

  final List<LightFragment> fragments;

  @override
  Widget build(BuildContext context) {
    return XiguangPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            label: 'TIME RIVER',
            title: '时间线',
            subtitle: '这些碎片不用被整理成答案，它们先按时间流动。',
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                MoodChip(label: '全部', selected: true),
                MoodChip(label: '雨天'),
                MoodChip(label: '灵感'),
                MoodChip(label: '奶茶'),
                MoodChip(label: '失眠'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const DateRail(label: '今天', count: '2 束光'),
          ...fragments.where((item) => item.date == '今天').map(
                (fragment) => LightFragmentCard(fragment: fragment),
              ),
          const SizedBox(height: 8),
          const DateRail(label: '昨天', count: '1 束光'),
          ...fragments.where((item) => item.date == '昨天').map(
                (fragment) => LightFragmentCard(fragment: fragment),
              ),
        ],
      ),
    );
  }
}

class UniversePage extends StatelessWidget {
  const UniversePage({super.key, required this.fragments});

  final List<LightFragment> fragments;

  @override
  Widget build(BuildContext context) {
    return XiguangPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            label: 'PRIVATE SKY',
            title: '小宇宙',
            subtitle: '标签、情绪和旧光慢慢连成一张只属于你的星图。',
          ),
          const SizedBox(height: 20),
          UniverseSky(fragments: fragments),
          const SizedBox(height: 20),
          SectionTitle(title: '正在生长的主题', action: '轻轻回看', onTap: () {}),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TopicIsland(title: '失眠微光', count: 5, color: AppColors.mistBlue),
              TopicIsland(title: '通勤小岛', count: 3, color: AppColors.teaGreen),
              TopicIsland(
                  title: '创作种子', count: 4, color: AppColors.sunsetCoral),
              TopicIsland(title: '雨天回声', count: 2, color: AppColors.lilac),
            ],
          ),
          const SizedBox(height: 20),
          const SoftAiPanel(),
        ],
      ),
    );
  }
}

class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return XiguangPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            label: 'MY SPACE',
            title: '我的',
            subtitle: '这个空间默认只属于你。AI 只有在你邀请时才会出现。',
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: softDecoration(AppColors.white, radius: 8),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.teaGreen,
                    shape: BoxShape.circle,
                    boxShadow: softShadow,
                  ),
                  child: const Icon(Icons.wb_twilight_rounded,
                      color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('今晚也慢慢来', style: AppText.titleMedium),
                      const SizedBox(height: 6),
                      Text('已保存 18 束光 · 4 条织线', style: AppText.bodyMuted),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: '隐私模式',
            subtitle: '所有内容默认仅自己可见',
            trailing: '已开启',
          ),
          const SettingsTile(
            icon: Icons.auto_awesome_outlined,
            title: 'AI 柔光建议',
            subtitle: '只在你主动选择记录后整理',
            trailing: '克制',
          ),
          const SettingsTile(
            icon: Icons.inventory_2_outlined,
            title: '数据管理',
            subtitle: '导出、删除或查看保存状态',
            trailing: '',
          ),
          const SettingsTile(
            icon: Icons.info_outline_rounded,
            title: '关于隙光',
            subtitle: '轻记录 × 私人时间线 × 柔软连接',
            trailing: '',
          ),
        ],
      ),
    );
  }
}

class XiguangPage extends StatelessWidget {
  const XiguangPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 520 ? 34.0 : 22.0;
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
              horizontalPadding, 18, horizontalPadding, 104),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.label,
    required this.title,
    required this.subtitle,
  });

  final String label;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.eyebrow),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text(title, style: AppText.hero)),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: .86),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.nights_stay_outlined, color: AppColors.ink),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: AppText.body),
      ],
    );
  }
}

class BreathingLightCard extends StatelessWidget {
  const BreathingLightCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: softDecoration(AppColors.ink, radius: 8).copyWith(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF213A3B), Color(0xFF7DAE99), Color(0xFFFFD4A8)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CalmWaveField()),
          Positioned(
            right: 28,
            top: 34,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white.withValues(alpha: .18),
                border: Border.all(
                    color: AppColors.white.withValues(alpha: .44), width: 1.2),
              ),
              child: Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white.withValues(alpha: .7),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 150,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('这一束光，已经落进你的宇宙。', style: AppText.inverseTitle),
                const SizedBox(height: 8),
                Text('今晚的节律：缓慢、轻、没有任务。', style: AppText.inverseBody),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuickRecordComposer extends StatelessWidget {
  const QuickRecordComposer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softDecoration(AppColors.white, radius: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('把这一瞬间放在这里', style: AppText.titleMedium),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.teaGreen,
                  foregroundColor: Colors.white,
                ),
                tooltip: '添加图片',
                onPressed: () {},
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(minHeight: 106),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              '今天发生了什么？可以只写一句，也可以什么都不解释。',
              style: AppText.placeholder,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MoodChip(label: '松了一口气', selected: true),
              MoodChip(label: '有点累'),
              MoodChip(label: '被安放'),
              MoodChip(label: '+ 标签'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {},
              icon: const Icon(Icons.wb_sunny_outlined),
              label: const Text('保存这一束光'),
            ),
          ),
        ],
      ),
    );
  }
}

class LightFragmentCard extends StatelessWidget {
  const LightFragmentCard({
    super.key,
    required this.fragment,
    this.compact = false,
  });

  final LightFragment fragment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: softDecoration(AppColors.white, radius: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 48 : 58,
            height: compact ? 48 : 58,
            decoration: BoxDecoration(
              color: fragment.color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomPaint(
              painter: CupLabelPainter(
                  color: AppColors.white.withValues(alpha: .72)),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(fragment.title, style: AppText.titleSmall)),
                    Text(fragment.time, style: AppText.caption),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  fragment.text,
                  style: AppText.body,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    MiniTag(label: fragment.emotion, filled: true),
                    ...fragment.tags
                        .take(compact ? 2 : 3)
                        .map((tag) => MiniTag(label: tag)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UniverseSky extends StatelessWidget {
  const UniverseSky({super.key, required this.fragments});

  final List<LightFragment> fragments;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 286,
      decoration: softDecoration(AppColors.ink, radius: 8).copyWith(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF203437), Color(0xFF496F67), Color(0xFFF1CDA5)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: StarMapPainterWidget()),
          Positioned(
            left: 20,
            top: 18,
            child: Text('近期星图', style: AppText.inverseTitle),
          ),
          Positioned(
            left: 20,
            bottom: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'AI 发现：${fragments.length} 束光里，雨天、通勤和被安放的情绪正在靠近。',
                    style: AppText.inverseBody,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.ink,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {},
                  child: const Text('柔光整理'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TopicIsland extends StatelessWidget {
  const TopicIsland({
    super.key,
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 154,
      padding: const EdgeInsets.all(14),
      decoration: softDecoration(AppColors.white, radius: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34 + count * 4,
            height: 34 + count * 4,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.blur_on_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(height: 14),
          Text(title, style: AppText.titleSmall),
          const SizedBox(height: 4),
          Text('$count 条记录正在靠近', style: AppText.caption),
        ],
      ),
    );
  }
}

class SoftAiPanel extends StatelessWidget {
  const SoftAiPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softDecoration(AppColors.white, radius: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.lilac,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_outlined,
                    color: AppColors.ink),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('AI 星图管理员', style: AppText.titleMedium)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '这几条记录里，似乎都有一种疲惫之后被微小事物接住的感觉。你不用急着让自己变好。',
            style: AppText.body,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MoodChip(label: '轻轻命名', selected: true),
              MoodChip(label: '帮我织线'),
              MoodChip(label: '不解释我'),
            ],
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppText.titleMedium)),
        TextButton(
          onPressed: onTap,
          child: Text(action),
        ),
      ],
    );
  }
}

class DateRail extends StatelessWidget {
  const DateRail({super.key, required this.label, required this.count});

  final String label;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.teaGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: AppText.titleSmall),
          const SizedBox(width: 8),
          Text(count, style: AppText.caption),
        ],
      ),
    );
  }
}

class MoodChip extends StatelessWidget {
  const MoodChip({super.key, required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.teaGreen
            : AppColors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: selected ? AppColors.teaGreen : AppColors.line),
      ),
      child: Text(
        label,
        style: AppText.chip
            .copyWith(color: selected ? Colors.white : AppColors.ink),
      ),
    );
  }
}

class MiniTag extends StatelessWidget {
  const MiniTag({super.key, required this.label, this.filled = false});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? AppColors.ink : AppColors.paper,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          color: filled ? Colors.white : AppColors.inkMuted,
        ),
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: softDecoration(AppColors.white, radius: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.titleSmall),
                const SizedBox(height: 4),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          if (trailing.isNotEmpty) Text(trailing, style: AppText.caption),
        ],
      ),
    );
  }
}

class XiguangNavBar extends StatelessWidget {
  const XiguangNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.edit_note_rounded, '记录'),
      (Icons.timeline_rounded, '时间线'),
      (Icons.blur_circular_rounded, '小宇宙'),
      (Icons.person_outline_rounded, '我的'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(8),
        boxShadow: softShadow,
        border: Border.all(color: AppColors.line),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (index) {
            final selected = selectedIndex == index;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.teaGreen.withValues(alpha: .16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[index].$1,
                        size: 22,
                        color:
                            selected ? AppColors.teaGreen : AppColors.inkMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[index].$2,
                        style: AppText.nav.copyWith(
                          color: selected ? AppColors.ink : AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class AtmosphereBackground extends StatelessWidget {
  const AtmosphereBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: AtmospherePainter(),
      child: const SizedBox.expand(),
    );
  }
}

class CalmWaveField extends StatelessWidget {
  const CalmWaveField({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CalmWavePainter(),
      child: const SizedBox.expand(),
    );
  }
}

class StarMapPainterWidget extends StatelessWidget {
  const StarMapPainterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: StarMapPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class AtmospherePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.paper, Color(0xFFE8F1EC), Color(0xFFF8ECE1)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);

    final linePaint = Paint()
      ..color = AppColors.teaGreen.withValues(alpha: .08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < 6; i++) {
      final y = size.height * (.12 + i * .12);
      final path = Path()..moveTo(-20, y);
      for (var x = -20.0; x <= size.width + 20; x += 32) {
        path.lineTo(x, y + math.sin((x / 38) + i) * 8);
      }
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CalmWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (var i = 0; i < 9; i++) {
      final path = Path();
      final y = 38.0 + i * 18;
      path.moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 18) {
        path.lineTo(x, y + math.sin(x / 28 + i * .6) * 5);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CupLabelPainter extends CustomPainter {
  CupLabelPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.shortestSide * .24, paint);
    canvas.drawLine(
      Offset(size.width * .22, size.height * .72),
      Offset(size.width * .78, size.height * .28),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CupLabelPainter oldDelegate) =>
      oldDelegate.color != color;
}

class StarMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(size.width * .18, size.height * .34),
      Offset(size.width * .44, size.height * .22),
      Offset(size.width * .68, size.height * .38),
      Offset(size.width * .36, size.height * .56),
      Offset(size.width * .72, size.height * .66),
    ];

    final linePaint = Paint()
      ..color = AppColors.white.withValues(alpha: .24)
      ..strokeWidth = 1.2;
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }

    final glowPaint = Paint()..color = AppColors.white.withValues(alpha: .22);
    final starPaint = Paint()..color = AppColors.white.withValues(alpha: .86);
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 18 + i * 2, glowPaint);
      canvas.drawCircle(points[i], 5 + i.toDouble(), starPaint);
    }

    final texturePaint = Paint()
      ..color = AppColors.white.withValues(alpha: .12);
    for (var i = 0; i < 22; i++) {
      final x = (i * 37 % size.width).toDouble();
      final y = (i * 53 % size.height).toDouble();
      canvas.drawCircle(Offset(x, y), i.isEven ? 1.4 : 2.1, texturePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LightFragment {
  const LightFragment({
    required this.time,
    required this.date,
    required this.title,
    required this.text,
    required this.emotion,
    required this.tags,
    required this.color,
    required this.relation,
  });

  final String time;
  final String date;
  final String title;
  final String text;
  final String emotion;
  final List<String> tags;
  final Color color;
  final String relation;
}

BoxDecoration softDecoration(Color color, {required double radius}) {
  return BoxDecoration(
    color: color.withValues(alpha: .92),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.line),
    boxShadow: softShadow,
  );
}

final softShadow = [
  BoxShadow(
    color: const Color(0xFF23413F).withValues(alpha: .08),
    blurRadius: 28,
    offset: const Offset(0, 16),
  ),
];

class AppColors {
  static const paper = Color(0xFFF6F3EC);
  static const white = Color(0xFFFFFCF6);
  static const ink = Color(0xFF233332);
  static const inkMuted = Color(0xFF78827D);
  static const line = Color(0xFFE4DDD0);
  static const teaGreen = Color(0xFF72A58F);
  static const mistBlue = Color(0xFF9EBBCC);
  static const sunsetCoral = Color(0xFFE9A18B);
  static const lilac = Color(0xFFD9CCE8);
}

class AppText {
  static const eyebrow = TextStyle(
    fontSize: 11,
    height: 1.1,
    fontWeight: FontWeight.w700,
    color: AppColors.teaGreen,
    letterSpacing: 0,
  );

  static const hero = TextStyle(
    fontSize: 34,
    height: 1.08,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    letterSpacing: 0,
  );

  static const titleMedium = TextStyle(
    fontSize: 18,
    height: 1.22,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: 0,
  );

  static const titleSmall = TextStyle(
    fontSize: 15,
    height: 1.28,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: 0,
  );

  static const body = TextStyle(
    fontSize: 14,
    height: 1.58,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
    letterSpacing: 0,
  );

  static const bodyMuted = TextStyle(
    fontSize: 13,
    height: 1.45,
    color: AppColors.inkMuted,
    letterSpacing: 0,
  );

  static const placeholder = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: AppColors.inkMuted,
    letterSpacing: 0,
  );

  static const caption = TextStyle(
    fontSize: 12,
    height: 1.32,
    color: AppColors.inkMuted,
    letterSpacing: 0,
  );

  static const chip = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const nav = TextStyle(
    fontSize: 11,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static const inverseTitle = TextStyle(
    fontSize: 20,
    height: 1.22,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 0,
  );

  static const inverseBody = TextStyle(
    fontSize: 13,
    height: 1.5,
    color: Colors.white,
    letterSpacing: 0,
  );
}
