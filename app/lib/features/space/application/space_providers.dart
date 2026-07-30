import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../membership/application/membership_controller.dart';
import '../../membership/domain/membership.dart';
import '../domain/space_theme.dart';

final spaceThemeProvider =
    AsyncNotifierProvider<SpaceController, List<SpaceTheme>>(
  SpaceController.new,
);

class SpaceController extends AsyncNotifier<List<SpaceTheme>> {
  @override
  Future<List<SpaceTheme>> build() async {
    final membership = ref.watch(membershipProvider).valueOrNull;
    final tier = membership?.tier ?? MembershipTier.glimmer;
    return applySpaceThemeEntitlements(
      await ref.watch(spaceRepositoryProvider).themes(),
      tier,
    );
  }

  Future<void> selectTheme(String themeId) async {
    await ref.read(spaceRepositoryProvider).selectTheme(themeId);
    final tier = ref.read(membershipProvider).valueOrNull?.tier ??
        MembershipTier.glimmer;
    state = AsyncData(applySpaceThemeEntitlements(
      await ref.read(spaceRepositoryProvider).themes(),
      tier,
    ));
  }
}

List<SpaceTheme> applySpaceThemeEntitlements(
  List<SpaceTheme> themes,
  MembershipTier tier,
) {
  const rank = {'glimmer': 0, 'starlight': 1, 'galaxy': 2};
  final currentRank = rank[tier.code] ?? 0;
  return themes
      .map((theme) => SpaceTheme(
            id: theme.id,
            name: theme.name,
            primaryColorHex: theme.primaryColorHex,
            description: theme.description,
            requiredTier: theme.requiredTier,
            locked: currentRank < (rank[theme.requiredTier] ?? 0),
            selected: theme.selected,
          ))
      .toList(growable: false);
}
