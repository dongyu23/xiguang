import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../design/tokens/colors.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/shadows.dart';
import '../../design/tokens/typography.dart';
import 'media_image.dart';
import 'tag_chip.dart';

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
class LightFragmentCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final nightMode = ref.watch(nightModeProvider);
    final hasImageAttachment = fragment.mediaUrls.any(_isImageMedia);
    return Semantics(
      key: tapKey,
      button: onTap != null,
      label: fragment.title,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: EdgeInsets.only(bottom: compact ? 9 : (dense ? 8 : 12)),
          padding: EdgeInsets.all(compact ? 10 : (dense ? 11 : 16)),
          decoration: _cardDecoration(
            nightMode: nightMode,
            selected: selected,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode || showSelectionControl) ...[
                _SelectionMark(
                  selected: selected,
                  nightMode: nightMode,
                  onTap: onSelectionTap,
                ),
                SizedBox(width: compact ? 8 : 10),
              ],
              // 左侧色块
              _MediaThumb(
                urls: fragment.mediaUrls,
                color: fragment.color,
                size: compact ? 42 : (dense ? 44 : 58),
                circular: dense,
              ),
              SizedBox(width: compact ? 10 : (dense ? 10 : 14)),
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
                              maxLines: dense ? 2 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.onNight(
                                dense
                                    ? AppText.titleSmall.copyWith(
                                        fontSize: 14,
                                        height: 1.34,
                                      )
                                    : AppText.body,
                                nightMode,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (showAttachmentBadge && hasImageAttachment) ...[
                            _AttachmentBadge(nightMode: nightMode),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            fragment.time,
                            maxLines: 1,
                            style: AppText.onNight(AppText.caption, nightMode),
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
                                  style: AppText.onNight(
                                    AppText.titleSmall,
                                    nightMode,
                                  ))),
                          const SizedBox(width: 10),
                          if (showAttachmentBadge && hasImageAttachment) ...[
                            _AttachmentBadge(nightMode: nightMode),
                            const SizedBox(width: 6),
                          ],
                          Text(fragment.time,
                              maxLines: 1,
                              style:
                                  AppText.onNight(AppText.caption, nightMode)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(fragment.text,
                          style: AppText.onNight(AppText.body, nightMode),
                          maxLines: compact ? 1 : 3,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (!compact) ...[
                      SizedBox(height: dense ? 6 : 10),
                      Wrap(
                        spacing: dense ? 5 : 6,
                        runSpacing: dense ? 5 : 6,
                        children: [
                          MiniTag(
                              label: fragment.emotion,
                              filled: true,
                              nightMode: nightMode,
                              compact: dense),
                          if (_relationLabel(fragment.relation) != null)
                            _RelationBadge(
                              label: _relationLabel(fragment.relation)!,
                              nightMode: nightMode,
                              compact: dense,
                            ),
                          ...fragment.tags.take(3).map((tag) => MiniTag(
                                label: tag,
                                nightMode: nightMode,
                                compact: dense,
                              )),
                        ],
                      ),
                    ],
                    if (compact) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.alt_route_rounded,
                            size: 15, color: AppColors.teaGreen),
                        const SizedBox(width: 5),
                        Text('点开织线',
                            style: AppText.onNight(AppText.caption, nightMode)),
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
    required this.nightMode,
    required this.compact,
  });

  final String label;
  final bool nightMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = nightMode ? AppText.nightAccent : AppColors.teaGreen;
    return Tooltip(
      message: '已织线：$label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 8,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: nightMode ? .16 : .12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: foreground.withValues(alpha: .28)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.blur_circular_rounded,
              size: compact ? 10 : 12, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppText.caption.copyWith(
              fontSize: compact ? 10 : null,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
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
  const _AttachmentBadge({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    final color = nightMode ? AppText.nightInkMuted : AppColors.inkMuted;
    return Tooltip(
      message: '含图片附件',
      child: Container(
        width: 19,
        height: 19,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: nightMode
              ? AppColors.white.withValues(alpha: .08)
              : AppColors.ink.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.attach_file_rounded, size: 12, color: color),
      ),
    );
  }
}

BoxDecoration _cardDecoration({
  required bool nightMode,
  required bool selected,
}) {
  final base =
      nightMode ? _nightCardDecoration() : softDecoration(AppColors.white);
  if (!selected) return base;
  return base.copyWith(
    border: Border.all(
        color: AppColors.teaGreen.withValues(alpha: .72), width: 1.4),
    boxShadow: [
      ...?base.boxShadow,
      BoxShadow(
        color: AppColors.teaGreen.withValues(alpha: nightMode ? .18 : .14),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

BoxDecoration _nightCardDecoration() {
  return BoxDecoration(
    color: const Color(0xFF213433).withValues(alpha: .78),
    borderRadius: BorderRadius.circular(AppRadius.md),
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

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({
    required this.selected,
    required this.nightMode,
    this.onTap,
  });

  final bool selected;
  final bool nightMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: selected ? '取消选择' : '选择',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.teaGreen
                : (nightMode
                    ? AppColors.white.withValues(alpha: .08)
                    : AppColors.paper.withValues(alpha: .88)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppColors.teaGreen
                  : (nightMode
                      ? AppColors.white.withValues(alpha: .16)
                      : AppColors.line),
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, size: 16, color: AppColors.ink)
              : null,
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
        borderRadius: circular ? null : BorderRadius.circular(8),
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
        child: const SizedBox(width: 30, height: 24),
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
