import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/primitives/overlay_snackbar.dart';
import '../../domain/update_state.dart';
import '../providers/app_update_providers.dart';

/// 在「我的」页或主动检查时弹出的更新对话。
///
/// 自动按 [appUpdateStateProvider] 状态切换内容：检查中 → 已是最新 / 有更新 →
/// 下载中（带进度）→ 准备安装。强更场景下隐藏关闭按钮。
Future<void> showAppUpdateSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (ctx) => const _AppUpdateSheet(),
  );
}

class _AppUpdateSheet extends ConsumerStatefulWidget {
  const _AppUpdateSheet();

  @override
  ConsumerState<_AppUpdateSheet> createState() => _AppUpdateSheetState();
}

class _AppUpdateSheetState extends ConsumerState<_AppUpdateSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 进入时立刻触发一次检查，让 UI 状态准确。
      ref.read(appUpdateStateProvider.notifier).checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appUpdateStateProvider);
    final nightMode = ref.watch(nightModeProvider);
    final canDismiss = !_isForceUpdate(state) && state is! UpdateDownloading;
    return PopScope(
      canPop: canDismiss,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(
              AppSpacing.s18, 0, AppSpacing.s18, AppSpacing.s18),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.s22, AppSpacing.s18, AppSpacing.s22, AppSpacing.s22),
          decoration:
              nightMode ? nightDecoration() : softDecoration(AppColors.white),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(_titleFor(state),
                      style: AppText.onNight(AppText.titleMedium, nightMode)),
                ),
                if (canDismiss)
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded,
                        color: nightMode
                            ? AppText.nightInkMuted
                            : AppColors.inkMuted),
                  ),
              ]),
              const SizedBox(height: AppSpacing.s12),
              _bodyFor(context, state, nightMode),
              const SizedBox(height: AppSpacing.s18),
              _actionsFor(context, state, canDismiss, nightMode),
            ],
          ),
        ),
      ),
    );
  }

  bool _isForceUpdate(UpdateState s) {
    if (s is UpdateAvailable) return s.mustForceUpdate;
    if (s is UpdateDownloading) {
      // 下载中不允许关闭
      return true;
    }
    if (s is UpdateReadyToInstall) return false;
    return false;
  }

  String _titleFor(UpdateState s) {
    return switch (s) {
      UpdateIdle() => '检查更新',
      UpdateChecking() => '正在查看是否有更新',
      UpdateUpToDate() => '已是最新版本',
      UpdateAvailable() => '有新版本可用',
      UpdateDownloading() => '正在下载新版本',
      UpdateReadyToInstall() => '可以安装新版本了',
      UpdateFailed() => '更新遇到问题',
    };
  }

  Widget _bodyFor(BuildContext context, UpdateState s, bool nightMode) {
    final body = AppText.onNight(AppText.body, nightMode);
    final caption = AppText.onNight(AppText.caption, nightMode);
    switch (s) {
      case UpdateChecking():
        return _CenteredLoader(label: '正在悄悄问一下服务器…', nightMode: nightMode);
      case UpdateUpToDate(:final currentBuild):
        return Text('当前已是最新版本（build $currentBuild）。', style: body);
      case UpdateAvailable(:final version, :final currentBuild):
        final mustForceUpdate =
            version.forceUpdate || currentBuild < version.minSupportedBuild;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${version.latestVersion}（build ${version.latestBuild}）',
              style: AppText.onNight(AppText.titleSmall, nightMode),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
                '当前 build $currentBuild · 大小 ${_formatSize(version.apkSizeBytes)}',
                style: caption),
            if (version.releaseNote.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s12),
              Text(version.releaseNote, style: body),
            ],
            if (mustForceUpdate) ...[
              const SizedBox(height: AppSpacing.s10),
              Text('这是一次必须更新的版本，更新后即可继续使用。',
                  style: caption.copyWith(color: AppColors.sunsetCoral)),
            ],
          ],
        );
      case UpdateDownloading(
          :final version,
          :final receivedBytes,
          :final totalBytes
        ):
        final progress = totalBytes > 0 ? receivedBytes / totalBytes : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${version.latestVersion}（build ${version.latestBuild}）',
                style: AppText.onNight(AppText.titleSmall, nightMode)),
            const SizedBox(height: AppSpacing.s12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: AppColors.teaGreen,
                backgroundColor: nightMode
                    ? AppColors.white.withValues(alpha: .14)
                    : AppColors.line,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${_formatSize(receivedBytes)} / ${_formatSize(totalBytes > 0 ? totalBytes : version.apkSizeBytes)}',
              style: caption,
            ),
          ],
        );
      case UpdateReadyToInstall(:final version):
        return Text(
          '${version.latestVersion}（build ${version.latestBuild}）已经准备好，'
          '点击下面的按钮唤起系统安装。',
          style: body,
        );
      case UpdateFailed(:final message):
        return Text(message,
            style: body.copyWith(color: AppColors.sunsetCoral));
      case UpdateIdle():
        return Text('点击"开始检查"看看有没有新版本。', style: body);
    }
  }

  Widget _actionsFor(
    BuildContext context,
    UpdateState s,
    bool canDismiss,
    bool nightMode,
  ) {
    switch (s) {
      case UpdateChecking():
        return const SizedBox.shrink();
      case UpdateUpToDate():
        return Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        );
      case UpdateAvailable(:final version, :final mustForceUpdate):
        return Row(children: [
          if (!mustForceUpdate)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  ref.read(appUpdateStateProvider.notifier).dismiss();
                  Navigator.of(context).pop();
                },
                child: const Text('稍后再说'),
              ),
            ),
          if (!mustForceUpdate) const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () =>
                  ref.read(appUpdateStateProvider.notifier).download(version),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('立即更新'),
            ),
          ),
        ]);
      case UpdateDownloading():
        return const SizedBox.shrink();
      case UpdateReadyToInstall():
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () =>
                ref.read(appUpdateStateProvider.notifier).install(),
            icon: const Icon(Icons.system_security_update_good_outlined,
                size: 18),
            label: const Text('打开系统安装器'),
          ),
        );
      case UpdateFailed():
        return Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后再说'),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                ref.read(appUpdateStateProvider.notifier).checkForUpdate();
              },
              child: const Text('重试'),
            ),
          ),
        ]);
      case UpdateIdle():
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () =>
                ref.read(appUpdateStateProvider.notifier).checkForUpdate(),
            child: const Text('开始检查'),
          ),
        );
    }
  }
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader({required this.label, this.nightMode = false});
  final String label;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      child: Row(children: [
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
            child:
                Text(label, style: AppText.onNight(AppText.body, nightMode))),
      ]),
    );
  }
}

String _formatSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  double value = bytes.toDouble();
  int i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return '${value.toStringAsFixed(value >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

/// 用于在导航前的辅助：把更新失败时的提示也通过 overlay snackbar 暴露，
/// 让 sheet 关闭后还能看到提示。
void notifyUpdateFailure(BuildContext context, String message) {
  showOverlaySnackBar(
    context,
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
