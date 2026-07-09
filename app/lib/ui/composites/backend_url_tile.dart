import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../design/tokens/colors.dart';
import '../../design/tokens/motion.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/typography.dart';
import '../../design/tokens/spacing.dart';

/// 后端连接状态
enum BackendStatus { unknown, checking, connected, disconnected }

/// 连接状态检测 Provider
final backendStatusProvider =
    StateNotifierProvider<BackendStatusNotifier, BackendStatus>((ref) {
  return BackendStatusNotifier(ref);
});

class BackendStatusNotifier extends StateNotifier<BackendStatus> {
  BackendStatusNotifier(this._ref) : super(BackendStatus.unknown) {
    check();
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
      _dio ??= Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));

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
    this.nightMode = false,
    this.onBeginEdit,
  });
  final bool loading;
  final bool nightMode;
  final VoidCallback? onBeginEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Icon(Icons.dns_outlined,
                size: 15,
                color: nightMode
                    ? AppColors.white.withValues(alpha: .50)
                    : AppColors.inkMuted),
            const SizedBox(width: AppSpacing.s6),
            _StatusDot(status: status),
          ],
        ),
        label: Text(host.isNotEmpty ? host : '后端地址',
            style: AppText.caption.copyWith(
                color: nightMode
                    ? AppColors.white.withValues(alpha: .50)
                    : AppColors.inkMuted)),
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
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s22, AppSpacing.s12,
                  AppSpacing.s22, AppSpacing.s22),
              decoration: BoxDecoration(
                color: nightMode ? AppColors.nightSurfaceHigh : AppColors.white,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: nightMode
                          ? AppColors.white.withValues(alpha: .20)
                          : AppColors.line,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('后端地址',
                      style: AppText.onNight(AppText.titleMedium, nightMode)),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'http://192.168.1.2:8088/api/v1',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final navigator = Navigator.of(ctx);
                          await ref.read(apiBaseUrlProvider.notifier).reset();
                          navigator.pop();
                          ref.read(backendStatusProvider.notifier).check();
                        },
                        child: const Text('恢复默认'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: FilledButton(
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
                        child: const Text('保存'),
                      ),
                    ),
                  ]),
                ],
              ),
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
