import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../design/tokens/motion.dart';
import '../../shared/data/api_client.dart';
import '../domain/app_version.dart';

/// 在线更新的数据层：拉取版本元信息、下载 APK、触发系统安装器。
///
/// 故意没用现有的 dio 拦截器去打 baseUrl——下载使用绝对 [AppVersion.downloadUrl]，
/// 拼接由后端控制，客户端不修改。
class AppUpdateRepository {
  AppUpdateRepository(this._api);

  final ApiClient _api;
  Dio? _downloader;

  Future<int> currentBuildNumber() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  /// 调 `/app/version`。无版本或网络错误时返回 null。
  Future<AppVersion?> fetchLatest({
    String channel = 'stable',
    String platform = 'android',
  }) async {
    try {
      final body = await _api.get('/app/version', query: {
        'channel': channel,
        'platform': platform,
      });
      // 后端 data 为 null 时 _unwrap 会返回 {value: null}；区分一下。
      if (body.isEmpty ||
          body['value'] == null && body['latest_build'] == null) {
        return null;
      }
      final raw = body.containsKey('latest_build')
          ? body
          : (body['value'] as Map<String, dynamic>? ?? const {});
      if (raw.isEmpty) return null;
      return AppVersion.fromJson(raw);
    } on DioException catch (e) {
      developer.log('fetchLatest dio failed', error: e);
      return null;
    } catch (e) {
      developer.log('fetchLatest failed', error: e);
      return null;
    }
  }

  /// 下载 APK 到外部缓存目录。返回本地文件路径。
  /// [onProgress] 接收 (received, total) 字节数。
  Future<String> downloadApk(
    AppVersion version, {
    required void Function(int received, int total) onProgress,
  }) async {
    final saveDir = await _saveDirectory();
    final fileName = _safeFileName(version);
    final target = p.join(saveDir, fileName);
    // 重复进入时清掉旧文件，避免半截下载残留。
    final f = File(target);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {}
    }
    _downloader ??= Dio(BaseOptions(
      connectTimeout: AppTiming.updateConnectTimeout,
      receiveTimeout: AppTiming.updateReceiveTimeout,
    ));
    await _downloader!.download(
      version.downloadUrl,
      target,
      onReceiveProgress: onProgress,
      options: Options(
        followRedirects: true,
        validateStatus: (s) => s != null && s >= 200 && s < 400,
      ),
    );
    return target;
  }

  /// 调起系统安装器。需要用户在系统设置里授权"来自此来源的安装"。
  Future<void> openInstaller(String apkPath) async {
    final result = await OpenFilex.open(apkPath);
    if (result.type != ResultType.done) {
      throw StateError(
          'open_installer_failed:${result.type}:${result.message}');
    }
  }

  Future<String> _saveDirectory() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) return dir.path;
    }
    final tmp = await getTemporaryDirectory();
    return tmp.path;
  }

  String _safeFileName(AppVersion v) {
    // 用 build_number 作后缀确保不同构建分开存储。
    return 'xiguang-update-${v.latestBuild}.apk';
  }
}
