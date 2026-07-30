import 'package:flutter/material.dart';

/// 隙光动效体系 — 呼吸感、不急促、不打扰
///
/// 所有业务 Widget 的动效时长和曲线必须从这里取，不允许写裸 Duration / Curves。
///
/// 豁免范围（详见 CLAUDE.md §9.14 "动效令牌强约束"）：
///   1. lib/ui/spaces/ 下所有沉浸式空间自绘文件；
///   2. 任意业务文件，只要在顶部首行（package 导入之后）声明
///      `// MOTION_EXEMPT: self-painted` 标记，并紧接 2-5 行说明豁免理由。
/// 没有标记的文件，本约束依然适用。
///
/// 网络超时、Timer.periodic、Future.delayed 的非动效用法（重试退避、连接超时、
/// 录音计数器等）不在本约束范围内——本文件只管"视觉变化的节奏"。
class AppMotion {
  AppMotion._();

  // 时长 — 从快到慢，按使用场景分档
  /// 极快状态切换（chip 选中、AnimatedContainer 状态翻转）
  static const Duration quick = Duration(milliseconds: 180);

  /// 快速 UI 反馈（按钮按下、轻量 opacity）
  static const Duration fast = Duration(milliseconds: 200);

  /// 常规过渡（页面元素切换、AnimatedSwitcher）
  static const Duration normal = Duration(milliseconds: 260);

  /// 路由级过渡（导航 pill、tab 平移）
  static const Duration pageSwap = Duration(milliseconds: 320);

  /// 慢速过渡（强调动作、滚动定位）
  static const Duration slow = Duration(milliseconds: 400);

  /// 水波点击反馈
  static const Duration ripple = Duration(milliseconds: 600);

  /// 开屏/Hero 入场
  static const Duration linger = Duration(milliseconds: 1500);

  /// 岛屿跨越生长阶段时的压缩、跃起与回弹。
  static const Duration islandGrowth = Duration(milliseconds: 920);

  /// 新建小岛预览从雾中浮现的时长。
  static const Duration islandCreationReveal = Duration(milliseconds: 720);

  /// 进入群岛后选中岛屿的落点动画。
  static const Duration islandArrival = Duration(milliseconds: 760);

  /// 从群岛进入岛上时，岛体平移并放大的连续旅程。
  static const Duration islandTravel = Duration(milliseconds: 520);

  static const Duration islandCanvasTransition = Duration(milliseconds: 760);
  static const Duration islandReveal = Duration(milliseconds: 720);
  static const Duration selection = Duration(milliseconds: 220);
  static const Duration islandModeForward = Duration(milliseconds: 360);

  /// shimmer 高光扫过周期
  static const Duration shimmer = Duration(milliseconds: 1800);

  /// SnackBar/Toast 停留时长
  static const Duration snackbar = Duration(milliseconds: 2000);

  /// 呼吸感周期（按钮呼吸、星点闪烁、慢速 ambient）
  static const Duration breath = Duration(milliseconds: 3000);

  /// 页面切换动画（GoRoute 过渡）
  static const Duration pageTransition = Duration(milliseconds: 260);

  /// 黑胶与沉浸空间的慢速环境动效。
  static const Duration vinylSlowOrbit = Duration(milliseconds: 5600);
  static const Duration vinylOrbit = Duration(milliseconds: 4200);
  static const Duration vinylSettle = Duration(milliseconds: 360);
  static const Duration vinylAmbient = Duration(milliseconds: 4800);
  static const Duration oceanAmbient = Duration(seconds: 6);
  static const Duration starryAmbient = Duration(seconds: 8);
  static const Duration canvasAmbient = Duration(milliseconds: 11000);

  // 曲线
  /// 进入加速（开屏退场、抽屉收起）
  static const Curve easeIn = Curves.easeInCubic;

  /// 默认过渡（绝大多数 UI 状态切换、滚动定位）
  static const Curve easeOut = Curves.easeOutCubic;

  /// 平滑往返（路由 pill、AnimatedPositioned）
  static const Curve microMovement = Curves.easeInOutCubic;

  /// 呼吸/波动专用（正弦缓动）
  static const Curve sine = Curves.easeInOutSine;

  /// 岛屿生长阶段跃迁的弹性回落。
  static const Curve growthSpring = Curves.elasticOut;
}

/// 非视觉流程的时间配置。业务代码不得直接创建 Duration。
class AppTiming {
  AppTiming._();

  static const Duration editorAutoSaveDebounce = Duration(milliseconds: 800);
  static const Duration editorAutoSaveRetry = Duration(milliseconds: 250);
  static const Duration timelineSearchDebounce = Duration(milliseconds: 280);
  static const Duration audioMeterTick = Duration(seconds: 1);
  static const Duration backendConnectionTimeout = Duration(seconds: 5);

  /// healthz 连通性探测专用短超时（轻量端点，无需 5s）
  static const Duration healthzProbeTimeout = Duration(seconds: 2);
  static const Duration authRequestTimeout = Duration(seconds: 8);
  static const Duration updateCheckDelay = Duration(seconds: 30);
  static const Duration themeModePoll = Duration(minutes: 1);
  static const Duration syncEveryFiveMinutes = Duration(minutes: 5);
  static const Duration syncHourly = Duration(hours: 1);
  static const Duration tokenRefreshSkew = Duration(minutes: 1);
  static const Duration fallbackTokenLifetime = Duration(minutes: 15);
  static const Duration apiConnectTimeout = Duration(seconds: 10);
  static const Duration apiReceiveTimeout = Duration(seconds: 15);
  static const Duration apiSendTimeout = Duration(seconds: 10);
  static const Duration updateConnectTimeout = Duration(seconds: 15);
  static const Duration updateReceiveTimeout = Duration(minutes: 5);
  static const Duration aiRequestTimeout = Duration(seconds: 70);
  static const Duration captureReminderDelay = Duration(days: 7);
  static const Duration oldLightAge = Duration(days: 30);
  static const Duration fragmentPickerWeek = Duration(days: 7);
  static const Duration fragmentPickerMonth = Duration(days: 30);
  static const Duration oldLightReminderDelay = Duration(days: 3);
  static const Duration islandQuietReminderDelay = Duration(days: 30);
  static const Duration reminderMinimumLead = Duration(minutes: 2);
  static const Duration paymentPurchaseTimeout = Duration(minutes: 2);
  static const Duration paymentStatusPoll = Duration(seconds: 2);
  static const Duration appleRestoreCollection = Duration(seconds: 3);
  static const Duration recentWeek = Duration(days: 7);
  static const Duration recentMonth = Duration(days: 30);
  static const Duration timelineSearchDebounce = Duration(milliseconds: 280);

  static Duration retryBackoff(int attempts) {
    final milliseconds = (200 * (1 << attempts)).clamp(0, 3000);
    return Duration(milliseconds: milliseconds);
  }
}
