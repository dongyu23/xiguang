import 'create_params.dart';
import 'fragment.dart';

abstract interface class FragmentRepositoryContract {
  Future<List<Fragment>> list();
  Future<Fragment?> getById(int id);
  Future<Fragment> create(CreateFragmentParams params);
  Future<Fragment> update(Fragment fragment);
  Future<void> delete(int id);
}
