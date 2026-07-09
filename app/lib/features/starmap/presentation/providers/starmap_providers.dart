import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/starmap_api.dart';
import '../../data/starmap_repository_impl.dart';

final starMapRepositoryProvider = Provider<StarMapRepositoryImpl>((ref) {
  return StarMapRepositoryImpl(StarMapApi(ref.watch(apiClientProvider)));
});
