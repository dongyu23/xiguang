import '../domain/space_repository.dart';
import '../domain/space_theme.dart';
import 'space_api.dart';

class SpaceRepositoryImpl implements SpaceRepositoryContract {
  const SpaceRepositoryImpl(this._api);

  final SpaceApi _api;

  @override
  Future<SpaceThemeValue> currentTheme() async {
    final body = await _api.getConfig();
    return switch (body['theme']) {
      'ocean' => SpaceThemeValue.ocean,
      'room' => SpaceThemeValue.room,
      'island' => SpaceThemeValue.island,
      _ => SpaceThemeValue.starry,
    };
  }

  @override
  Future<void> saveTheme(SpaceThemeValue theme) async {
    await _api.saveConfig({'theme': theme.name});
  }
}
