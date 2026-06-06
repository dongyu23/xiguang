import '../domain/space_repository.dart';
import '../domain/space_theme.dart';
import 'space_api.dart';

class SpaceRepositoryImpl implements SpaceRepository {
  SpaceRepositoryImpl(this._api);

  final SpaceApi _api;

  @override
  Future<SpaceTheme> currentTheme() async {
    try {
      final json = await _api.currentTheme();
      return SpaceTheme(
        name: json['name'] as String? ?? '晨雾',
        primaryColorHex: json['primary_color'] as String? ?? '#72A58F',
        description: json['description'] as String? ?? '一层轻柔的微光。',
      );
    } catch (_) {
      return const SpaceTheme(
        name: '晨雾',
        primaryColorHex: '#72A58F',
        description: '一层轻柔的微光。',
      );
    }
  }
}
