import 'app_version.dart';

/// 客户端在线更新的运行时状态。
sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate({required this.currentBuild});
  final int currentBuild;
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable({required this.version, required this.currentBuild});
  final AppVersion version;
  final int currentBuild;

  bool get mustForceUpdate =>
      version.forceUpdate || currentBuild < version.minSupportedBuild;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading({
    required this.version,
    required this.receivedBytes,
    required this.totalBytes,
  });
  final AppVersion version;
  final int receivedBytes;
  final int totalBytes;
  double? get progress {
    if (totalBytes <= 0) return null;
    return receivedBytes / totalBytes;
  }
}

class UpdateReadyToInstall extends UpdateState {
  const UpdateReadyToInstall({required this.version, required this.filePath});
  final AppVersion version;
  final String filePath;
}

class UpdateFailed extends UpdateState {
  const UpdateFailed({required this.message});
  final String message;
}
