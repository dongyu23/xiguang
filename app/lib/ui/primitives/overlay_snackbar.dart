import 'package:flutter/material.dart';
import '../../design/tokens/spacing.dart';

/// 显示 SnackBar，自动关闭当前正在显示的消息（覆盖而非排队）。
///
/// 浮动样式的 SnackBar 默认会落在屏幕底部，但应用底部有一个浮岛导航（高
/// 64px + 10px 偏移 + safe area），原始 SnackBar 会和导航重叠。
/// 这里在调用方没有自定义 margin 时，自动留出底部导航空间，避免视觉冲突。
void showOverlaySnackBar(BuildContext context, SnackBar snackBar) {
  final effective = _withSafeBottomMargin(context, snackBar);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(effective);
}

SnackBar _withSafeBottomMargin(BuildContext context, SnackBar snackBar) {
  if (snackBar.behavior != SnackBarBehavior.floating) return snackBar;
  if (snackBar.margin != null) return snackBar;
  final bottomPadding = MediaQuery.paddingOf(context).bottom;
  // 浮岛导航高度 64 + 浮岛底部偏移 10 + safe area + 12 视觉间距。
  final navClearance = 64 + 10 + bottomPadding + 12;
  return SnackBar(
    content: snackBar.content,
    backgroundColor: snackBar.backgroundColor,
    elevation: snackBar.elevation,
    margin: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, navClearance),
    padding: snackBar.padding,
    width: snackBar.width,
    shape: snackBar.shape,
    hitTestBehavior: snackBar.hitTestBehavior,
    behavior: SnackBarBehavior.floating,
    action: snackBar.action,
    actionOverflowThreshold: snackBar.actionOverflowThreshold,
    showCloseIcon: snackBar.showCloseIcon,
    closeIconColor: snackBar.closeIconColor,
    duration: snackBar.duration,
    animation: snackBar.animation,
    onVisible: snackBar.onVisible,
    dismissDirection: snackBar.dismissDirection,
    clipBehavior: snackBar.clipBehavior,
  );
}
