/// 统一音频描述 - 合并内置音频（打包 asset）与用户自定义音频（沙盒文件）。
///
/// emotion.soundKey 引用 [key]；查找时先匹配内置 const，再查 audio_library 表。
class AudioTrack {
  const AudioTrack({
    required this.key,
    required this.name,
    required this.source,
    this.assetPath,
    this.filePath,
    this.dbId,
  });

  final String key;
  final String name;
  final AudioTrackSource source;

  /// 内置音频的 asset 路径（source == builtin 时非空）。
  final String? assetPath;

  /// 自定义音频的沙盒绝对路径（source == custom 时非空）。
  final String? filePath;

  /// 自定义音频在 drift 表中的 id（source == custom 时非空），用于删除。
  final int? dbId;

  bool get isBuiltin => source == AudioTrackSource.builtin;
}

enum AudioTrackSource { builtin, custom }
