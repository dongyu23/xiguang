import '../../shared/data/api_client.dart';

class MediaUploader {
  const MediaUploader(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> presign({
    required int fragmentId,
    required String fileName,
    required String contentType,
    required int fileSize,
  }) {
    return _api.post('/media/presign-upload', {
      'fragment_id': fragmentId,
      'file_name': fileName,
      'content_type': contentType,
      'file_size': fileSize,
    });
  }
}
