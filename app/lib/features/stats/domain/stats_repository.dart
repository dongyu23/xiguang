import 'emotion_density.dart';
import 'freq_words.dart';
import 'tide_insight.dart';

abstract interface class StatsRepositoryContract {
  Future<EmotionDensity> emotionDensity();
  Future<FreqWordsResult> frequentWords();
  Future<TideInsight> tideInsight();
}
