import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/providers.dart';
import '../domain/audio_track.dart';

/// 音频库 provider - 合并内置音频（const）与用户自定义音频（DB）。
final audioTracksProvider =
    AsyncNotifierProvider<AudioTracksController, List<AudioTrack>>(
  AudioTracksController.new,
);

class AudioTracksController extends AsyncNotifier<List<AudioTrack>> {
  @override
  Future<List<AudioTrack>> build() {
    return ref.watch(emotionRepositoryProvider).getAllAudioTracks();
  }

  /// 将选中的音频文件拷贝到 app 沙盒并入库，返回新增的 track。
  ///
  /// [sourcePath] 由 file_picker 返回的平台路径；[displayName] 用户可见名。
  Future<AudioTrack> addFromFile({
    required String sourcePath,
    required String displayName,
  }) async {
    final tracks = await future;
    final repo = ref.read(emotionRepositoryProvider);
    final key = _generateKey(displayName);
    final destPath = await _copyToSandbox(sourcePath, key);
    final id = await repo.addAudioTrack(
      key: key,
      name: displayName,
      filePath: destPath,
    );
    final track = AudioTrack(
      key: key,
      name: displayName,
      source: AudioTrackSource.custom,
      filePath: destPath,
      dbId: id,
    );
    state = AsyncData([...tracks, track]);
    return track;
  }

  /// 删除自定义音频：先删 DB，再删沙盒文件。内置音频不可删。
  Future<void> delete(int id) async {
    final tracks = await future;
    state = const AsyncLoading<List<AudioTrack>>().copyWithPrevious(state);
    try {
      await ref.read(emotionRepositoryProvider).deleteAudioTrack(id);
      // 找到被删 track 的沙盒文件并清理（失败不影响 DB 一致性）
      AudioTrack? removed;
      for (final t in tracks) {
        if (t.dbId == id) removed = t;
      }
      if (removed?.filePath != null) {
        final f = File(removed!.filePath!);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {
            // 文件删除失败不阻塞：DB 已删，残留文件下次可手动清理
          }
        }
      }
      state = AsyncData([
        for (final t in tracks)
          if (t.dbId != id) t,
      ]);
    } catch (error, stackTrace) {
      state = AsyncError<List<AudioTrack>>(error, stackTrace)
          .copyWithPrevious(AsyncData(tracks));
      rethrow;
    }
  }

  /// 生成唯一 key：custom_ 前缀 + 时间戳 + 名字哈希，避免与内置 key 冲突。
  String _generateKey(String name) {
    final hash = name.hashCode.abs().toRadixString(36);
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return 'custom_${ts}_$hash';
  }

  /// 拷贝到 app documents 目录下的 audio_library/ 子目录，保留原扩展名。
  Future<String> _copyToSandbox(String sourcePath, String key) async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(dir.path, 'audio_library'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    final ext = p.extension(sourcePath);
    final destPath = p.join(audioDir.path, '$key$ext');
    await File(sourcePath).copy(destPath);
    return destPath;
  }
}
