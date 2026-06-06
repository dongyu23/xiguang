class AIRequest {
  const AIRequest({
    required this.mode,
    this.fragmentIds = const [],
    this.context,
  });

  final String mode;
  final List<int> fragmentIds;
  final String? context;
}
