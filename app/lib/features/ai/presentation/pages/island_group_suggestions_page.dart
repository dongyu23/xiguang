import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../application/island_group_controller.dart';

class IslandGroupSuggestionsPage extends ConsumerStatefulWidget {
  const IslandGroupSuggestionsPage({super.key});
  @override
  ConsumerState<IslandGroupSuggestionsPage> createState() =>
      _IslandGroupSuggestionsPageState();
}

class _IslandGroupSuggestionsPageState
    extends ConsumerState<IslandGroupSuggestionsPage> {
  final List<Map<String, dynamic>> _proposals = [];
  bool _creating = false;
  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final async = ref.watch(islandGroupControllerProvider);
    final result = async.valueOrNull;
    return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          const Positioned.fill(child: AtmosphereBackground()),
          SafeArea(
              child: Column(children: [
            Padding(
                padding: const EdgeInsets.all(AppSpacing.s12),
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
                        Text('看看哪些岛可以成群',
                            style: AppText.titleLarge
                                .copyWith(color: theme.foreground)),
                        Text('原岛和岛内光片都会完整保留',
                            style: AppText.caption
                                .copyWith(color: theme.foregroundMuted))
                      ]))
                ])),
            Expanded(
                child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.s18),
                    children: [
                  if (result == null && !async.isLoading)
                    XiguangCard(
                        child: Column(children: [
                      Icon(Icons.hub_outlined, color: theme.accent, size: 30),
                      const SizedBox(height: AppSpacing.s10),
                      Text('先由可解释规则寻找靠近的岛，再请星图管理员排序和命名。',
                          textAlign: TextAlign.center,
                          style: AppText.body
                              .copyWith(color: theme.foregroundMuted)),
                      const SizedBox(height: AppSpacing.s14),
                      FilledButton.icon(
                          onPressed: _preview,
                          icon: const Icon(Icons.auto_awesome_outlined),
                          label: const Text('看看岛群建议'))
                    ])),
                  if (async.isLoading)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(AppSpacing.xl),
                            child: CircularProgressIndicator())),
                  if (async.hasError)
                    XiguangCard(
                        child: ListTile(
                            leading: const Icon(Icons.cloud_off_outlined),
                            title: const Text('暂时没有收到回应'),
                            subtitle: const Text('小岛没有任何变化。'),
                            trailing: IconButton(
                                onPressed: _preview,
                                icon: const Icon(Icons.refresh_rounded)))),
                  if (result != null && result['status'] != 'success')
                    XiguangCard(
                        child: Text(
                            result['message'] as String? ?? '暂时没有合适的岛群建议。')),
                  for (var i = 0; i < _proposals.length; i++)
                    Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                        child: _ProposalCard(
                            proposal: _proposals[i],
                            onChanged: () => setState(() {}))),
                  if (_proposals.isNotEmpty)
                    FilledButton.icon(
                        onPressed: _creating ? null : _create,
                        icon: _creating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.done_all_rounded),
                        label: Text(
                            '确认创建 ${_proposals.where((p) => p['selected'] == true).length} 个岛群'))
                ]))
          ]))
        ]));
  }

  Future<void> _preview() async {
    final result =
        await ref.read(islandGroupControllerProvider.notifier).preview();
    if (!mounted) return;
    final raw = result['proposals'] as List<dynamic>? ?? const [];
    setState(() {
      _proposals
        ..clear()
        ..addAll(raw.map((e) {
          final p = Map<String, dynamic>.from(e as Map);
          p['selected'] = p['preselected'] == true;
          p['name_controller'] =
              TextEditingController(text: p['name'] as String? ?? '');
          p['description_controller'] =
              TextEditingController(text: p['description'] as String? ?? '');
          return p;
        }));
    });
  }

  Future<void> _create() async {
    final selected = _proposals.where((p) => p['selected'] == true).map((p) {
      return {
        ...p,
        'name': (p['name_controller'] as TextEditingController).text.trim(),
        'description':
            (p['description_controller'] as TextEditingController).text.trim()
      };
    }).toList();
    if (selected.isEmpty) return;
    setState(() => _creating = true);
    try {
      await ref
          .read(islandGroupControllerProvider.notifier)
          .createSelected(selected);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('岛群已经形成，原来的岛仍在原处。')));
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.proposal, required this.onChanged});
  final Map<String, dynamic> proposal;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final ids = (proposal['island_ids'] as List<dynamic>? ?? const []);
    return XiguangCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: proposal['selected'] == true,
          onChanged: (v) {
            proposal['selected'] = v == true;
            onChanged();
          },
          title: TextField(
              controller: proposal['name_controller'] as TextEditingController,
              decoration: const InputDecoration(labelText: '岛群名称')),
          subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                  '${ids.length} 座岛 · ${proposal['confidence'] == 'high' ? '联系明显，已预选' : '联系仍有余地，由你决定'}',
                  style:
                      AppText.caption.copyWith(color: theme.foregroundMuted)))),
      TextField(
          controller:
              proposal['description_controller'] as TextEditingController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: '说明')),
      const SizedBox(height: AppSpacing.s10),
      Text('为什么这样建议',
          style: AppText.captionStrong.copyWith(color: theme.foreground)),
      const SizedBox(height: AppSpacing.s3),
      Text(proposal['why'] as String? ?? '',
          style: AppText.body.copyWith(color: theme.foregroundMuted)),
      const SizedBox(height: AppSpacing.sm),
      Text('岛屿 ID：${ids.join('、')}',
          style: AppText.caption.copyWith(color: theme.foregroundMuted))
    ]));
  }
}
