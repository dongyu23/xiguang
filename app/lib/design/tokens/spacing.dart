/// 隙光留白体系 — 大留白、低信息密度
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// 页面水平内边距
  static double pageHorizontal(double width) => width > 520 ? 34 : 22;

  /// 卡片最大宽度
  static const double cardMaxWidth = 560;

  /// 底部导航外边距
  static const double navBarMargin = 18;
}
