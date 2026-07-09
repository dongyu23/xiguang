import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/app_update_repository.dart';
import '../../domain/app_version.dart';
import '../../domain/update_state.dart';

final appUpdateRepositoryProvider = Provider<AppUpdateRepository>((ref) {
  return AppUpdateRepository(ref.watch(apiClientProvider));
});

/// 当前更新流程的状态机。
final appUpdateStateProvider =
    StateNotifierProvider<AppUpdateNotifier, UpdateState>((ref) {
  return AppUpdateNotifier(ref);
});

/// 「我的」tab 上的红点标志位。来自 piggyback meta 或主动检查。
final appUpdateBadgeProvider = StateProvider<bool>((ref) => false);

class AppUpdateNotifier extends StateNotifier<UpdateState> {
  AppUpdateNotifier(this._ref) : super(const UpdateIdle());

  final Ref _ref;

  /// 主动检查更新。[silent] 为 true 时不切换为 checking 状态，避免启动后悄悄检查时干扰 UI。
  Future<UpdateState> checkForUpdate({bool silent = false}) async {
    final repo = _ref.read(appUpdateRepositoryProvider);
    if (!silent) state = const UpdateChecking();
    final current = await repo.currentBuildNumber();
    final latest = await repo.fetchLatest();
    if (latest == null) {
      final next = silent ? state : UpdateUpToDate(currentBuild: current);
      if (!silent) state = next;
      return next;
    }
    _ref.read(appUpdateBadgeProvider.notifier).state =
        latest.latestBuild > current;
    final UpdateState next;
    if (latest.latestBuild > current) {
      next = UpdateAvailable(version: latest, currentBuild: current);
    } else {
      next = UpdateUpToDate(currentBuild: current);
    }
    if (!silent || state is UpdateChecking) {
      state = next;
    }
    return next;
  }

  Future<void> download(AppVersion version) async {
    final repo = _ref.read(appUpdateRepositoryProvider);
    final current = await repo.currentBuildNumber();
    state = UpdateDownloading(
      version: version,
      receivedBytes: 0,
      totalBytes: version.apkSizeBytes,
    );
    try {
      final path = await repo.downloadApk(version, onProgress: (recv, total) {
        if (!mounted) return;
        state = UpdateDownloading(
          version: version,
          receivedBytes: recv,
          totalBytes: total > 0 ? total : version.apkSizeBytes,
        );
      });
      if (!mounted) return;
      state = UpdateReadyToInstall(version: version, filePath: path);
    } catch (e) {
      if (!mounted) return;
      state = UpdateFailed(message: '下载失败：$e');
      // 状态机里保留失败原因，UI 可以引导重试
      _ref.read(appUpdateBadgeProvider.notifier).state =
          version.latestBuild > current;
    }
  }

  Future<void> install() async {
    final current = state;
    if (current is! UpdateReadyToInstall) return;
    try {
      await _ref
          .read(appUpdateRepositoryProvider)
          .openInstaller(current.filePath);
    } catch (e) {
      state = UpdateFailed(message: '调起安装器失败：$e');
    }
  }

  /// 用户在非强更弹窗里选择"稍后" — 重置状态但保留红点，下次仍能再点开。
  void dismiss() {
    state = const UpdateIdle();
  }
}
