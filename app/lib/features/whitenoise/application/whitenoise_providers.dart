import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../membership/application/membership_controller.dart';
import '../../membership/domain/membership.dart';
import '../domain/noise_audio.dart';

export '../../../app/providers.dart' show whiteNoiseRepositoryProvider;

final whiteNoiseOptionsProvider = FutureProvider<List<NoiseAudio>>((ref) async {
  final membership = ref.watch(membershipProvider).valueOrNull;
  final tier = membership?.tier ?? MembershipTier.glimmer;
  final items = await ref.watch(whiteNoiseRepositoryProvider).list();
  return items
      .map((item) => item.copyWith(
            locked: item.locked || !_tierAllows(tier, item.requiredTier),
          ))
      .toList(growable: false);
});

bool _tierAllows(MembershipTier tier, String requiredTier) {
  const rank = {'glimmer': 0, 'starlight': 1, 'galaxy': 2};
  return (rank[tier.code] ?? 0) >= (rank[requiredTier] ?? 0);
}
