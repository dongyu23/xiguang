import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// 监听 [scrollToTopSignalProvider]，信号变化时滚到顶部。
/// 自动管理 [ScrollController] 生命周期。
class ScrollToTop extends ConsumerStatefulWidget {
  const ScrollToTop({super.key, required this.builder});

  final Widget Function(BuildContext context, ScrollController controller) builder;

  @override
  ConsumerState<ScrollToTop> createState() => _ScrollToTopState();
}

class _ScrollToTopState extends ConsumerState<ScrollToTop> {
  late final _controller = ScrollController();
  int _lastSignal = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scrollToTopSignalProvider, (_, next) {
      if (next != _lastSignal && _controller.hasClients) {
        _lastSignal = next;
        _controller.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
    return widget.builder(context, _controller);
  }
}
