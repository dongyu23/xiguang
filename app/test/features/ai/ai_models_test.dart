import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/ai/domain/ai_request.dart';
import 'package:xiguang/features/ai/domain/ai_response.dart';

void main() {
  test('AI scope only serializes the explicitly selected range', () {
    expect(const AIScope.fragments([2, 7]).toJson(), {
      'type': 'fragments',
      'fragment_ids': [2, 7],
    });
    expect(const AIScope.island(9).toJson(), {
      'type': 'island',
      'island_id': 9,
    });
    expect(const AIScope.range(30).toJson(), {
      'type': 'range',
      'range_days': 30,
    });
  });

  test('summary draft keeps source references and editable points', () {
    const scope = AIScope.fragments([1, 2]);
    final draft = AISummaryDraft.fromJson({
      'status': 'success',
      'request_id': 12,
      'source_count': 2,
      'summary': '两束光有一点靠近。',
      'title_candidates': ['靠近的光'],
      'why': '按共同线索整理',
      'sources': [
        {'fragment_id': 1, 'excerpt': '第一束', 'emotion': '平静'},
        {'fragment_id': 2, 'excerpt': '第二束', 'emotion': '开心'},
      ],
      'key_points': [
        {
          'text': '共同线索',
          'source_fragment_ids': [1, 2]
        },
      ],
    }, scope);

    expect(draft.requestId, 12);
    expect(draft.sources.map((source) => source.fragmentId), [1, 2]);
    expect(draft.keyPoints.single.toJson()['source_fragment_ids'], [1, 2]);
  });
}
