import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../fragment/application/fragment_list_controller.dart';
import '../../fragment/domain/fragment.dart';
import '../domain/relation.dart';

export '../../../app/providers.dart' show relationRepositoryProvider;

final fragmentRelationsProvider =
    FutureProvider.family<List<Relation>, int>((ref, fragmentId) {
  return ref.watch(relationRepositoryProvider).list(fragmentId: fragmentId);
});

final relationsProvider = FutureProvider<List<Relation>>((ref) {
  return ref.watch(relationRepositoryProvider).list();
});

class RelationLedgerData {
  const RelationLedgerData({
    required this.relations,
    required this.fragmentsById,
  });

  final List<Relation> relations;
  final Map<int, Fragment> fragmentsById;
}

final relationLedgerProvider = FutureProvider<RelationLedgerData>((ref) async {
  final relations = await ref.watch(relationRepositoryProvider).list();
  final fragments = await ref.watch(fragmentsProvider.future);
  return RelationLedgerData(
    relations: relations,
    fragmentsById: {for (final fragment in fragments) fragment.id: fragment},
  );
});
