import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/emotion_density.dart';
import '../domain/freq_words.dart';
import '../domain/tide_insight.dart';

final statsRefreshTickProvider = StateProvider<int>((ref) => 0);

final emotionDensityProvider = FutureProvider<EmotionDensity>((ref) async {
  ref.watch(statsRefreshTickProvider);
  return ref.watch(statsRepositoryProvider).emotionDensity();
});

final freqWordsProvider = FutureProvider<FreqWordsResult>((ref) async {
  ref.watch(statsRefreshTickProvider);
  return ref.watch(statsRepositoryProvider).frequentWords();
});

final tideInsightProvider = FutureProvider<TideInsight>((ref) async {
  return ref.watch(statsRepositoryProvider).tideInsight();
});
