import '../../shared/data/api_client.dart';

class MediaUploader {
  const MediaUploader(this._api);

  final ApiClient _api;

  /// 通过后端代理上传文件到 MinIO，返回 {object_key, file_url, ...}。
  Future<Map<String, dynamic>> uploadFile({
    required int fragmentId,
    required String filePath,
    required String fileName,
  }) {
    return _api.uploadFile(
      '/media/upload',
      filePath: filePath,
      fileName: fileName,
      fragmentId: fragmentId,
    );
  }

  /// 从内存字节上传（用于 Web 端 base64 转换后的数据）。
  Future<Map<String, dynamic>> uploadBytes({
    required int fragmentId,
    required List<int> bytes,
    required String fileName,
  }) {
    return _api.uploadBytes(
      '/media/upload',
      bytes: bytes,
      fileName: fileName,
      fragmentId: fragmentId,
    );
  }
}
