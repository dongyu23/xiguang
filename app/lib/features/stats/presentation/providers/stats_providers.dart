import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/stats_api.dart';
import '../../data/stats_repository_impl.dart';

final statsRepositoryProvider = Provider<StatsRepositoryImpl>((ref) {
  return StatsRepositoryImpl(StatsApi(ref.watch(apiClientProvider)));
});
