import 'fragment_dao.dart';
import 'fragment_drift.dart';

class FragmentLocalDataSource {
  const FragmentLocalDataSource(this._dao);

  final FragmentDao _dao;

  Future<List<FragmentRow>> listCached() => _dao.list();
  Future<void> save(FragmentRow row) => _dao.upsert(row);
}
