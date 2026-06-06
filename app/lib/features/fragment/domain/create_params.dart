class CreateFragmentParams {
  const CreateFragmentParams({
    required this.contentText,
    required this.emotion,
    this.tagNames = const [],
    this.mediaPaths = const [],
  });

  final String contentText;
  final String emotion;
  final List<String> tagNames;
  final List<String> mediaPaths;
}
