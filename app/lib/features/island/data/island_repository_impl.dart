import '../domain/island.dart';
import '../domain/island_repository.dart';
import 'island_api.dart';

class IslandRepositoryImpl implements IslandRepositoryContract {
  const IslandRepositoryImpl(this._api);

  final IslandApi _api;

  @override
  Future<Island?> getById(int id) async {
    final body = await _api.get('$id');
    return _fromJson(body);
  }

  @override
  Future<List<Island>> list() async {
    final body = await _api.list();
    return (body['islands'] as List<dynamic>? ?? const [])
        .map((item) => _fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Island _fromJson(Map<String, dynamic> json) {
    final rawID = json['id'];
    final parsedID = rawID is int ? rawID : int.tryParse('$rawID') ?? 0;
    return Island(
      id: parsedID,
      publicId: json['public_id'] as String? ?? '',
      userId: json['user_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'star_point',
      fragmentCount: json['fragment_count'] as int? ?? 0,
      description: json['description'] as String? ?? '',
    );
  }
}
