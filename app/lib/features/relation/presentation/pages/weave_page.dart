import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../../fragment/data/fragment_repository.dart';
import '../../../relation/domain/relation.dart';
import '../../../starmap/presentation/providers/starmap_provider.dart';
import '../widgets/relation_note_input.dart';
import '../widgets/relation_type_picker.dart';

class WeavePage extends ConsumerStatefulWidget {
  const WeavePage({super.key, required this.sourceId});

  final int sourceId;

  @override
  ConsumerState<WeavePage> createState() => _WeavePageState();
}

class _WeavePageState extends ConsumerState<WeavePage> {
  final _noteController = TextEditingController();
  int? _targetId;
  String _relationType = 'reminds_me';
  bool _isSubmitting = false;
  bool _completed = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fragments = ref.watch(fragmentsProvider);
    final nightMode = ref.watch(nightModeProvider);
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      const Positioned.fill(child: _ThreadMist()),
      Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: fragments.when(
            data: (items) => _buildContent(context, items, nightMode),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('暂时无法展开这些光：$error',
                    style: AppText.onNight(AppText.body, nightMode)),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildContent(
    BuildContext context,
    List<LightFragmentModel> items,
    bool nightMode,
  ) {
    final source =
        items.where((item) => item.id == widget.sourceId).firstOrNull;
    final candidates =
        items.where((item) => item.id != widget.sourceId).toList();

    if (source == null) {
      return _NotFoundState(onBack: () => context.pop());
    }

    final hasSelectedTarget =
        candidates.any((fragment) => fragment.id == _targetId);
    final effectiveTargetId =
        hasSelectedTarget ? _targetId : candidates.firstOrNull?.id;
    final selected =
        candidates.where((item) => item.id == effectiveTargetId).firstOrNull;

    return Stack(children: [
      SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 132),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Header(onBack: () => context.pop(), nightMode: nightMode),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _StepThread(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(
                          icon: Icons.wb_twilight_rounded,
                          label: '当前这束光',
                          nightMode: nightMode,
                        ),
                        const SizedBox(height: 10),
                        _CurrentLightCard(fragment: source),
                        const SizedBox(height: 12),
                        _ExistingRelations(
                          sourceId: source.id,
                          fragments: items,
                        ),
                        const SizedBox(height: 24),
                        _SectionLabel(
                          icon: Icons.blur_circular_rounded,
                          label: '选择另一束光',
                          trailing: _SortPill(),
                          nightMode: nightMode,
                        ),
                        const SizedBox(height: 10),
                        if (candidates.isEmpty)
                          _EmptyCandidatesCard()
                        else
                          ...candidates.map(
                            (fragment) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CandidateLightTile(
                                fragment: fragment,
                                selected: fragment.id == effectiveTargetId,
                                onTap: () =>
                                    setState(() => _targetId = fragment.id),
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        _SectionLabel(
                          icon: Icons.hub_rounded,
                          label: '关系类型',
                          nightMode: nightMode,
                        ),
                        const SizedBox(height: 12),
                        RelationTypePicker(
                          selectedType: _relationType,
                          onSelected: (type) =>
                              setState(() => _relationType = type),
                        ),
                        const SizedBox(height: 24),
                        _SectionLabel(
                          icon: Icons.short_text_rounded,
                          label: '写一句关系说明',
                          suffix: '可选',
                          nightMode: nightMode,
                        ),
                        const SizedBox(height: 10),
                        RelationNoteInput(controller: _noteController),
                      ]),
                ),
              ]),
            ]),
          ),
        ),
      ),
      Positioned(
        left: 22,
        right: 22,
        bottom: 18,
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _SubmitButton(
                  enabled: selected != null && !_isSubmitting,
                  isSubmitting: _isSubmitting,
                  onPressed:
                      selected == null ? null : () => _submit(source, selected),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: _completed
                      ? const Padding(
                          key: ValueKey('weave-complete-toast'),
                          padding: EdgeInsets.only(top: 10),
                          child: _CompleteToast(),
                        )
                      : const SizedBox.shrink(),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Future<void> _submit(
    LightFragmentModel source,
    LightFragmentModel selected,
  ) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _completed = false;
    });
    final relation = await ref.read(fragmentRepositoryProvider).weave(
          sourceFragmentId: source.id,
          targetFragmentId: selected.id,
          relationType: _relationType,
          note: _noteController.text,
        );
    if (!mounted) return;
    ref.invalidate(fragmentRelationsProvider(source.id));
    ref.invalidate(starGraphProvider);
    setState(() {
      _isSubmitting = false;
      _completed = relation != null;
    });
  }
}

class _ExistingRelations extends ConsumerWidget {
  const _ExistingRelations({required this.sourceId, required this.fragments});

  final int sourceId;
  final List<LightFragmentModel> fragments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relations = ref.watch(fragmentRelationsProvider(sourceId));
    final nightMode = ref.watch(nightModeProvider);
    return relations.when(
      data: (items) {
        if (items.isEmpty) {
          return Text('还没有织好的线。',
              style: AppText.onNight(AppText.bodyMuted, nightMode));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('已经织好的线',
                style: AppText.onNight(AppText.caption, nightMode)),
            const SizedBox(height: 8),
            ...items.take(4).map((relation) {
              final other = _otherFragment(relation);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.blur_circular_rounded,
                      size: 16, color: AppColors.teaGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_relationLabel(relation.relationType)} · ${other?.title ?? '另一束光'}',
                      style: AppText.onNight(AppText.bodyMuted, nightMode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => Text('织线暂时无法读取。',
          style: AppText.onNight(AppText.bodyMuted, nightMode)),
    );
  }

  LightFragmentModel? _otherFragment(Relation relation) {
    final otherId = relation.sourceFragmentId == sourceId
        ? relation.targetFragmentId
        : relation.sourceFragmentId;
    return fragments.where((fragment) => fragment.id == otherId).firstOrNull;
  }

  String _relationLabel(String value) {
    return switch (value) {
      'echo' => '回声',
      'foreshadow' => '伏笔',
      'aftershock' => '余震',
      'parallel' => '平行宇宙',
      'lifeline' => '小小救命',
      'tide' => '潮汐',
      'old_light' => '旧光',
      _ => '有点相似',
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.nightMode});

  final VoidCallback onBack;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: AppColors.white.withValues(alpha: .74),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: '返回',
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.inkMuted,
          ),
        ),
      ),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          '织线',
          style: AppText.onNight(
            AppText.hero.copyWith(fontSize: 30),
            nightMode,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '让两束光轻轻靠近。',
          style: AppText.onNight(AppText.bodyMuted, nightMode),
        ),
      ]),
    ]);
  }
}

class _CurrentLightCard extends StatelessWidget {
  const _CurrentLightCard({required this.fragment});

  final LightFragmentModel fragment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _glassDecoration(),
      child: Row(children: [
        _LightGlyph(color: fragment.color, icon: Icons.graphic_eq_rounded),
        const SizedBox(width: 16),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fragment.title, style: AppText.titleSmall),
            const SizedBox(height: 6),
            Text(
              fragment.contentText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.body,
            ),
            const SizedBox(height: 10),
            Text('${fragment.dateLabel} · ${fragment.emotion}',
                style: AppText.bodyMuted),
          ]),
        ),
      ]),
    );
  }
}

class _CandidateLightTile extends StatelessWidget {
  const _CandidateLightTile({
    required this.fragment,
    required this.selected,
    required this.onTap,
  });

  final LightFragmentModel fragment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: selected ? .9 : .66),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected
                ? AppColors.lilac.withValues(alpha: .9)
                : Colors.white.withValues(alpha: .74),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.lilac.withValues(alpha: .3),
                    blurRadius: 20,
                    offset: const Offset(0, 9),
                  ),
                ]
              : null,
        ),
        child: Row(children: [
          _MiniImage(fragment: fragment),
          const SizedBox(width: 13),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                fragment.contentText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(height: 1.42),
              ),
              const SizedBox(height: 7),
              Text('${fragment.dateLabel} · ${fragment.emotion}',
                  style: AppText.bodyMuted),
            ]),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.lilac : Colors.transparent,
              border: Border.all(
                color: selected
                    ? AppColors.lilac
                    : AppColors.inkMuted.withValues(alpha: .35),
                width: 1.4,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded,
                    color: AppColors.white, size: 18)
                : null,
          ),
        ]),
      ),
    );
  }
}

class _MiniImage extends StatelessWidget {
  const _MiniImage({required this.fragment});

  final LightFragmentModel fragment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fragment.color.withValues(alpha: .72),
            AppColors.white.withValues(alpha: .92),
            AppColors.sunsetCoral.withValues(alpha: .34),
          ],
        ),
      ),
      child: CustomPaint(painter: _LightSketchPainter(fragment.color)),
    );
  }
}

class _LightGlyph extends StatelessWidget {
  const _LightGlyph({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .18),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.nightMode,
    this.trailing,
    this.suffix,
  });

  final IconData icon;
  final String label;
  final bool nightMode;
  final Widget? trailing;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.teaGreen),
      const SizedBox(width: 8),
      Text(
        label,
        style: AppText.onNight(
          AppText.titleMedium.copyWith(fontSize: 17),
          nightMode,
        ),
      ),
      if (suffix != null) ...[
        const SizedBox(width: 6),
        Text(suffix!, style: AppText.onNight(AppText.caption, nightMode)),
      ],
      if (trailing != null) ...[
        const Spacer(),
        trailing!,
      ],
    ]);
  }
}

class _SortPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('按时间', style: AppText.caption.copyWith(color: AppColors.ink)),
        const SizedBox(width: 4),
        const Icon(Icons.expand_more_rounded, size: 16, color: AppColors.ink),
      ]),
    );
  }
}

class _StepThread extends StatelessWidget {
  const _StepThread();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 650,
      child: CustomPaint(painter: _StepThreadPainter()),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.enabled,
    required this.isSubmitting,
    required this.onPressed,
  });

  final bool enabled;
  final bool isSubmitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          disabledBackgroundColor: AppColors.inkMuted.withValues(alpha: .34),
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          elevation: 0,
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.auto_awesome_rounded, size: 19),
                const SizedBox(width: 8),
                Text('织好这条线',
                    style: AppText.inverseBody.copyWith(fontSize: 17)),
              ]),
      ),
    );
  }
}

class _CompleteToast extends StatelessWidget {
  const _CompleteToast();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: .8)),
        boxShadow: softShadow,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.teaGreen.withValues(alpha: .18),
          ),
          child: const Icon(Icons.check_rounded,
              size: 16, color: AppColors.teaGreen),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            '这两束光之间，有了一条细细的线。',
            style: AppText.body,
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }
}

class _EmptyCandidatesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _glassDecoration(),
      child: Text('还没有另一束旧光可以连接。先去捕下一束光，线会在这里等你。', style: AppText.body),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('没有找到这束光。', style: AppText.titleMedium),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('返回'),
          ),
        ]),
      ),
    );
  }
}

class _ThreadMist extends StatelessWidget {
  const _ThreadMist();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _ThreadMistPainter()),
    );
  }
}

class _ThreadMistPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: .28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = size.height * (.16 + i * .17);
      final path = Path()..moveTo(-20, y);
      path.cubicTo(
        size.width * .28,
        y - 34,
        size.width * .56,
        y + 32,
        size.width + 24,
        y - 8,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StepThreadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.lilac.withValues(alpha: .58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..moveTo(size.width / 2, 4)
      ..cubicTo(
        -2,
        120,
        size.width + 6,
        250,
        size.width / 2,
        360,
      )
      ..cubicTo(
        -2,
        450,
        size.width + 4,
        550,
        size.width / 2,
        size.height - 6,
      );
    canvas.drawPath(path, linePaint);

    final positions = [0.02, .2, .42, .67, .88];
    for (var i = 0; i < positions.length; i++) {
      final dy = size.height * positions[i];
      final fill = Paint()
        ..color = i.isEven ? AppColors.emotionHappy : AppColors.white
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = AppColors.lilac.withValues(alpha: .72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(Offset(size.width / 2, dy), i.isEven ? 5.2 : 4.4, fill);
      canvas.drawCircle(
          Offset(size.width / 2, dy), i.isEven ? 5.2 : 4.4, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LightSketchPainter extends CustomPainter {
  const _LightSketchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sunPaint = Paint()
      ..color = AppColors.white.withValues(alpha: .7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(size.width * .72, size.height * .28), 10, sunPaint);

    final linePaint = Paint()
      ..color = AppColors.ink.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (.48 + i * .11);
      final path = Path()..moveTo(0, y);
      path.quadraticBezierTo(size.width * .45, y - 10, size.width, y + 2);
      canvas.drawPath(path, linePaint);
    }

    final boatPaint = Paint()
      ..color = color.withValues(alpha: .6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final boat = Path()
      ..moveTo(size.width * .18, size.height * .68)
      ..lineTo(size.width * .45, size.height * .74)
      ..lineTo(size.width * .68, size.height * .66);
    canvas.drawPath(boat, boatPaint);
  }

  @override
  bool shouldRepaint(covariant _LightSketchPainter oldDelegate) =>
      oldDelegate.color != color;
}

BoxDecoration _glassDecoration() {
  return BoxDecoration(
    color: AppColors.white.withValues(alpha: .68),
    borderRadius: BorderRadius.circular(AppRadius.lg),
    border: Border.all(color: Colors.white.withValues(alpha: .72)),
    boxShadow: softShadow,
  );
}
