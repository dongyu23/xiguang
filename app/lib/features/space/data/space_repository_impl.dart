import '../domain/space_repository.dart';
import '../domain/space_theme.dart';
import 'space_api.dart';
import 'space_theme_assets.dart';

class SpaceRepositoryImpl implements SpaceRepository {
  SpaceRepositoryImpl(this._api);

  final SpaceApi _api;

  @override
  Future<List<SpaceTheme>> themes() async {
    try {
      final json = await _api.themes();
      final items = (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map((item) => SpaceTheme(
                id: item['id'] as String? ?? '',
                name: item['name'] as String? ?? '',
                primaryColorHex: item['primary_color'] as String? ?? '#72A58F',
                description: item['description'] as String? ?? '',
                requiredTier: item['required_tier'] as String? ?? 'glimmer',
                locked: item['locked'] as bool? ?? false,
                selected: item['selected'] as bool? ?? false,
              ))
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
      return items.isEmpty ? builtinSpaceThemes : items;
    } catch (_) {
      return builtinSpaceThemes;
    }
  }

  @override
  Future<void> selectTheme(String id) => _api.selectTheme(id);
}
