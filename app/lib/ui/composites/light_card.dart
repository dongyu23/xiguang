import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/colors.dart';
import '../../design/tokens/motion.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/typography.dart';
import '../../design/tokens/spacing.dart';
import 'media_image.dart';
import 'tag_chip.dart';
import 'xiguang_card.dart';

/// 光片数据模型（纯展示用，正式开发时用 freezed 的 Fragment）
class LightFragment {
  const LightFragment({
    required this.time,
    required this.date,
    required this.title,
    required this.text,
    required this.emotion,
    required this.tags,
    required this.color,
    this.relation,
    this.mediaUrls = const [],
  });

  final String time;
  final String date;
  final String title;
  final String text;
  final String emotion;
  final List<String> tags;
  final Color color;
  final String? relation;
  final List<String> mediaUrls;
}

/// 光片卡片 — 时间河流中使用
class LightFragmentCard extends StatefulWidget {
  const LightFragmentCard(
      {super.key,
      required this.fragment,
      this.compact = false,
      this.dense = false,
      this.showTitle = true,
      this.showAttachmentBadge = false,
      this.onTap,
      this.onLongPress,
      this.onSelectionTap,
      this.selected = false,
      this.selectionMode = false,
      this.showSelectionControl = false,
      this.tapKey});

  final LightFragment fragment;
  final bool compact;
  final bool dense;
  final bool showTitle;
  final bool showAttachmentBadge;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectionTap;
  final bool selected;
  final bool selectionMode;
  final bool showSelectionControl;
  final Key? tapKey;

  @override
  State<LightFragmentCard> createState() => _LightFragmentCardState();
}

class _LightFragmentCardState extends State<LightFragmentCard> {
  bool _pressing = false;
  bool _longPressActive = false;

  void _setPressing(bool value) {
    if (_pressing == value || !mounted) return;
    setState(() => _pressing = value);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    HapticFeedback.selectionClick();
    setState(() {
      _pressing = true;
      _longPressActive = true;
    });
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    if (!mounted) return;
    setState(() {
      _pressing = false;
      _longPressActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fragment = widget.fragment;
    final compact = widget.compact;
    final dense = widget.dense;
    final showTitle = widget.showTitle;
    final showAttachmentBadge = widget.showAttachmentBadge;
    final onTap = widget.onTap;
    final onLongPress = widget.onLongPress;
    final onSelectionTap = widget.onSelectionTap;
    final selected = widget.selected;
    final selectionMode = widget.selectionMode;
    final showSelectionControl = widget.showSelectionControl;
    final selectionVisible = selectionMode || showSelectionControl;
    final tapKey = widget.tapKey;
    final theme = NightTheme.of(context);
    final hasImageAttachment = fragment.mediaUrls.any(_isImageMedia);
    final interactionEnabled = onTap != null || onLongPress != null;
    return AnimatedScale(
      key: const ValueKey('light-card-press-scale'),
      scale: _longPressActive
          ? .972
          : _pressing
              ? .988
              : 1,
      duration: _pressing ? AppMotion.quick : AppMotion.normal,
      curve: _pressing ? AppMotion.easeOut : AppMotion.microMovement,
      child: Semantics(
        key: tapKey,
        button: onTap != null,
        label: fragment.title,
        child: XiguangCard(
          margin: EdgeInsets.only(
            bottom: compact
                ? AppSpacing.s9
                : (dense ? AppSpacing.s9 : AppSpacing.s12),
          ),
          padding: EdgeInsets.fromLTRB(
            compact ? AppSpacing.s10 : (dense ? AppSpacing.s12 : AppSpacing.md),
            compact ? AppSpacing.s10 : (dense ? AppSpacing.s12 : AppSpacing.md),
            compact ? AppSpacing.s10 : (dense ? AppSpacing.s12 : AppSpacing.md),
            compact ? AppSpacing.s10 : (dense ? AppSpacing.s11 : AppSpacing.md),
          ),
          selected: selected,
          highlighted: _longPressActive,
          onTap: onTap,
          onLongPress: onLongPress,
          onTapDown: interactionEnabled ? (_) => _setPressing(true) : null,
          onTapUp: interactionEnabled ? (_) => _setPressing(false) : null,
          onTapCancel: interactionEnabled ? () => _setPressing(false) : null,
          onLongPressStart: onLongPress != null ? _handleLongPressStart : null,
          onLongPressEnd: onLongPress != null ? _handleLongPressEnd : null,
          child: Row(
            key: const ValueKey('light-card-content-row'),
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                key: const ValueKey('light-card-selection-slot'),
                duration: AppMotion.normal,
                curve: AppMotion.microMovement,
                width: selectionVisible
                    ? 24 + (compact ? AppSpacing.sm : AppSpacing.s10)
                    : 0,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IgnorePointer(
                      ignoring: !selectionVisible,
                      child: AnimatedOpacity(
                        opacity: selectionVisible ? 1 : 0,
                        duration: AppMotion.quick,
                        curve: AppMotion.easeOut,
                        child: AnimatedScale(
                          scale: selectionVisible ? 1 : .82,
                          duration: AppMotion.normal,
                          curve: AppMotion.easeOut,
                          child: _SelectionMark(
                            selected: selected,
                            onTap: onSelectionTap,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 左侧色块
              KeyedSubtree(
                key: const ValueKey('light-card-media-thumb'),
                child: _MediaThumb(
                  urls: fragment.mediaUrls,
                  color: fragment.color,
                  size: compact ? 42 : (dense ? 42 : 58),
                  circular: dense,
                ),
              ),
              SizedBox(
                width: compact
                    ? AppSpacing.s10
                    : (dense ? AppSpacing.s10 : AppSpacing.s14),
              ),
              // 右侧内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!showTitle)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              fragment.text,
                              maxLines: dense ? 3 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: (dense
                                      ? AppText.bodyStrong
                                          .copyWith(height: 1.42)
                                      : AppText.body)
                                  .copyWith(color: theme.foreground),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s10),
                          if (showAttachmentBadge && hasImageAttachment) ...[
                            const _AttachmentBadge(),
                            const SizedBox(width: AppSpacing.s6),
                          ],
                          Text(
                            fragment.time,
                            maxLines: 1,
                            style: AppText.caption
                                .copyWith(color: theme.foregroundMuted),
                          ),
                        ],
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                              child: Text(fragment.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.titleSmall
                                      .copyWith(color: theme.foreground))),
                          const SizedBox(width: AppSpacing.s10),
                          if (showAttachmentBadge && hasImageAttachment) ...[
                            const _AttachmentBadge(),
                            const SizedBox(width: AppSpacing.s6),
                          ],
                          Text(fragment.time,
                              maxLines: 1,
                              style: AppText.caption
                                  .copyWith(color: theme.foregroundMuted)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(fragment.text,
                          style: AppText.body.copyWith(color: theme.foreground),
                          maxLines: compact ? 1 : 3,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (!compact) ...[
                      SizedBox(height: dense ? AppSpacing.sm : AppSpacing.s10),
                      Wrap(
                        spacing: dense ? AppSpacing.s5 : AppSpacing.s6,
                        runSpacing: dense ? AppSpacing.s5 : AppSpacing.s6,
                        children: [
                          MiniTag(
                              label: fragment.emotion,
                              filled: true,
                              compact: dense),
                          if (_relationLabel(fragment.relation) != null)
                            _RelationBadge(
                              label: _relationLabel(fragment.relation)!,
                              compact: dense,
                            ),
                          ...fragment.tags.take(3).map((tag) => MiniTag(
                                label: tag,
                                compact: dense,
                              )),
                        ],
                      ),
                    ],
                    if (compact) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(children: [
                        Icon(Icons.alt_route_rounded,
                            size: 15, color: theme.accent),
                        const SizedBox(width: AppSpacing.s5),
                        Text('点开织线',
                            style: AppText.caption
                                .copyWith(color: theme.foregroundMuted)),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _relationLabel(String? value) {
  return switch (value) {
    'reminds_me' => '回声',
    'inspiration' => '伏笔',
    'emotion_continue' => '余震',
    'same_phase' => '平行宇宙',
    'cause' => '小小救命',
    'custom' => '旧光',
    'echo' => '回声',
    'foreshadow' => '伏笔',
    'aftershock' => '余震',
    'parallel' => '平行宇宙',
    'lifeline' => '小小救命',
    'old_light' => '旧光',
    _ => null,
  };
}

class _RelationBadge extends StatelessWidget {
  const _RelationBadge({
    required this.label,
    required this.compact,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = NightTheme.of(context).accent;
    return Tooltip(
      message: '已织线：$label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.s7 : AppSpacing.sm,
          vertical: compact ? AppSpacing.s3 : AppSpacing.s5,
        ),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: foreground.withValues(alpha: .28)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.blur_circular_rounded,
              size: compact ? 10 : 12, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: (compact ? AppText.microLabel : AppText.captionStrong)
                .copyWith(color: foreground),
          ),
        ]),
      ),
    );
  }
}

bool _isImageMedia(String value) {
  final media = value.trim().toLowerCase();
  if (media.isEmpty || _isAudioMedia(media)) return false;
  if (media.startsWith('data:image/')) return true;
  if (media.startsWith('users/')) return true;
  if (media.startsWith('http://') || media.startsWith('https://')) return true;
  return media.endsWith('.jpg') ||
      media.endsWith('.jpeg') ||
      media.endsWith('.png') ||
      media.endsWith('.webp') ||
      media.endsWith('.gif');
}

bool _isAudioMedia(String value) {
  final media = value.trim().toLowerCase();
  return media.startsWith('audio-cue://') ||
      media.startsWith('data:audio/') ||
      media.endsWith('.m4a') ||
      media.endsWith('.mp3') ||
      media.endsWith('.wav') ||
      media.endsWith('.aac') ||
      media.endsWith('.ogg') ||
      media.endsWith('.opus');
}

class _AttachmentBadge extends StatelessWidget {
  const _AttachmentBadge();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final color = theme.foregroundMuted;
    return Tooltip(
      message: '含图片附件',
      child: Container(
        width: 19,
        height: 19,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.surface.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(AppRadius.sm - 1),
        ),
        child: Icon(Icons.attach_file_rounded, size: 12, color: color),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({
    required this.selected,
    this.onTap,
  });

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Tooltip(
      message: selected ? '取消选择' : '选择',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color:
                selected ? theme.accent : theme.surface.withValues(alpha: .88),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? theme.accent : theme.border,
            ),
          ),
          child: AnimatedSwitcher(
            duration: AppMotion.quick,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    key: const ValueKey('selected'),
                    size: 16,
                    color: theme.background,
                  )
                : const SizedBox(key: ValueKey('unselected')),
          ),
        ),
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({
    required this.urls,
    required this.color,
    required this.size,
    this.circular = false,
  });

  final List<String> urls;
  final Color color;
  final double size;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final first = urls.where((url) => url.trim().isNotEmpty).firstOrNull;
    final hasAudio = urls.any(_isAudioMedia);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(AppRadius.md),
      ),
      child: hasAudio && (first == null || _isAudioMedia(first))
          ? _AudioThumb(color: color)
          : first == null
              ? _fallback
              : _image(first),
    );
  }

  Widget _image(String url) {
    return MediaImage(source: url, fallback: _fallback);
  }

  Widget get _fallback => CustomPaint(
        painter:
            _CardIconPainter(color: AppColors.white.withValues(alpha: .72)),
        child: const SizedBox.expand(),
      );
}

class _AudioThumb extends StatelessWidget {
  const _AudioThumb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: .28),
      alignment: Alignment.center,
      child: CustomPaint(
        painter: _AudioThumbPainter(),
        child: const SizedBox(width: 30, height: AppSpacing.lg),
      ),
    );
  }
}

class _AudioThumbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final bars = [8.0, 17.0, 12.0, 22.0, 9.0];
    for (var i = 0; i < bars.length; i++) {
      final x = 4.0 + i * 5.5;
      final h = bars[i];
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 光片卡片左侧装饰图标
class _CardIconPainter extends CustomPainter {
  _CardIconPainter({required this.color});
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
  bool shouldRepaint(covariant _CardIconPainter old) => old.color != color;
}
