import '../domain/noise_audio.dart';
import '../domain/whitenoise_repository.dart';
import 'whitenoise_api.dart';
import 'whitenoise_assets.dart';

class WhiteNoiseRepositoryImpl implements WhiteNoiseRepositoryContract {
  const WhiteNoiseRepositoryImpl(this._api);

  final WhiteNoiseApi _api;

  @override
  Future<List<NoiseAudio>> list() async {
    final body = await _api.list();
    final remote = (body['value'] as List<dynamic>? ?? const [])
        .map((item) => item as Map<String, dynamic>)
        .map((item) {
          final id = item['id'] as String? ?? '';
          final fallback =
              builtinNoiseAudios.where((audio) => audio.id == id).firstOrNull;
          return NoiseAudio(
            id: id,
            name: item['name'] as String? ?? fallback?.name ?? id,
            icon: fallback?.icon ?? id,
            audioFile: fallback?.audioFile ?? '',
            category: item['category'] as String? ?? fallback?.category ?? '',
          );
        })
        .where((item) => item.id.isNotEmpty)
        .toList();
    return remote.isEmpty ? builtinNoiseAudios : remote;
  }
}
