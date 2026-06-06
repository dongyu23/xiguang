import 'fragment_drift.dart';

class FragmentDao {
  final List<FragmentRow> _rows = [];

  Future<List<FragmentRow>> list() async => List.unmodifiable(_rows);

  Future<void> upsert(FragmentRow row) async {
    _rows.removeWhere((item) => item.id == row.id);
    _rows.add(row);
  }
}
