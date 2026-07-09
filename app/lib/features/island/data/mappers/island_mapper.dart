import '../../domain/island_model.dart';

class IslandMapper {
  IslandMapper._();

  static IslandModel fromApi(Map<String, dynamic> json) {
    return IslandModel(
      name: json['name'] as String? ?? '未命名小岛',
      islandId: (json['island_id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'star_point',
      fragmentCount: json['fragment_count'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      manual: json['manual'] as bool? ?? false,
    );
  }
}
