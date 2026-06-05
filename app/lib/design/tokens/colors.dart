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

  // 主题色
  static const teaGreen = Color(0xFF72A58F);     // 茶绿 — 平静、生长
  static const mistBlue = Color(0xFF9EBBCC);     // 雾蓝 — 微光、失眠
  static const sunsetCoral = Color(0xFFE9A18B);  // 珊瑚 — 被击中、期待
  static const lilac = Color(0xFFD9CCE8);        // 淡紫 — 说不清、氛围

  // 情绪色点（对应 emotion 枚举）
  static const emotionCalm = teaGreen;
  static const emotionHappy = Color(0xFFF0C78E);
  static const emotionTired = mistBlue;
  static const emotionAnxious = sunsetCoral;
  static const emotionLost = Color(0xFFC4C4C4);
  static const emotionStruck = Color(0xFFE8B88A);
  static const emotionChaos = lilac;
  static const emotionUnclear = Color(0xFFB8C5B2);

  /// 情绪名 → 颜色映射
  static Color emotionColor(String emotion) {
    return switch (emotion) {
      '平静' => emotionCalm,
      '开心' => emotionHappy,
      '疲惫' => emotionTired,
      '焦虑' => emotionAnxious,
      '失落' => emotionLost,
      '被击中' => emotionStruck,
      '混乱' => emotionChaos,
      _ => emotionUnclear,
    };
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
}
