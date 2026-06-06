import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/image_grid.dart';
import '../../../../ui/composites/tag_chip.dart';
import '../../../../ui/spaces/space_canvas.dart';

class FragmentDetailPage extends ConsumerWidget {
  const FragmentDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fragmentID = int.tryParse(id) ?? 0;
    final fragments = ref.watch(fragmentsProvider);
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('光片详情'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: fragments.when(
            data: (items) {
              final fragment =
                  items.where((item) => item.id == fragmentID).firstOrNull;
              if (fragment == null) {
                return Center(child: Text('没有找到这束光。', style: AppText.body));
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 104),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: softDecoration(AppColors.white),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(fragment.dateLabel,
                                      style: AppText.eyebrow),
                                  const SizedBox(height: 10),
                                  Text(fragment.title,
                                      style: AppText.titleMedium),
                                  const SizedBox(height: 12),
                                  Text(fragment.contentText,
                                      style: AppText.body),
                                  if (fragment.mediaUrls.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    ImageGrid(urls: fragment.mediaUrls),
                                  ],
                                  const SizedBox(height: 16),
                                  Wrap(spacing: 8, runSpacing: 8, children: [
                                    MiniTag(
                                        label: fragment.emotion, filled: true),
                                    ...fragment.tags
                                        .map((tag) => MiniTag(label: tag)),
                                  ]),
                                ]),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await ref
                                    .read(fragmentRepositoryProvider)
                                    .deleteFragment(fragment.id);
                                ref.invalidate(fragmentsProvider);
                                if (context.mounted) context.pop();
                              },
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('删除这束光'),
                            ),
                          ),
                        ]),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('暂时无法打开这束光：$error', style: AppText.body)),
          ),
        ),
      ),
    ]);
  }
}
