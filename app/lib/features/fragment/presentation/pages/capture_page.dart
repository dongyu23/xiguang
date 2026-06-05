import 'package:flutter/material.dart';

import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/emotion_picker.dart';
import '../../../../ui/composites/light_card.dart';
import '../../../../ui/composites/tag_chip.dart';
import '../../../../ui/spaces/space_canvas.dart';

/// 捕光页 — 首页，快速记录入口
///
/// "今天有什么光落下来吗？"
class CapturePage extends StatelessWidget {
  const CapturePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _XiguangPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeader(
            label: 'CAPTURE LIGHT',
            title: '捕光',
            subtitle: '不用解释，也不用整理。先把这一束光轻轻放下。',
          ),
          const SizedBox(height: 22),
          const _BreathingLightBanner(),
          const SizedBox(height: 18),
          const _QuickRecordComposer(),
          const SizedBox(height: 22),
          _SectionTitle(title: '刚刚留下的光', action: '${_mockFragments.length} 束光', onTap: () {}),
          const SizedBox(height: 12),
          ..._mockFragments.take(2).map((f) => LightFragmentCard(fragment: f, compact: true)),
        ],
      ),
    );
  }
}

// --- Mock data (remove when backend is integrated) ---
final _mockFragments = [
  LightFragment(time: '23:48', date: '今天', title: '雨声把窗台变得很近',
    text: '本来只是想睡前看一眼窗外，结果突然觉得今天没有那么糟。',
    emotion: '松了一口气', tags: ['雨天', '失眠', '微光'], color: AppColors.mistBlue, relation: '想起了它'),
  LightFragment(time: '18:16', date: '今天', title: '一杯青提茶',
    text: '冰块、杯壁上的水珠、路边很亮的橱窗。好像被小小地接住了一下。',
    emotion: '被安放', tags: ['通勤', '奶茶', '小小救命'], color: AppColors.teaGreen, relation: '情绪延续'),
  LightFragment(time: '01:22', date: '昨天', title: '凌晨突然想到的片名',
    text: '如果把这段时间剪成一支短片，名字也许叫：慢慢亮起来的房间。',
    emotion: '有一点期待', tags: ['灵感', '电影', '种子'], color: AppColors.sunsetCoral, relation: '灵感来源'),
];

// --- Shared widgets (moved from original main.dart) ---

class _XiguangPage extends StatelessWidget {
  const _XiguangPage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final hp = constraints.maxWidth > 520 ? 34.0 : 22.0;
      return Stack(children: [
        const Positioned.fill(child: AtmosphereBackground()),
        SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hp, 18, hp, 104),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.label, required this.title, required this.subtitle});

  final String label, title, subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppText.eyebrow),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text(title, style: AppText.hero)),
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: AppColors.white.withValues(alpha: .86), shape: BoxShape.circle),
          child: const Icon(Icons.nights_stay_outlined, color: AppColors.ink),
        ),
      ]),
      const SizedBox(height: 8),
      Text(subtitle, style: AppText.body),
    ]);
  }
}

class _BreathingLightBanner extends StatelessWidget {
  const _BreathingLightBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: softDecoration(AppColors.ink).copyWith(gradient: AppColors.gradientDusk),
      child: Stack(children: [
        const Positioned.fill(child: _CalmWavePainterWidget()),
        Positioned(right: 28, top: 34,
          child: Container(width: 112, height: 112,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: AppColors.white.withValues(alpha: .18),
              border: Border.all(color: AppColors.white.withValues(alpha: .44), width: 1.2)),
            child: Center(child: Container(width: 58, height: 58,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.white.withValues(alpha: .7)))),
          )),
        Positioned(left: 20, right: 150, bottom: 22,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('这一束光，已经落进你的宇宙。', style: AppText.inverseTitle),
            const SizedBox(height: 8),
            Text('今晚的节律：缓慢、轻、没有任务。', style: AppText.inverseBody),
          ])),
      ]),
    );
  }
}

class _CalmWavePainterWidget extends StatelessWidget {
  const _CalmWavePainterWidget();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CalmWavePainter(), child: const SizedBox.expand());
  }
}

class _CalmWavePainter extends CustomPainter {
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
        path.lineTo(x, y + sin(x / 28 + i * .6) * 5);
      }
      canvas.drawPath(path, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _QuickRecordComposer extends StatefulWidget {
  const _QuickRecordComposer();
  @override
  State<_QuickRecordComposer> createState() => _QuickRecordComposerState();
}

class _QuickRecordComposerState extends State<_QuickRecordComposer> {
  String? _emotion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softDecoration(AppColors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('把这一瞬间放在这里', style: AppText.titleMedium)),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: AppColors.teaGreen, foregroundColor: Colors.white),
            tooltip: '添加图片', onPressed: () {},
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(minHeight: 106),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.line)),
          child: Text('今天发生了什么？可以只写一句，也可以什么都不解释。', style: AppText.placeholder),
        ),
        const SizedBox(height: 14),
        EmotionPicker(selected: _emotion, onSelected: (e) => setState(() => _emotion = e)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: () {},
          icon: const Icon(Icons.wb_sunny_outlined),
          label: const Text('保存这一束光'),
        )),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.action, required this.onTap});
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
