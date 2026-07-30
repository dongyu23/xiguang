/// 隙光留白体系 — 大留白、低信息密度
///
/// 两套并存：
/// - `xs/sm/md/lg/xl/xxl` 是按 4 倍数推荐的"主节奏"，新代码优先用这套。
/// - `s2/s6/s10/s12/s14/s18/s22/s28` 是项目里实际在用的细粒度补充值（2px 步进），
///   把它们也 token 化，意图是「所有间距引用 token 而不出现裸数字」。
///   修改一处即可全局生效——这是设计规范化的根本目标。
class AppSpacing {
  AppSpacing._();

  // ── 主节奏（4 倍数推荐刻度） ──
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // ── 细粒度补充（项目实际在用的中间值） ──
  static const double s1 = 1;
  static const double s2 = 2;
  static const double s3 = 3;
  static const double s5 = 5;
  static const double s6 = 6;
  static const double s7 = 7;
  static const double s9 = 9;
  static const double s10 = 10;
  static const double s11 = 11;
  static const double s12 = 12;
  static const double s13 = 13;
  static const double s14 = 14;
  static const double s15 = 15;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s22 = 22;
  static const double s28 = 28;

  /// 页面底部留白，避开底部浮岛导航 + 系统手势条。
  static const double pageBottomNav = 104;

  /// 捕光编辑器底部操作区和系统手势区的合计避让。
  static const double captureComposerClearance = 126;

  /// 路由级浮层避开底部导航所需的空间。
  static const double routeOverlayClearance = 100;

  /// 时间河流进入批量选择后，为底部操作栏保留的空间。
  static const double selectionToolbarClearance = 156;

  /// 小宇宙列表避开底部模式切换条的空间。
  static const double universeListBottom = 76;

  /// 支线画布缩放和平移时保留的边界。
  static const double graphBoundary = 80;

  /// 页面水平内边距
  static double pageHorizontal(double width) => width > 520 ? 34 : 22;

  /// 卡片最大宽度
  static const double cardMaxWidth = 560;

  /// 底部导航外边距
  static const double navBarMargin = 18;

  /// 卡片内边距
  static const double cardPadding = 16;

  /// 小组件内边距
  static const double widgetPadding = 12;

  /// 标签内边距
  static const double tagPadding = 8;

  /// 按钮内边距
  static const double buttonPadding = 14;
}
