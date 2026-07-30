import 'ai_request.dart';

class AISourceReference {
  const AISourceReference(
      {required this.fragmentId, required this.excerpt, required this.emotion});
  final int fragmentId;
  final String excerpt;
  final String emotion;
  factory AISourceReference.fromJson(Map<String, dynamic> json) =>
      AISourceReference(
          fragmentId: (json['fragment_id'] as num).toInt(),
          excerpt: json['excerpt'] as String? ?? '',
          emotion: json['emotion'] as String? ?? '说不清');
}

class AISummaryPoint {
  const AISummaryPoint({required this.text, required this.sourceFragmentIds});
  final String text;
  final List<int> sourceFragmentIds;
  factory AISummaryPoint.fromJson(Map<String, dynamic> json) => AISummaryPoint(
      text: json['text'] as String? ?? '',
      sourceFragmentIds:
          (json['source_fragment_ids'] as List<dynamic>? ?? const [])
              .map((id) => (id as num).toInt())
              .toList());
  Map<String, dynamic> toJson() =>
      {'text': text, 'source_fragment_ids': sourceFragmentIds};
}

class AISummaryDraft {
  const AISummaryDraft(
      {required this.status,
      required this.scope,
      this.message = '',
      this.requestId = 0,
      this.sourceCount = 0,
      this.sources = const [],
      this.summary = '',
      this.keyPoints = const [],
      this.titleCandidates = const [],
      this.why = ''});
  final String status;
  final String message;
  final int requestId;
  final AIScope scope;
  final int sourceCount;
  final List<AISourceReference> sources;
  final String summary;
  final List<AISummaryPoint> keyPoints;
  final List<String> titleCandidates;
  final String why;
  factory AISummaryDraft.fromJson(
          Map<String, dynamic> json, AIScope fallback) =>
      AISummaryDraft(
          status: json['status'] as String? ?? 'error',
          message: json['message'] as String? ?? '',
          requestId: (json['request_id'] as num?)?.toInt() ?? 0,
          scope: fallback,
          sourceCount: (json['source_count'] as num?)?.toInt() ?? 0,
          sources: (json['sources'] as List<dynamic>? ?? const [])
              .map((e) => AISourceReference.fromJson(e as Map<String, dynamic>))
              .toList(),
          summary: json['summary'] as String? ?? '',
          keyPoints: (json['key_points'] as List<dynamic>? ?? const [])
              .map((e) => AISummaryPoint.fromJson(e as Map<String, dynamic>))
              .toList(),
          titleCandidates:
              (json['title_candidates'] as List<dynamic>? ?? const [])
                  .map((e) => '$e')
                  .toList(),
          why: json['why'] as String? ?? '');
}

class AIResponse {
  const AIResponse(
      {this.keywords = const [],
      this.emotionTitle,
      this.summary,
      this.suggestions = const []});
  final List<String> keywords;
  final String? emotionTitle;
  final String? summary;
  final List<int> suggestions;
}
