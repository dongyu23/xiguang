import 'island.dart';

abstract interface class IslandRepositoryContract {
  Future<List<Island>> list();
  Future<Island?> getById(int id);
}
