import 'package:flutter/material.dart';

import '../../design/tokens/colors.dart';
import '../../design/tokens/typography.dart';

/// 微光情绪选择器 — 柔和色点 + 情绪词
///
/// 可跳过，默认"说不清"。不强制用户选择。
class EmotionPicker extends StatefulWidget {
  const EmotionPicker({
    super.key,
    this.selected,
    this.onSelected,
    this.customValue = '',
    this.onCustomChanged,
  });

  final String? selected;
  final ValueChanged<String>? onSelected;
  final String customValue;
  final ValueChanged<String>? onCustomChanged;

  static const emotions = [
    _Emotion('平静', AppColors.emotionCalm, '内心安静，没有波澜'),
    _Emotion('开心', AppColors.emotionHappy, '有一点点想笑'),
    _Emotion('疲惫', AppColors.emotionTired, '身体或心里有点累'),
    _Emotion('焦虑', AppColors.emotionAnxious, '心悬着，不太安稳'),
    _Emotion('失落', AppColors.emotionLost, '空空的，说不上来'),
    _Emotion('被击中', AppColors.emotionStruck, '被什么触动了'),
    _Emotion('混乱', AppColors.emotionChaos, '一团乱，理不清楚'),
    _Emotion('自定义', AppColors.emotionUnclear, '先留一个自己的感觉'),
  ];

  @override
  State<EmotionPicker> createState() => _EmotionPickerState();
}

class _EmotionPickerState extends State<EmotionPicker> {
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(text: widget.customValue);
  }

  @override
  void didUpdateWidget(covariant EmotionPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customValue != widget.customValue &&
        _customController.text != widget.customValue) {
      _customController.text = widget.customValue;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('心绪收录', style: AppText.titleSmall),
          const SizedBox(width: 8),
          Text('轻触一个靠近的感觉', style: AppText.caption),
        ]),
        const SizedBox(height: 12),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: EmotionPicker.emotions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 42),
          itemBuilder: (context, index) {
            final emotion = EmotionPicker.emotions[index];
            return _EmotionChip(
              emotion: emotion,
              isSelected: widget.selected == emotion.label ||
                  (emotion.label == '自定义' &&
                      (widget.selected == null ||
                          widget.selected == '说不清' ||
                          widget.customValue.trim().isNotEmpty)),
              onTap: () => widget.onSelected?.call(emotion.label),
            );
          },
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: widget.selected == '自定义'
              ? Padding(
                  key: const ValueKey('custom-emotion-field'),
                  padding: const EdgeInsets.only(top: 10),
                  child: TextField(
                    controller: _customController,
                    onChanged: widget.onCustomChanged,
                    maxLength: 8,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '写一个自己的感觉',
                      prefixIcon: const Icon(Icons.edit_outlined),
                      filled: true,
                      fillColor: AppColors.white.withValues(alpha: .72),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
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
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? emotion.color
              : AppColors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? emotion.color : AppColors.line,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration:
                  BoxDecoration(color: emotion.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                emotion.label,
                style: AppText.chip.copyWith(
                  color: isSelected ? Colors.white : AppColors.ink,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
