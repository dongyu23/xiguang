class FragmentConflictResolver {
  Map<String, dynamic> asConflictCopy(Map<String, dynamic> localPayload) {
    return {...localPayload, 'conflict_copy': true};
  }
}
