import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/space_api.dart';
import '../../data/space_repository_impl.dart';
import '../../domain/space_theme.dart';

final spaceRepositoryProvider = Provider<SpaceRepositoryImpl>((ref) {
  return SpaceRepositoryImpl(SpaceApi(ref.watch(apiClientProvider)));
});

final spaceThemeProvider = FutureProvider<SpaceTheme>((ref) {
  return ref.watch(spaceRepositoryProvider).currentTheme();
});
