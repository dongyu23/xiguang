import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/colors.dart';
import '../../design/tokens/motion.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/typography.dart';
import '../../design/tokens/spacing.dart';
import 'xiguang_bottom_sheet.dart';
import 'xiguang_button.dart';

/// 后端连接状态
enum BackendStatus { unknown, checking, connected, disconnected }

/// 连接状态检测 Provider
///
/// autoDispose：离开登录/注册页后自动释放，停止无意义的 healthz 轮询。
final backendStatusProvider =
    StateNotifierProvider.autoDispose<BackendStatusNotifier, BackendStatus>(
        (ref) {
  return BackendStatusNotifier(ref);
});

class BackendStatusNotifier extends StateNotifier<BackendStatus> {
  BackendStatusNotifier(this._ref) : super(BackendStatus.unknown) {
    // 延迟到下一事件循环再检查，避免和登录页首帧 build / layout 竞争。
    Future.delayed(Duration.zero, check);
  }

  final Ref _ref;
  Dio? _dio;

  Future<void> check() async {
    if (state == BackendStatus.checking) return;
    state = BackendStatus.checking;

    try {
      final baseUrl = _ref.read(apiBaseUrlProvider).valueOrNull ?? '';
      if (baseUrl.isEmpty) {
        state = BackendStatus.disconnected;
        return;
      }

      // 构建 healthz URL（去掉 /api/v1 后缀，加上 /healthz）
      final uri = Uri.tryParse(baseUrl);
      if (uri == null) {
        state = BackendStatus.disconnected;
        return;
      }

      final healthUrl = '${uri.scheme}://${uri.host}:${uri.port}/healthz';
      _dio ??= Dio(
        BaseOptions(connectTimeout: AppTiming.healthzProbeTimeout),
      );

      final response = await _dio!.get(healthUrl);
      if (response.statusCode == 200) {
        state = BackendStatus.connected;
      } else {
        state = BackendStatus.disconnected;
      }
    } catch (_) {
      state = BackendStatus.disconnected;
    }
  }
}

/// 登录/注册页面的后端地址切换按钮
class BackendUrlTile extends ConsumerWidget {
  const BackendUrlTile({
    super.key,
    this.loading = false,
    this.onBeginEdit,
  });
  final bool loading;
  final VoidCallback? onBeginEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = NightTheme.of(context);
    final baseUrl = ref.watch(apiBaseUrlProvider).valueOrNull ?? '';
    final host = Uri.tryParse(baseUrl)?.host ?? baseUrl;
    final status = ref.watch(backendStatusProvider);

    return Center(
      child: TextButton.icon(
        onPressed: loading
            ? null
            : () {
                onBeginEdit?.call();
                _showUrlSheet(context, ref);
              },
        icon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_outlined, size: 15, color: theme.foregroundMuted),
            const SizedBox(width: AppSpacing.s6),
            _StatusDot(status: status),
          ],
        ),
        label: Text(host.isNotEmpty ? host : '后端地址',
            style: AppText.caption.copyWith(color: theme.foregroundMuted)),
      ),
    );
  }

  void _showUrlSheet(BuildContext context, WidgetRef ref) {
    FocusManager.instance.primaryFocus?.unfocus();
    final controller = TextEditingController(
        text: ref.read(apiBaseUrlProvider).valueOrNull ?? '');
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final theme = NightTheme.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: XiguangBottomSheet(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('后端地址',
                    style:
                        AppText.titleMedium.copyWith(color: theme.foreground)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'https://api.frozenfish.cn/api/v1',
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                Row(children: [
                  Expanded(
                    child: XiguangButton(
                      label: '恢复默认',
                      variant: XiguangButtonVariant.secondary,
                      onPressed: () async {
                        final navigator = Navigator.of(ctx);
                        await ref.read(apiBaseUrlProvider.notifier).reset();
                        navigator.pop();
                        ref.read(backendStatusProvider.notifier).check();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: XiguangButton(
                      label: '保存',
                      onPressed: () async {
                        final navigator = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(ctx);
                        final value = controller.text.trim();
                        try {
                          await ref
                              .read(apiBaseUrlProvider.notifier)
                              .save(value);
                          navigator.pop();
                          ref.read(backendStatusProvider.notifier).check();
                        } on ArgumentError catch (e) {
                          messenger.showSnackBar(SnackBar(
                            content: Text(e.message.toString()),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      controller.dispose();
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }
}

/// 状态指示圆点
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final BackendStatus status;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.normal,
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        boxShadow: status == BackendStatus.connected
            ? [
                BoxShadow(
                  color: _color.withValues(alpha: .4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }

  Color get _color {
    switch (status) {
      case BackendStatus.connected:
        return AppColors.teaGreen; // 绿色 — 使用主题色
      case BackendStatus.disconnected:
        return AppColors.sunsetCoral; // 红色 — 使用主题色
      case BackendStatus.checking:
        return AppColors.inkMuted.withValues(alpha: .5); // 灰色闪烁
      case BackendStatus.unknown:
        return AppColors.inkMuted.withValues(alpha: .3); // 浅灰
    }
  }
}
