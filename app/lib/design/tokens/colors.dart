import 'package:flutter/material.dart';

/// 隙光莫兰迪色系 — 低饱和度、微光渐变、模拟晨昏/月光/雾气/天色变化
class AppColors {
  AppColors._();

  // 基础色板
  static const paper = Color(0xFFF6F3EC);
  static const white = Color(0xFFFFFCF6);
  static const ink = Color(0xFF233332);
  static const inkMuted = Color(0xFF78827D);
  static const line = Color(0xFFE4DDD0);
  static const inkSubtle = Color(0xFFA0A8A5); // 次要文字
  static const paperDark = Color(0xFFFBF7EF); // 深色纸张背景
  static const cardBorder = Color(0xFFE9E1D5); // 卡片边框
  static const shimmerBase = Color(0xFFE8E4DD); // 闪光基础色
  static const shimmerHighlight = Color(0xFFF5F2EC); // 闪光高亮色

  // 主题色
  static const teaGreen = Color(0xFF72A58F); // 茶绿 — 平静、生长
  static const mistBlue = Color(0xFF9EBBCC); // 雾蓝 — 微光、失眠
  static const sunsetCoral = Color(0xFFE9A18B); // 珊瑚 — 被击中、期待
  static const lilac = Color(0xFFD9CCE8); // 淡紫 — 说不清、氛围

  // 群岛海面语义色。集中在色板中，避免自绘组件散落原始色值。
  static const islandSeaNightDeep = Color(0xFF112725);
  static const islandSeaNightMid = Color(0xFF1B3531);
  static const islandSeaNightMist = Color(0xFF26323A);
  static const islandSeaNightDusk = Color(0xFF201F2B);
  static const islandSeaDayWarm = Color(0xFFF5F0E5);
  static const islandSeaDayMint = Color(0xFFDCEAE4);
  static const islandSeaDayMist = Color(0xFFE4EBE7);
  static const islandSeaDayDusk = Color(0xFFF2E8DC);
  static const islandSeaGlowNight = Color(0xFF6FA395);
  static const islandSeaGlowDay = Color(0xFF9FC5B9);
  static const islandSeaHazeNight = Color(0xFF8196B0);
  static const islandSeaHazeDay = Color(0xFFB8CBD0);
  static const islandTideNight = Color(0xFF8DB4AB);
  static const islandTideDay = Color(0xFF718F88);
  static const islandRelit = Color(0xFFD7BC7C);

  // 夜间文字/图标色 - 统一入口（AppText.nightInk 等保留向后兼容）
  // 其余夜间表面色（nightBackground/nightSurface 等）见下方夜间色板
  static const nightInk = Color(0xFFF4EFE4); // 夜间主文字/图标
  static const nightInkMuted = Color(0xFFC9D0C8); // 夜间次要文字/图标
  static const nightAccent = Color(0xFFA6CDBB); // 夜间强调色（对应日间 teaGreen）

  // 情绪色点（对应 emotion 枚举）
  static const emotionCalm = teaGreen;
  static const emotionHappy = Color(0xFFF0C78E);
  static const emotionTired = mistBlue;
  static const emotionAnxious = sunsetCoral;
  static const emotionLost = Color(0xFFC4C4C4);
  static const emotionStruck = Color(0xFFE8B88A);
  static const emotionChaos = lilac;
  static const emotionUnclear = Color(0xFFB8C5B2);

  /// 情绪名 → 颜色映射（缓存为 Map，O(1) 查表）
  static const _emotionMap = <String, Color>{
    '平静': emotionCalm,
    '开心': emotionHappy,
    '疲惫': emotionTired,
    '焦虑': emotionAnxious,
    '失落': emotionLost,
    '被击中': emotionStruck,
    '混乱': emotionChaos,
  };

  /// 自定义情绪的莫兰迪兜底色板（与默认 7 个区分）。
  /// 用名字 hash 确定性映射，保证同名情绪每次同色。
  static const _customEmotionPalette = <Color>[
    Color(0xFFB8C5B2),
    Color(0xFFC9B8D4),
    Color(0xFFD4C5B8),
    Color(0xFFB8C9D4),
    Color(0xFFD4B8C0),
    Color(0xFFC0D4B8),
    Color(0xFFB8D4C9),
    Color(0xFFD4CBB8),
  ];

  /// 情绪编辑器可选色，页面只消费语义色，不自行声明色值。
  static const emotionEditorPalette = <Color>[
    teaGreen,
    mistBlue,
    sunsetCoral,
    lilac,
    emotionHappy,
    emotionLost,
    emotionStruck,
    emotionUnclear,
    Color(0xFFC9B8D4),
    Color(0xFFD4C5B8),
    Color(0xFFB8C9D4),
    Color(0xFFD4B8C0),
  ];

  /// 情绪名 → 颜色。默认 7 个走静态 map；自定义情绪走 hash 兜底色板，
  /// 保证 emotionColor() 同步可用（无需查 DB），且与情绪表里 autoColorForName 一致。
  static Color emotionColor(String emotion) {
    final mapped = _emotionMap[emotion];
    if (mapped != null) return mapped;
    if (emotion.isEmpty) return emotionUnclear;
    var hash = 0;
    for (final c in emotion.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return _customEmotionPalette[hash % _customEmotionPalette.length];
  }

  // 渐变（用于 BreathingLightCard / UniverseSky 等）
  static const gradientDusk = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF213A3B), Color(0xFF7DAE99), Color(0xFFFFD4A8)],
  );

  static const gradientNight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF203437), Color(0xFF496F67), Color(0xFFF1CDA5)],
  );

  static const gradientAtmosphere = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [paper, Color(0xFFE8F1EC), Color(0xFFF8ECE1)],
  );

  // 夜间模式色板
  static const nightBackground = Color(0xFF142322);
  static const nightSurface = Color(0xFF213433);
  static const nightSurfaceHigh = Color(0xFF172625);
  static const nightNav = Color(0xFF172625);
  static const nightBorder = Color(0xFF2A3E3C);
  static const nightButton = Color(0xFF233A38);
  static const nightShadow = Color(0xFF23413F); // 夜间阴影色
  static const nightGradientMid = Color(0xFF243D3A); // 夜间渐变中间色
  static const nightGradientEnd = Color(0xFF4E6054); // 夜间渐变结束色
  static const nightCard = Color(0xFF203231); // 夜间卡片背景
  static const nightCardDark = Color(0xFF0F1D1B); // 夜间深色卡片
  static const nightCardMid = Color(0xFF263936); // 夜间中等卡片
  static const nightCardLight = Color(0xFF52615C); // 夜间浅色卡片
  static const nightVinylDark = Color(0xFF162422); // 夜间黑胶深色
  static const nightVinylMid = Color(0xFF31413D); // 夜间黑胶中等色
  static const nightWave = Color(0xFF203437); // 夜间波浪色

  // 岛屿海域与生长阶段
  static const islandSeaNightBlue = islandSeaNightMist;
  static const islandSeaDaySand = islandSeaDayDusk;
  static const islandBasinNightGreen = islandSeaGlowNight;
  static const islandBasinDayGreen = islandSeaGlowDay;
  static const islandBasinNightBlue = islandSeaHazeNight;
  static const islandBasinDayBlue = islandSeaHazeDay;
  static const islandRelitGold = islandRelit;

  // 织线关系色
  static const relationEcho = Color(0xFFB8A4D4);
  static const relationForeshadow = Color(0xFFA4B8D4);
  static const relationAftershock = Color(0xFF8FB8A4);
  static const relationParallel = Color(0xFF8E96A8);
  static const relationRescue = Color(0xFFD4A4A4);
  static const relationTide = Color(0xFFA4C4D4);
  static const relationOldLight = Color(0xFFB9B9A8);
}
