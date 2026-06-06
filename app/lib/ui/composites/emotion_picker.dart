import 'package:flutter/material.dart';

import '../../design/tokens/colors.dart';
import '../../design/tokens/typography.dart';

/// 微光情绪选择器 — 柔和色点 + 情绪词
///
/// 可跳过，默认"说不清"。不强制用户选择。
class EmotionPicker extends StatelessWidget {
  const EmotionPicker({
    super.key,
    this.selected,
    this.onSelected,
  });

  final String? selected;
  final ValueChanged<String>? onSelected;

  static const emotions = [
    _Emotion('平静', AppColors.emotionCalm, '内心安静，没有波澜'),
    _Emotion('开心', AppColors.emotionHappy, '有一点点想笑'),
    _Emotion('疲惫', AppColors.emotionTired, '身体或心里有点累'),
    _Emotion('焦虑', AppColors.emotionAnxious, '心悬着，不太安稳'),
    _Emotion('失落', AppColors.emotionLost, '空空的，说不上来'),
    _Emotion('被击中', AppColors.emotionStruck, '被什么触动了'),
    _Emotion('混乱', AppColors.emotionChaos, '一团乱，理不清楚'),
    _Emotion('说不清', AppColors.emotionUnclear, '不一定要说清楚'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('不一定要说清楚，选一个靠近的感觉就好。', style: AppText.caption),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: emotions
              .map((e) => _EmotionChip(
                    emotion: e,
                    isSelected: selected == e.label,
                    onTap: () => onSelected?.call(e.label),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _Emotion {
  const _Emotion(this.label, this.color, this.hint);
  final String label;
  final Color color;
  final String hint;
}

class _EmotionChip extends StatelessWidget {
  const _EmotionChip(
      {required this.emotion, required this.isSelected, required this.onTap});

  final _Emotion emotion;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(emotion.hint),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? emotion.color
              : AppColors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: isSelected ? emotion.color : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: emotion.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(emotion.label,
                style: AppText.chip.copyWith(
                  color: isSelected ? Colors.white : AppColors.ink,
                )),
          ],
        ),
      ),
    );
  }
}
