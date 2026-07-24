import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:xiguang/features/shared/data/local/app_database.dart';

void main() {
  test('v5 migration backfills stable public id and updated_at', () async {
    final root = await Directory.systemTemp.createTemp('xiguang-db-v4-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/db.sqlite');
    final old = sqlite3.open(file.path);
    old.execute('''
      CREATE TABLE fragments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        public_id TEXT NOT NULL DEFAULT '',
        content_text TEXT NOT NULL DEFAULT '',
        emotion TEXT NOT NULL DEFAULT '说不清',
        status TEXT NOT NULL DEFAULT 'twilight',
        tags TEXT NOT NULL DEFAULT '[]',
        media_urls TEXT NOT NULL DEFAULT '[]',
        created_at INTEGER NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      );
      INSERT INTO fragments(content_text, created_at) VALUES('旧光', 1783728000);
      PRAGMA user_version = 4;
    ''');
    old.dispose();

    final database = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(database.close);
    final row = (await database.getAllFragments()).single;

    expect(row.publicId, isNotEmpty);
    expect(row.updatedAt, row.createdAt);
  });
}
