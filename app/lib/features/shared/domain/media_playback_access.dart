class MediaPlaybackRequest {
  const MediaPlaybackRequest({required this.source, this.headers});

  final String source;
  final Map<String, String>? headers;
}

abstract interface class MediaPlaybackAccess {
  MediaPlaybackRequest resolve(String value);
}
