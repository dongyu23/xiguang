import '../../shared/data/api_client.dart';
import '../domain/timeline_query.dart';

class TimelineApi {
  const TimelineApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> list(TimelineQuery query) {
    return _api.get('/timeline', query: {
      if (query.cursor != null) 'cursor': query.cursor,
      if (query.emotion != null) 'emotion': query.emotion,
      if (query.mediaType != null) 'media_type': query.mediaType,
      'limit': query.limit,
    });
  }
}
