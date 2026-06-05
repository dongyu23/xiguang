import 'package:flutter/material.dart';

import '../../design/tokens/colors.dart';
import '../../design/tokens/shadows.dart';
import '../../design/tokens/typography.dart';
import 'tag_chip.dart';

/// 光片数据模型（纯展示用，正式开发时用 freezed 的 Fragment）
class LightFragment {
  const LightFragment({
    required this.time, required this.date, required this.title,
    required this.text, required this.emotion, required this.tags,
    required this.color, this.relation,
  });

  final String time;
  final String date;
  final String title;
  final String text;
  final String emotion;
  final List<String> tags;
  final Color color;
  final String? relation;
}

/// 光片卡片 — 时间河流中使用
class LightFragmentCard extends StatelessWidget {
  const LightFragmentCard({super.key, required this.fragment, this.compact = false, this.onTap});

  final LightFragment fragment;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(compact ? 14 : 16),
        decoration: softDecoration(AppColors.white),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧色块
            Container(
              width: compact ? 48 : 58, height: compact ? 48 : 58,
              decoration: BoxDecoration(
                color: fragment.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(
                painter: _CardIconPainter(color: AppColors.white.withValues(alpha: .72)),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(width: 14),
            // 右侧内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(fragment.title, style: AppText.titleSmall)),
                      Text(fragment.time, style: AppText.caption),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(fragment.text, style: AppText.body, maxLines: compact ? 2 : 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: [
                      MiniTag(label: fragment.emotion, filled: true),
                      ...fragment.tags.take(compact ? 2 : 3).map((tag) => MiniTag(label: tag)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 光片卡片左侧装饰图标
class _CardIconPainter extends CustomPainter {
  _CardIconPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2;
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
