import 'package:flutter/material.dart';

import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../../../ui/spaces/starry_space.dart';

/// 织线页 — 可视化个人星图
///
/// 星点可拖拽建立连线。第一版用 StarrySpace + InteractiveViewer。
/// ⚠️ 手势冲突：双指→InteractiveViewer(缩放平移)；单指拖星点→GestureDetector
class StarmapPage extends StatelessWidget {
  const StarmapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 104),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Header(),
                const SizedBox(height: 20),
                // 星图画布
                Container(
                  height: 380,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: AppColors.gradientNight,
                  ),
                  child: const StarrySpace(),
                ),
                const SizedBox(height: 16),
                // TODO: 织线关系类型选择器
                Text('拖拽星点建立连线', style: AppText.bodyMuted),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('WEAVE', style: AppText.eyebrow),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text('织线', style: AppText.hero)),
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: AppColors.white.withValues(alpha: .86), shape: BoxShape.circle),
          child: const Icon(Icons.blur_circular_rounded, color: AppColors.ink)),
      ]),
      const SizedBox(height: 8),
      Text('星点之间，有一条细细的线。', style: AppText.body),
    ]);
  }
}
