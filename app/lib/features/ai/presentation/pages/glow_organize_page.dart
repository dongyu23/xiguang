import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_state.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../application/glow_organize_controller.dart';
import '../../domain/ai_request.dart';
import '../../domain/ai_response.dart';

class GlowOrganizePage extends ConsumerStatefulWidget {
  const GlowOrganizePage({super.key, this.initialScope});
  final AIScope? initialScope;
  @override
  ConsumerState<GlowOrganizePage> createState() => _GlowOrganizePageState();
}

class _GlowOrganizePageState extends ConsumerState<GlowOrganizePage> {
  late AIScope _scope;
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final List<TextEditingController> _points = [];
  bool _edited = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _scope = widget.initialScope ?? const AIScope.range(7);
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    for (final c in _points) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadDraft(AISummaryDraft draft) {
    _title.text =
        draft.titleCandidates.isEmpty ? '' : draft.titleCandidates.first;
    _summary.text = draft.summary;
    for (final c in _points) {
      c.dispose();
    }
    _points
      ..clear()
      ..addAll(draft.keyPoints.map((p) => TextEditingController(text: p.text)));
    _edited = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final enabled = ref.watch(aiEnabledProvider);
    final async = ref.watch(glowOrganizeControllerProvider);
    final draft = async.valueOrNull;
    return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          const Positioned.fill(child: AtmosphereBackground()),
          SafeArea(
              child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s14, AppSpacing.s6, AppSpacing.s14, 0),
                child: Row(children: [
                  IconButton(
                      tooltip: '返回',
                      onPressed: () => context.pop(),
                      icon: Icon(Icons.arrow_back_rounded,
                          color: theme.foreground)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('柔光总结',
                            style: AppText.titleLarge
                                .copyWith(color: theme.foreground)),
                        Text('只整理你这次明确选择的光',
                            style: AppText.caption
                                .copyWith(color: theme.foregroundMuted))
                      ]))
                ])),
            Expanded(
                child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.s18),
                    children: [
                  _ScopePicker(
                      scope: _scope,
                      initial: widget.initialScope,
                      onChanged: (scope) => setState(() {
                            _scope = scope;
                          })),
                  const SizedBox(height: AppSpacing.s14),
                  if (!enabled)
                    _StatusCard(
                        icon: Icons.visibility_off_outlined,
                        text: '星图管理员已关闭。捕光、回看和织线仍可正常使用。'),
                  if (enabled && draft == null && !async.isLoading)
                    _StartCard(
                        scope: _scope,
                        onStart: () async {
                          final result = await ref
                              .read(glowOrganizeControllerProvider.notifier)
                              .preview(_scope);
                          if (mounted && result.status == 'success') {
                            setState(() => _loadDraft(result));
                          }
                        }),
                  if (async.isLoading)
                    const _StatusCard(
                        icon: Icons.auto_awesome_outlined,
                        text: '正在轻轻整理这些光...'),
                  if (async.hasError)
                    _StatusCard(
                        icon: Icons.cloud_off_outlined,
                        text: '暂时没有收到回应，原有内容没有任何变化。',
                        action: () => ref
                            .read(glowOrganizeControllerProvider.notifier)
                            .preview(_scope)),
                  if (draft != null && draft.status != 'success')
                    _StatusCard(
                        icon: Icons.info_outline_rounded,
                        text: draft.message.isEmpty ? '暂时无法整理。' : draft.message,
                        action: enabled
                            ? () => ref
                                .read(glowOrganizeControllerProvider.notifier)
                                .preview(_scope)
                            : null),
                  if (draft?.status == 'success') ...[
                    _RangeBanner(scope: draft!.scope, count: draft.sourceCount),
                    const SizedBox(height: AppSpacing.s12),
                    _EditableResult(
                        title: _title,
                        summary: _summary,
                        points: _points,
                        draft: draft,
                        onChanged: () {
                          if (!_edited) setState(() => _edited = true);
                        }),
                    const SizedBox(height: AppSpacing.s12),
                    _SourcesCard(draft: draft),
                    const SizedBox(height: AppSpacing.s12),
                    XiguangCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('为什么这样整理',
                              style: AppText.titleSmall
                                  .copyWith(color: theme.foreground)),
                          const SizedBox(height: AppSpacing.sm),
                          Text(draft.why,
                              style: AppText.body
                                  .copyWith(color: theme.foregroundMuted))
                        ])),
                    const SizedBox(height: AppSpacing.s18),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () => _reject(draft),
                              child: const Text('不合适'))),
                      const SizedBox(width: AppSpacing.s10),
                      Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                              onPressed: _saving ? null : () => _save(draft),
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.bookmark_add_outlined),
                              label: const Text('留下这段整理')))
                    ])
                  ]
                ]))
          ]))
        ]));
  }

  Future<void> _save(AISummaryDraft draft) async {
    setState(() => _saving = true);
    try {
      final points = <AISummaryPoint>[];
      for (var i = 0; i < draft.keyPoints.length; i++) {
        points.add(AISummaryPoint(
            text: _points[i].text.trim(),
            sourceFragmentIds: draft.keyPoints[i].sourceFragmentIds));
      }
      await ref.read(glowOrganizeControllerProvider.notifier).save(
          draft: draft,
          title: _title.text.trim(),
          summary: _summary.text.trim(),
          points: points,
          edited: _edited);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('这段整理已经留在星图注释里。')));
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reject(AISummaryDraft draft) async {
    final reason = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ListTile(
                  title: Text('哪里不合适？'), subtitle: Text('可以直接关闭，不需要解释或填写提示词。')),
              for (final item in const ['放错了', '名字不合适', '解释太多'])
                ListTile(
                    title: Text(item),
                    onTap: () => Navigator.pop(context, item))
            ])));
    if (!mounted) return;
    await ref
        .read(glowOrganizeControllerProvider.notifier)
        .reject(draft, reason);
    if (mounted) context.pop();
  }
}

class _ScopePicker extends StatelessWidget {
  const _ScopePicker(
      {required this.scope, required this.initial, required this.onChanged});
  final AIScope scope;
  final AIScope? initial;
  final ValueChanged<AIScope> onChanged;
  @override
  Widget build(BuildContext context) {
    final options = <AIScope>[
      if (initial?.type == 'fragments') initial!,
      if (initial?.type == 'island') initial!,
      const AIScope.range(7),
      const AIScope.range(30)
    ];
    return SegmentedButton<AIScope>(segments: [
      for (final s in options)
        ButtonSegment(
            value: s,
            label: Text(s.label),
            icon: Icon(s.type == 'range'
                ? Icons.date_range_outlined
                : s.type == 'island'
                    ? Icons.landscape_outlined
                    : Icons.checklist_rounded))
    ], selected: {
      scope
    }, onSelectionChanged: (v) => onChanged(v.first), showSelectedIcon: false);
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.scope, required this.onStart});
  final AIScope scope;
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangCard(
        child: Column(children: [
      Icon(Icons.auto_awesome_outlined, size: 30, color: theme.accent),
      const SizedBox(height: AppSpacing.s10),
      Text(scope.label,
          style: AppText.titleMedium.copyWith(color: theme.foreground)),
      const SizedBox(height: AppSpacing.sm),
      Text('会生成一句摘要、主要线索和阶段名称候选。结果在你确认前不会保存。',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: theme.foregroundMuted)),
      const SizedBox(height: AppSpacing.s14),
      FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('开始整理'))
    ]));
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangCard(
        child: Row(children: [
      Icon(icon, color: theme.accent),
      const SizedBox(width: AppSpacing.s12),
      Expanded(
          child: Text(text,
              style: AppText.body.copyWith(color: theme.foreground))),
      if (action != null)
        IconButton(
            tooltip: '重试',
            onPressed: action,
            icon: const Icon(Icons.refresh_rounded))
    ]));
  }
}

class _RangeBanner extends StatelessWidget {
  const _RangeBanner({required this.scope, required this.count});
  final AIScope scope;
  final int count;
  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(children: [
          Icon(Icons.visibility_outlined, color: theme.accent, size: 19),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text('实际读取：${scope.label}，共 $count 束光',
                  style:
                      AppText.captionStrong.copyWith(color: theme.foreground)))
        ]));
  }
}

class _EditableResult extends StatelessWidget {
  const _EditableResult(
      {required this.title,
      required this.summary,
      required this.points,
      required this.draft,
      required this.onChanged});
  final TextEditingController title, summary;
  final List<TextEditingController> points;
  final AISummaryDraft draft;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('阶段名称',
          style: AppText.captionStrong.copyWith(color: theme.foregroundMuted)),
      const SizedBox(height: AppSpacing.s6),
      TextField(
          controller: title,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(hintText: '给这段时间一个名字')),
      if (draft.titleCandidates.length > 1) ...[
        const SizedBox(height: AppSpacing.sm),
        Wrap(spacing: 6, children: [
          for (final candidate in draft.titleCandidates)
            ActionChip(
                label: Text(candidate),
                onPressed: () {
                  title.text = candidate;
                  onChanged();
                })
        ])
      ],
      const SizedBox(height: AppSpacing.s14),
      Text('一句短摘要',
          style: AppText.captionStrong.copyWith(color: theme.foregroundMuted)),
      const SizedBox(height: AppSpacing.s6),
      TextField(
          controller: summary, onChanged: (_) => onChanged(), maxLines: 3),
      const SizedBox(height: AppSpacing.s14),
      Text('主要线索',
          style: AppText.captionStrong.copyWith(color: theme.foregroundMuted)),
      for (var i = 0; i < points.length; i++)
        Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: TextField(
                controller: points[i],
                onChanged: (_) => onChanged(),
                maxLines: 2,
                decoration: InputDecoration(prefixText: '${i + 1}. ')))
    ]));
  }
}

class _SourcesCard extends StatelessWidget {
  const _SourcesCard({required this.draft});
  final AISummaryDraft draft;
  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangCard(
        child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('查看引用原文',
                style: AppText.titleSmall.copyWith(color: theme.foreground)),
            subtitle: Text('${draft.sources.length} 束光，所有线索都可回看来源',
                style: AppText.caption.copyWith(color: theme.foregroundMuted)),
            children: [
          for (final source in draft.sources)
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(source.excerpt,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: Text('${source.emotion} · 光片 ${source.fragmentId}'))
        ]));
  }
}
