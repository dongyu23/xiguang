import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/space_theme.dart';

final spaceThemeProvider = StateProvider<SpaceThemeValue>((ref) {
  return SpaceThemeValue.starry;
});
