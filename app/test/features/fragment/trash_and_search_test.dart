import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/shared/data/local/app_database.dart';

void main() {
  test('local fragments can be searched, soft-deleted and restored', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final id = await database.insertFragment(FragmentsCompanion.insert(
      contentText: const Value('期末考试之后去看海'),
      emotion: const Value('平静'),
      tags: const Value('["考试周","海边"]'),
      createdAt: Value(DateTime(2026, 7, 13)),
    ));

    expect(await database.searchFragments('考试'), hasLength(1));
    expect(await database.searchFragments('海边'), hasLength(1));

    await database.deleteFragment(id);
    expect(await database.getAllFragments(), isEmpty);
    expect(await database.getDeletedFragments(), hasLength(1));

    await database.restoreFragment(id);
    expect(await database.getDeletedFragments(), isEmpty);
    expect(await database.getAllFragments(), hasLength(1));
  });

  test('permanent delete only removes the selected recycled fragment',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final id = await database.insertFragment(FragmentsCompanion.insert(
      contentText: const Value('准备删除'),
      createdAt: Value(DateTime(2026, 7, 13)),
    ));
    await database.deleteFragment(id);
    await database.permanentlyDeleteFragment(id);
    expect(await database.getDeletedFragments(), isEmpty);
    expect(await database.getFragmentById(id), equals(null));
  });
}
