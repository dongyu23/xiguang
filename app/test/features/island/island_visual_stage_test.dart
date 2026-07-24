import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/fragment/domain/fragment.dart';
import 'package:xiguang/features/island/domain/island_model.dart';
import 'package:xiguang/features/island/domain/island_visual_stage.dart';
import 'package:xiguang/features/island/domain/universe_overview.dart';

void main() {
  test('empty manual island starts as a shoal', () {
    final island = _node(status: 'star_point', fragments: const []);

    expect(island.visualStage, IslandVisualStage.shoal);
  });

  test('server growth states map to visual stages', () {
    expect(_node(status: 'growing').visualStage, IslandVisualStage.growing);
    expect(_node(status: 'formed').visualStage, IslandVisualStage.formed);
    expect(_node(status: 'dormant').visualStage, IslandVisualStage.dormant);
    expect(_node(status: 'relit').visualStage, IslandVisualStage.relit);
  });

  test('visual family is stable for the same island', () {
    final first = _node(status: 'formed');
    final second = _node(status: 'formed');

    expect(first.visualFamily, second.visualFamily);
    expect(first.visualFamily, inInclusiveRange(0, 5));
  });

  test('the first six persisted islands use six different families', () {
    final families = {
      for (var id = 1; id <= 6; id++)
        IslandVisualNode(
          island: IslandModel(
            islandId: id,
            name: '小岛 $id',
            status: 'formed',
            fragmentCount: 1,
            description: '',
          ),
          fragments: const [],
        ).visualFamily,
    };

    expect(families, hasLength(6));
  });
}

IslandVisualNode _node({
  required String status,
  List<Fragment>? fragments,
}) {
  return IslandVisualNode(
    island: IslandModel(
      islandId: 7,
      name: '考试周',
      status: status,
      fragmentCount: fragments?.length ?? 1,
      description: '',
    ),
    fragments: fragments ??
        [
          Fragment(
            id: 1,
            contentText: '开始复习',
            createdAt: DateTime.utc(2026, 7, 12),
          ),
        ],
  );
}
