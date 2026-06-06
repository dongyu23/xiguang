import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../data/fragment_repository.dart';
import 'fragment_detail_page.dart';
import '../../../../ui/composites/emotion_picker.dart';
import '../../../../ui/composites/light_card.dart';
import '../../../../ui/spaces/space_canvas.dart';

/// 捕光页 — 首页，快速记录入口
///
/// "今天有什么光落下来吗？"
class CapturePage extends ConsumerWidget {
  const CapturePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fragments = ref.watch(fragmentsProvider);
    return _XiguangPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeader(
            label: 'GAP OF LIGHT',
            title: '隙',
            subtitle: '不用解释，也不用整理。先把这一束光轻轻放下。',
          ),
          const SizedBox(height: 22),
          const _BreathingLightBanner(),
          const SizedBox(height: 18),
          const _QuickRecordComposer(),
          const SizedBox(height: 22),
          _SectionTitle(
            title: '刚刚留下的光',
            action: fragments.when(
                data: (items) => '${items.length} 束光',
                loading: () => '读取中',
                error: (_, __) => '本地光片'),
            onTap: () => ref.read(fragmentsProvider.notifier).refresh(),
          ),
          const SizedBox(height: 12),
          fragments.when(
            data: (items) => Column(
                children: items
                    .take(3)
                    .map((f) => LightFragmentCard(
                          fragment: f.toLightFragment(),
                          compact: true,
                          onTap: () =>
                              Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              builder: (_) => FragmentDetailPage(id: '${f.id}'),
                            ),
                          ),
                        ))
                    .toList()),
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator())),
            error: (error, _) =>
                Text('这束光先留在本地：$error', style: AppText.caption),
          ),
        ],
      ),
    );
  }
}

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
  const _PageHeader(
      {required this.label, required this.title, required this.subtitle});

  final String label, title, subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppText.eyebrow),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text(title, style: AppText.hero)),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: .86),
              shape: BoxShape.circle),
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
      decoration: softDecoration(AppColors.ink)
          .copyWith(gradient: AppColors.gradientDusk),
      child: Stack(children: [
        const Positioned.fill(child: _CalmWavePainterWidget()),
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
                      color: AppColors.white.withValues(alpha: .44),
                      width: 1.2)),
              child: Center(
                  child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.white.withValues(alpha: .7)))),
            )),
        Positioned(
            left: 20,
            right: 150,
            bottom: 22,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
    return CustomPaint(
        painter: _CalmWavePainter(), child: const SizedBox.expand());
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

class _QuickRecordComposer extends ConsumerStatefulWidget {
  const _QuickRecordComposer();
  @override
  ConsumerState<_QuickRecordComposer> createState() =>
      _QuickRecordComposerState();
}

class _QuickRecordComposerState extends ConsumerState<_QuickRecordComposer> {
  final _controller = TextEditingController();
  final _tagController = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  String _emotion = '说不清';
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softDecoration(AppColors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('把这一瞬间放在这里', style: AppText.titleMedium)),
          IconButton.filled(
            style: IconButton.styleFrom(
                backgroundColor: AppColors.teaGreen,
                foregroundColor: Colors.white),
            tooltip: '添加图片',
            onPressed: _saving ? null : _pickImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(minHeight: 106),
          decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line)),
          child: TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '今天发生了什么？可以只写一句，也可以什么都不解释。',
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 14),
        EmotionPicker(
            selected: _emotion,
            onSelected: (e) => setState(() => _emotion = e)),
        const SizedBox(height: 14),
        TextField(
          controller: _tagController,
          decoration: InputDecoration(
            hintText: '给光命名，用空格分隔，例如：雨天 通勤 微光',
            prefixIcon: const Icon(Icons.tag_rounded),
            filled: true,
            fillColor: AppColors.white.withValues(alpha: .72),
          ),
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final image = _images[index];
                return Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(image.path),
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: IconButton.filledTonal(
                      constraints:
                          const BoxConstraints.tightFor(width: 28, height: 28),
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      onPressed: () => setState(() => _images.removeAt(index)),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.wb_sunny_outlined),
              label: Text(_saving ? '正在捕光' : '捕光'),
            )),
      ]),
    );
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(limit: 6);
      if (picked.isEmpty) return;
      setState(() {
        _images
          ..clear()
          ..addAll(picked.take(6));
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂时无法打开相册。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('至少留下一句话。'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final tags = _tagController.text
        .split(RegExp(r'[\s,，#]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    setState(() => _saving = true);
    await ref.read(fragmentsProvider.notifier).capture(
          text: text,
          emotion: _emotion,
          tags: tags,
          mediaUrls: _images.map((image) => image.path).toList(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    _controller.clear();
    _tagController.clear();
    _images.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('这束光已经放好了。'), behavior: SnackBarBehavior.floating),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
      {required this.title, required this.action, required this.onTap});
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

extension _LightFragmentAdapter on LightFragmentModel {
  LightFragment toLightFragment() {
    return LightFragment(
      time: time,
      date: dateLabel,
      title: title,
      text: contentText,
      emotion: emotion,
      tags: tags,
      color: color,
      relation: status,
    );
  }
}
