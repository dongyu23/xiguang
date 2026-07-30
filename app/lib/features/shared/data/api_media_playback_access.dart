import '../domain/media_playback_access.dart';
import 'api_client.dart';

class ApiMediaPlaybackAccess implements MediaPlaybackAccess {
  const ApiMediaPlaybackAccess(this._api);

  final ApiClient _api;

  @override
  MediaPlaybackRequest resolve(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('users/')) {
      return MediaPlaybackRequest(source: trimmed);
    }
    return MediaPlaybackRequest(
      source: _api.mediaObjectUrl(trimmed),
      headers: _api.mediaAuthorizationHeaders,
    );
  }
}
