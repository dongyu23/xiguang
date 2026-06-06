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
      this.onTap,
      this.tapKey});

  final LightFragment fragment;
  final bool compact;
  final VoidCallback? onTap;
  final Key? tapKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nightMode = ref.watch(nightModeProvider);
    return Semantics(
      key: tapKey,
      button: onTap != null,
      label: fragment.title,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: compact ? 9 : 12),
          padding: EdgeInsets.all(compact ? 10 : 16),
          decoration: nightMode
              ? _nightCardDecoration()
              : softDecoration(AppColors.white),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧色块
              _MediaThumb(
                urls: fragment.mediaUrls,
                color: fragment.color,
                size: compact ? 42 : 58,
              ),
              SizedBox(width: compact ? 10 : 14),
              // 右侧内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(fragment.title,
                                style: AppText.onNight(
                                    AppText.titleSmall, nightMode))),
                        Text(fragment.time,
                            style: AppText.onNight(AppText.caption, nightMode)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(fragment.text,
                        style: AppText.onNight(AppText.body, nightMode),
                        maxLines: compact ? 1 : 3,
                        overflow: TextOverflow.ellipsis),
                    if (!compact) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          MiniTag(
                              label: fragment.emotion,
                              filled: true,
                              nightMode: nightMode),
                          ...fragment.tags.take(3).map((tag) => MiniTag(
                                label: tag,
                                nightMode: nightMode,
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

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({
    required this.urls,
    required this.color,
    required this.size,
  });

  final List<String> urls;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final first = urls.where((url) => url.trim().isNotEmpty).firstOrNull;
    final hasAudio = urls.any((url) => url.startsWith('audio-cue://'));
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: hasAudio && (first == null || first.startsWith('audio-cue://'))
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
