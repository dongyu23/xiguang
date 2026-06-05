import 'package:flutter/material.dart';

/// 隙光动效体系 — 呼吸感、不急促、不打扰
class AppMotion {
  AppMotion._();

  // 时长
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration breath = Duration(milliseconds: 3000);  // 呼吸周期
  static const Duration ripple = Duration(milliseconds: 600);

  // 曲线
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve microMovement = Curves.easeInOutCubic;
  static const Curve sine = Curves.easeInOutSine;  // 需 flutter ≥ 3.22

  // 页面切换动画时长
  static const Duration pageTransition = Duration(milliseconds: 260);
}
