import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../features/fragment/data/fragment_repository.dart';
import '../../../../features/fragment/presentation/pages/fragment_detail_page.dart';
import '../../../../ui/composites/light_card.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../data/island_repository.dart';

class IslandDetailPage extends ConsumerWidget {
  const IslandDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = Uri.decodeComponent(id);
    final repository = ref.watch(islandRepositoryProvider);
    final detail = _load(repository, name);
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('小岛详情'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: FutureBuilder<_IslandDetailData>(
            future: detail,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data ??
                  _IslandDetailData(
                    island: IslandModel(
                      name: name,
                      status: 'star_point',
                      fragmentCount: 0,
                      description: '这些光因为同一个主题靠近。',
                    ),
                    fragments: const [],
                  );
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
                              Text('ISLAND', style: AppText.eyebrow),
                              const SizedBox(height: 8),
                              Text(data.island.name,
                                  style: AppText.titleMedium),
                              const SizedBox(height: 8),
                              Text(data.island.description,
                                  style: AppText.body),
                              const SizedBox(height: 10),
                              Text(
                                '${data.fragments.length} 束光 · ${_statusLabel(data.island.status)}',
                                style: AppText.caption,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (data.fragments.isEmpty)
                          Text('这座小岛还没有可回看的光片。', style: AppText.body)
                        else
                          ...data.fragments.map((fragment) => LightFragmentCard(
                                fragment: fragment.toLightFragment(),
                                onTap: () =>
                                    Navigator.of(context, rootNavigator: true)
                                        .push(MaterialPageRoute<void>(
                                  builder: (_) =>
                                      FragmentDetailPage(id: '${fragment.id}'),
                                )),
                              )),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }

  Future<_IslandDetailData> _load(
      IslandRepository repository, String name) async {
    final results = await Future.wait<Object?>([
      repository.getIsland(name),
      repository.listIslandFragments(name),
    ]);
    return _IslandDetailData(
      island: (results[0] as IslandModel?) ??
          IslandModel(
            name: name,
            status: 'star_point',
            fragmentCount: 0,
            description: '这些光因为同一个主题靠近。',
          ),
      fragments: results[1] as List<LightFragmentModel>,
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'formed' => '已成岛',
      'growing' => '生长中',
      'dormant' => '休眠',
      'relit' => '重新亮起',
      _ => '主题星点',
    };
  }
}

class _IslandDetailData {
  const _IslandDetailData({required this.island, required this.fragments});

  final IslandModel island;
  final List<LightFragmentModel> fragments;
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
