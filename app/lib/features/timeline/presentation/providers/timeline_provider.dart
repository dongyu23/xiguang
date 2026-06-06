import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../fragment/data/fragment_repository.dart';
import '../../../fragment/domain/fragment.dart';
import '../../domain/date_group.dart';

final timelineGroupsProvider = FutureProvider<List<DateGroup>>((ref) async {
  try {
    return await ref.watch(localTimelineGroupsProvider.future);
  } catch (_) {
    final fragments = ref.watch(fragmentsProvider).value ?? const [];
    return _groupLocalFragments(fragments);
  }
});

List<DateGroup> _groupLocalFragments(List<LightFragmentModel> fragments) {
  final groups = <String, List<Fragment>>{};
  for (final fragment in fragments) {
    groups.putIfAbsent(fragment.dateLabel, () => []).add(
          Fragment(
            id: fragment.id,
            publicId: '',
            userId: 0,
            contentText: fragment.contentText,
            emotion: fragment.emotion,
            status: _statusFromText(fragment.status),
            mediaUrls: fragment.mediaUrls,
            tags: fragment.tags,
            createdAt: fragment.createdAt,
            updatedAt: fragment.createdAt,
          ),
        );
  }
  return groups.entries
      .map(
        (entry) => DateGroup(
          dateLabel: entry.key,
          fragments: entry.value,
          emotionDots: entry.value
              .map((fragment) => fragment.emotion ?? '说不清')
              .toSet()
              .toList(),
        ),
      )
      .toList();
}

FragmentStatus _statusFromText(String value) {
  return switch (value) {
    'stardust' => FragmentStatus.stardust,
    'echo' => FragmentStatus.echo,
    'seed' => FragmentStatus.seed,
    'tide' => FragmentStatus.tide,
    'island_core' => FragmentStatus.islandCore,
    _ => FragmentStatus.twilight,
  };
}
