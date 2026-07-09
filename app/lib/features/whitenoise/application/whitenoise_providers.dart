import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/noise_audio.dart';

export '../../../app/providers.dart' show whiteNoiseRepositoryProvider;

final whiteNoiseOptionsProvider = FutureProvider<List<NoiseAudio>>((ref) {
  return ref.watch(whiteNoiseRepositoryProvider).list();
});
