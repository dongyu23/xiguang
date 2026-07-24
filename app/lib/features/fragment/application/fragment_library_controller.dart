import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/fragment.dart';
import '../domain/fragment_repository.dart';

final fragmentLibraryControllerProvider =
    Provider<FragmentLibraryController>((ref) {
  return FragmentLibraryController(ref.watch(fragmentRepositoryProvider));
});

class FragmentLibraryController {
  const FragmentLibraryController(this._repository);

  final FragmentRepositoryContract _repository;

  Future<List<Fragment>> search(String query) =>
      _repository.searchFragments(query);

  Future<List<Fragment>> listDeleted() => _repository.listDeletedFragments();

  Future<List<Fragment>> listLocal() => _repository.listLocalFragments();

  Future<void> restore(int id) => _repository.restoreFragment(id);

  Future<void> deletePermanently(int id) =>
      _repository.permanentlyDeleteFragment(id);
}
