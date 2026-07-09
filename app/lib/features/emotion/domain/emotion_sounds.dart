/// 心情绑定的声音目录。
///
/// 每个心情可绑定一个声音（soundKey），在管理心情页面试听、捕光页唱片播放。
/// soundKey 为 null 表示该心情未绑定声音（自定义心情默认为空）。
class EmotionSound {
  const EmotionSound({
    required this.key,
    required this.name,
    required this.assetPath,
  });

  final String key;
  final String name;
  final String assetPath;
}

/// 内置声音清单（3 首）。
const emotionSounds = [
  EmotionSound(
    key: 'soothing',
    name: '舒缓',
    assetPath: 'assets/audio/Light music 舒缓.m4a',
  ),
  EmotionSound(
    key: 'upbeat',
    name: '律动欢快',
    assetPath: 'assets/audio/Light music 律动欢快.m4a',
  ),
  EmotionSound(
    key: 'haoyvnlai',
    name: '好韵来',
    assetPath: 'assets/audio/haoyvnlai(1).m4a',
  ),
];

/// 根据 soundKey 查找对应的资源路径。未找到返回 null。
String? soundAssetForKey(String? key) {
  if (key == null || key.isEmpty) return null;
  for (final s in emotionSounds) {
    if (s.key == key) return s.assetPath;
  }
  return null;
}

/// 根据 soundKey 查找声音名称（用于编辑页展示）。
String? soundNameForKey(String? key) {
  if (key == null || key.isEmpty) return null;
  for (final s in emotionSounds) {
    if (s.key == key) return s.name;
  }
  return null;
}

/// 默认 7 个心情的声音绑定（与原 capture_page 硬编码映射一致）。
const defaultEmotionSoundKeys = <String, String>{
  '平静': 'soothing',
  '开心': 'upbeat',
  '疲惫': 'soothing',
  '焦虑': 'soothing',
  '失落': 'haoyvnlai',
  '被击中': 'upbeat',
  '混乱': 'upbeat',
};
