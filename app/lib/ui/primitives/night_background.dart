import 'package:flutter/material.dart';

import '../../design/themes/extensions/night_theme.dart';

/// 夜间模式背景色占位 — 解决新页面进入时 AtmosphereBackground 延迟一帧导致的闪烁
///
/// 放在 Stack 最底层，确保首帧就有正确的背景色。
class NightBackgroundPlaceholder extends StatelessWidget {
  const NightBackgroundPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final nightTheme = NightTheme.of(context);
    return ColoredBox(color: nightTheme.background);
  }
}
