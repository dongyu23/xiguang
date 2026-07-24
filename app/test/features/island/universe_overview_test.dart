import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/fragment/domain/fragment.dart';
import 'package:xiguang/features/island/application/universe_overview_provider.dart';
import 'package:xiguang/features/island/domain/universe_overview.dart';
import 'package:xiguang/features/relation/domain/relation.dart';

void main() {
  test('relations are grouped into stable visual branches', () {
    final fragments = [
      _fragment(1, 1),
      _fragment(2, 2),
      _fragment(3, 3),
      _fragment(4, 4),
      _fragment(5, 5),
    ];
    const relations = [
      Relation(
        id: 1,
        publicId: 'a',
        sourceFragmentId: 1,
        targetFragmentId: 2,
        relationType: 'cause',
      ),
      Relation(
        id: 2,
        publicId: 'b',
        sourceFragmentId: 2,
        targetFragmentId: 3,
        relationType: 'same_phase',
      ),
      Relation(
        id: 3,
        publicId: 'c',
        sourceFragmentId: 4,
        targetFragmentId: 5,
        relationType: 'cause',
      ),
    ];

    final branches = buildBranchVisualSummaries(relations, fragments);

    expect(branches, hasLength(2));
    expect(branches.map((branch) => branch.fragmentCount), containsAll([3, 2]));
    final first = branches.firstWhere((branch) => branch.fragmentCount == 3);
    expect(first.fragments.map((fragment) => fragment.id), [1, 2, 3]);
    expect(first.hasBidirectional, isTrue);
    expect(first.edges.first.direction, RelationDirection.forward);
  });
}

Fragment _fragment(int id, int hour) => Fragment(
      id: id,
      publicId: 'fragment-$id',
      contentText: '事件 $id',
      createdAt: DateTime.utc(2026, 7, 12, hour),
    );
