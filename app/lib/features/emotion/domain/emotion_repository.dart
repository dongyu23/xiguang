import 'audio_track.dart';
import 'user_emotion.dart';

abstract interface class EmotionRepositoryPort {
  Future<List<UserEmotion>> getAll();
  Future<int> addCustom(String name, {String? description, String? soundKey});
  Future<void> update(UserEmotion emotion);
  Future<void> delete(int id);

  /// 设为首选心情：清除其他 isUserDefault，置目标为 true（事务）。
  Future<void> setUserDefault(int id);

  /// 设置隐藏状态。
  Future<void> setHidden(int id, bool hidden);

  // ── 音频库 ──

  /// 合并内置音频与自定义音频，内置在前。
  Future<List<AudioTrack>> getAllAudioTracks();

  /// 新增自定义音频，返回 db id。
  Future<int> addAudioTrack({
    required String key,
    required String name,
    required String filePath,
  });

  Future<void> deleteAudioTrack(int id);
}
