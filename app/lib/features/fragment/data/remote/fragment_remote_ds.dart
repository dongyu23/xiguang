import 'fragment_api.dart';

class FragmentRemoteDataSource {
  const FragmentRemoteDataSource(this._api);

  final FragmentApi _api;

  Future<Map<String, dynamic>> list() => _api.list();
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) =>
      _api.create(body);
}
