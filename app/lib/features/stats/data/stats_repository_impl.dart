import '../domain/emotion_density.dart';
import '../domain/freq_words.dart';
import '../domain/stats_repository.dart';
import 'stats_api.dart';

class StatsRepositoryImpl implements StatsRepositoryContract {
  const StatsRepositoryImpl(this._api);

  final StatsApi _api;

  @override
  Future<EmotionDensity> emotionDensity() async {
    final body = await _api.emotionDensity();
    final total = body['total'] as int? ?? 0;
    final emotions = (body['emotions'] as List<dynamic>? ?? const [])
        .map((item) => item as Map<String, dynamic>)
        .map((item) {
      final count = item['count'] as int? ?? 0;
      return EmotionDensityItem(
        name: item['name'] as String? ?? '说不清',
        count: count,
        percentage: total == 0 ? 0 : count / total,
      );
    }).toList();
    return EmotionDensity(
      period: body['period'] as String? ?? '7d',
      emotions: emotions,
    );
  }

  @override
  Future<FreqWordsResult> frequentWords() async {
    final body = await _api.frequentWords();
    final words = (body['words'] as List<dynamic>? ?? const [])
        .map((item) => item as Map<String, dynamic>)
        .map((item) => FreqWord(
              text: item['text'] as String? ?? '',
              count: item['count'] as int? ?? 0,
            ))
        .where((item) => item.text.isNotEmpty)
        .toList();
    return FreqWordsResult(words);
  }
}
