import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../fragment/data/fragment_repository.dart';
import '../../../fragment/domain/fragment.dart';
import '../../domain/date_group.dart';

final timelineGroupsProvider = FutureProvider<List<DateGroup>>((ref) async {
  final fragments = ref.watch(fragmentsProvider).value ?? const [];
  try {
    final remoteGroups = await ref.watch(localTimelineGroupsProvider.future);
    return _mergeLocalFragments(remoteGroups, fragments);
  } catch (_) {
    return _groupLocalFragments(fragments);
  }
});

List<DateGroup> _mergeLocalFragments(
  List<DateGroup> remoteGroups,
  List<LightFragmentModel> localFragments,
) {
  if (localFragments.isEmpty) return remoteGroups;
  final remoteIds = {
    for (final group in remoteGroups)
      for (final fragment in group.fragments) fragment.id
  };
  final missing = localFragments
      .where((fragment) => !remoteIds.contains(fragment.id))
      .toList();
  if (missing.isEmpty) return remoteGroups;
  final mergedFragments = [
    for (final group in remoteGroups) ...group.fragments,
    ...missing.map(_fragmentFromLocalModel),
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return _groupFragments(mergedFragments);
}

List<DateGroup> _groupLocalFragments(List<LightFragmentModel> fragments) {
  return _groupFragments(fragments.map(_fragmentFromLocalModel).toList());
}

List<DateGroup> _groupFragments(List<Fragment> fragments) {
  final groups = <String, List<Fragment>>{};
  for (final fragment in fragments) {
    groups.putIfAbsent(_dateLabel(fragment.createdAt), () => []).add(fragment);
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

Fragment _fragmentFromLocalModel(LightFragmentModel fragment) {
  return Fragment(
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
  );
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.year}年${local.month}月${local.day}日';
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
