import 'space_theme.dart';

abstract class SpaceRepository {
  Future<SpaceTheme> currentTheme();
}
