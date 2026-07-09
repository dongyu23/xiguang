/// 后端 `GET /api/v1/app/version` 返回的版本元信息。
///
/// 关键字段是 [latestBuild]——客户端只用 build 数字比对，不解析 [latestVersion]。
class AppVersion {
  const AppVersion({
    required this.latestVersion,
    required this.latestBuild,
    required this.minSupportedBuild,
    required this.downloadUrl,
    required this.sha256,
    required this.apkSizeBytes,
    required this.releaseNote,
    required this.forceUpdate,
    required this.publishedAt,
  });

  final String latestVersion;
  final int latestBuild;
  final int minSupportedBuild;
  final String downloadUrl;
  final String sha256;
  final int apkSizeBytes;
  final String releaseNote;
  final bool forceUpdate;
  final DateTime? publishedAt;

  static AppVersion fromJson(Map<String, dynamic> json) {
    return AppVersion(
      latestVersion: json['latest_version'] as String? ?? '',
      latestBuild: (json['latest_build'] as num?)?.toInt() ?? 0,
      minSupportedBuild: (json['min_supported_build'] as num?)?.toInt() ?? 0,
      downloadUrl: json['download_url'] as String? ?? '',
      sha256: (json['sha256'] as String? ?? '').toLowerCase(),
      apkSizeBytes: (json['apk_size_bytes'] as num?)?.toInt() ?? 0,
      releaseNote: json['release_note'] as String? ?? '',
      forceUpdate: json['force_update'] as bool? ?? false,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
    );
  }
}
