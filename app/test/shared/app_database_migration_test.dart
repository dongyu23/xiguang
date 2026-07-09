import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:xiguang/features/shared/data/local/app_database.dart';

void main() {
  test('schema v1 upgrades directly to the current emotion schema', () async {
    final sqlite = sqlite3.openInMemory();
    addTearDown(sqlite.dispose);

    final current = AppDatabase.forTesting(NativeDatabase.opened(
      sqlite,
      closeUnderlyingOnClose: false,
    ));
    await current.getAllEmotions();
    await current.close();

    // Recreate the shape of a v1 install: fragments and op_logs existed,
    // while emotions and audio_library had not been introduced yet.
    sqlite.execute('DROP TABLE emotions');
    sqlite.execute('DROP TABLE audio_library');
    sqlite.execute('PRAGMA user_version = 1');

    final upgraded = AppDatabase.forTesting(NativeDatabase.opened(
      sqlite,
      closeUnderlyingOnClose: false,
    ));
    addTearDown(upgraded.close);

    final emotions = await upgraded.getAllEmotions();
    expect(emotions, hasLength(7));
    expect(
      sqlite.select('PRAGMA table_info(emotions)').map((row) => row['name']),
      containsAll(['sound_key', 'is_user_default', 'hidden']),
    );
    expect(
      sqlite.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'audio_library'",
      ),
      isNotEmpty,
    );
  });
}
