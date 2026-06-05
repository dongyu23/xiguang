import 'package:flutter/material.dart';

import '../../../../ui/spaces/starry_space.dart';

/// 沉浸式空间页 — 全屏 CustomPainter 星空默认为主
///
/// 用户可切换：星空 / 海 / 房间 / 岛屿
class SpacePage extends StatelessWidget {
  const SpacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: StarrySpace(starCount: 40)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              // TODO: 空间主题切换器（星空/海/房间/岛屿）
            ]),
          ),
        ),
      ]),
    );
  }
}
