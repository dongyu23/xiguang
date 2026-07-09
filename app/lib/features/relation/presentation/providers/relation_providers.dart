import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/relation_api.dart';
import '../../data/relation_repository_impl.dart';
import '../../domain/relation.dart';

final relationRepositoryProvider = Provider<RelationRepositoryImpl>((ref) {
  return RelationRepositoryImpl(RelationApi(ref.watch(apiClientProvider)));
});

final fragmentRelationsProvider =
    FutureProvider.family<List<Relation>, int>((ref, fragmentId) {
  return ref.watch(relationRepositoryProvider).list(fragmentId: fragmentId);
});

final relationsProvider = FutureProvider<List<Relation>>((ref) {
  return ref.watch(relationRepositoryProvider).list();
});
