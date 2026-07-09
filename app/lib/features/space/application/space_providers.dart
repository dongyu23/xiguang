import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/space_theme.dart';

final spaceThemeProvider = FutureProvider<SpaceTheme>((ref) {
  return ref.watch(spaceRepositoryProvider).currentTheme();
});
