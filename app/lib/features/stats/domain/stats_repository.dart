import 'emotion_density.dart';
import 'freq_words.dart';

abstract interface class StatsRepositoryContract {
  Future<EmotionDensity> emotionDensity();
  Future<FreqWordsResult> frequentWords();
}
