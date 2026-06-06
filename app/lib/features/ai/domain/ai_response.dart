class AIResponse {
  const AIResponse({
    this.keywords = const [],
    this.emotionTitle,
    this.summary,
    this.suggestions = const [],
  });

  final List<String> keywords;
  final String? emotionTitle;
  final String? summary;
  final List<int> suggestions;
}
