import 'space_theme.dart';

abstract interface class SpaceRepositoryContract {
  Future<SpaceThemeValue> currentTheme();
  Future<void> saveTheme(SpaceThemeValue theme);
}
