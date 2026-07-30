import 'space_theme.dart';

abstract class SpaceRepository {
  Future<List<SpaceTheme>> themes();
  Future<void> selectTheme(String id);
}
