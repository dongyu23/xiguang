import 'package:flutter/material.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../domain/user_emotion.dart';

class EmotionRow extends StatelessWidget {
  const EmotionRow({
    super.key,
    required this.emotion,
    required this.previewing,
    required this.onPreview,
    required this.onEdit,
    required this.onLongPress,
    this.onDelete,
  });

  final UserEmotion emotion;
  final bool previewing;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onLongPress;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final hasSound = (emotion.soundKey ?? '').isNotEmpty;
    return Opacity(
      opacity: emotion.hidden ? 0.5 : 1.0,
      child: XiguangCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s10,
        ),
        onTap: onEdit,
        onLongPress: onLongPress,
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: emotion.color.withValues(alpha: .30),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: emotion.color, width: 1.2),
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration:
                    BoxDecoration(color: emotion.color, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(emotion.name,
                      style:
                          AppText.titleSmall.copyWith(color: theme.foreground)),
                ]),
                if (emotion.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s2),
                  Text(emotion.description,
                      style: AppText.caption
                          .copyWith(color: theme.foregroundMuted)),
                ],
              ],
            ),
          ),
          // 唱片试听按钮：绑定了声音才显示
          if (hasSound) ...[
            _VinylPreviewButton(
              playing: previewing,
              color: emotion.color,
              onTap: onPreview,
            ),
            const SizedBox(width: AppSpacing.s6),
          ],
          Icon(Icons.edit_outlined, size: 18, color: theme.foregroundMuted),
          if (onDelete != null) ...[
            const SizedBox(width: AppSpacing.s6),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.delete_outline_rounded,
                  size: 18, color: theme.danger),
            ),
          ],
        ]),
      ),
    );
  }
}

/// 小型唱片试听按钮 - 圆形，播放时旋转动画。
class _VinylPreviewButton extends StatelessWidget {
  const _VinylPreviewButton({
    required this.playing,
    required this.color,
    required this.onTap,
  });

  final bool playing;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: .16),
          border: Border.all(color: color.withValues(alpha: .50), width: 1.2),
        ),
        child: Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 18,
          color: color,
        ),
      ),
    );
  }
}
