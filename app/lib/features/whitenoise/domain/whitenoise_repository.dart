import 'noise_audio.dart';

abstract interface class WhiteNoiseRepositoryContract {
  Future<List<NoiseAudio>> list();
}
