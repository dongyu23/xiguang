import 'package:flutter_riverpod/flutter_riverpod.dart';

class RelationDraft {
  const RelationDraft({this.sourceId, this.targetId, this.type = 'reminds_me'});

  final int? sourceId;
  final int? targetId;
  final String type;
}

final relationDraftProvider = StateProvider<RelationDraft>((ref) {
  return const RelationDraft();
});
