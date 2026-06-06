class RelationLocalDao {
  final List<Map<String, dynamic>> _drafts = [];

  Future<void> saveDraft(Map<String, dynamic> draft) async {
    _drafts.add(draft);
  }
}
