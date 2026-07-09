import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/whitenoise_api.dart';
import '../../data/whitenoise_repository_impl.dart';

final whiteNoiseRepositoryProvider = Provider<WhiteNoiseRepositoryImpl>((ref) {
  return WhiteNoiseRepositoryImpl(WhiteNoiseApi(ref.watch(apiClientProvider)));
});
