import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../emotion/domain/emotion_sounds.dart';

part 'app_database.g.dart';

/// 本地光片表
class Fragments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get publicId => text().withDefault(const Constant(''))();
  TextColumn get contentText => text().withDefault(const Constant(''))();
  TextColumn get emotion => text().withDefault(const Constant('说不清'))();
  TextColumn get status => text().withDefault(const Constant('twilight'))();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get mediaUrls =>
      text().named('media_urls').withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  BoolColumn get isSynced =>
      boolean().named('is_synced').withDefault(const Constant(false))();
}

/// 本地 OpLog 表（待同步操作）
class OpLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientOpId => text().named('client_op_id')();
  TextColumn get entityType => text().named('entity_type')();
  TextColumn get opType => text().named('op_type')();
  TextColumn get entityPublicId => text().named('entity_public_id')();
  TextColumn get payload => text().withDefault(const Constant('{}'))();
  IntColumn get clientSeq =>
      integer().named('client_seq').withDefault(const Constant(0))();
  IntColumn get baseServerVersion =>
      integer().named('base_server_version').withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}

/// 本地情绪表 — 用户可管理的微光情绪（默认 7 个 + 自定义）
/// 默认情绪 isDefault=true 不可删除；自定义情绪可增删改。
/// fragment.emotion 字段仍存情绪名 text，删情绪时光片保留原文字。
class Emotions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // 情绪名，用户可见
  IntColumn get colorHex => integer().named('color_hex')();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get isDefault =>
      boolean().named('is_default').withDefault(const Constant(false))();
  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();
  TextColumn get soundKey => text().named('sound_key').nullable()();
  BoolColumn get isUserDefault =>
      boolean().named('is_user_default').withDefault(const Constant(false))();
  BoolColumn get hidden =>
      boolean().named('hidden').withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}

/// 本地音频库表 - 用户新增的背景音乐。
/// 内置音频见 emotion_sounds.dart 的 const 清单，不入库。
/// emotion.soundKey 引用本表 key 字段；查找时先查内置 const，再查本表。
@DataClassName('AudioLibraryEntry')
class AudioLibrary extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text()(); // 唯一标识，供 emotion.sound_key 绑定
  TextColumn get name => text()(); // 用户可见名
  TextColumn get filePath => text().named('file_path')(); // 沙盒内绝对路径
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {key}
      ];
}

@DriftDatabase(tables: [Fragments, OpLogs, Emotions, AudioLibrary])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Explicit executor injection keeps repositories deterministic in tests and
  /// prevents feature code from creating a second app database implicitly.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaultEmotions();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Drift uses the current table definition here, so a direct
            // v1 -> v4 upgrade already creates every emotion column. Do not
            // run the incremental ALTER TABLE steps below for this branch.
            await m.createTable(emotions);
            await _seedDefaultEmotions();
            if (to >= 4) await m.createTable(audioLibrary);
          } else {
            if (from < 3) {
              // v3: 心情增加 sound_key 列，并为已有默认心情绑定声音
              await m.addColumn(emotions, emotions.soundKey);
              await _backfillDefaultSoundKeys();
            }
            if (from < 4) {
              // v4: 心情增加 is_user_default / hidden 列；新增音频库表
              await m.addColumn(emotions, emotions.isUserDefault);
              await m.addColumn(emotions, emotions.hidden);
              await m.createTable(audioLibrary);
            }
          }
        },
      );

  /// 默认 7 个情绪种子数据（与 AppColors._emotionMap 对齐）。
  /// 颜色用 Color.value (int) 持久化，声音绑定见 emotion_sounds.dart。
  Future<void> _seedDefaultEmotions() async {
    const defaults = <(String, int, String, String?)>[
      ('平静', 0xFF72A58F, '内心安静，没有波澜', 'soothing'),
      ('开心', 0xFFF0C78E, '有一点点想笑', 'upbeat'),
      ('疲惫', 0xFF9EBBCC, '身体或心里有点累', 'soothing'),
      ('焦虑', 0xFFE9A18B, '心悬着，不太安稳', 'soothing'),
      ('失落', 0xFFC4C4C4, '空空的，说不上来', 'haoyvnlai'),
      ('被击中', 0xFFE8B88A, '被什么触动了', 'upbeat'),
      ('混乱', 0xFFD9CCE8, '一团乱，理不清楚', 'upbeat'),
    ];
    for (var i = 0; i < defaults.length; i++) {
      final (name, color, desc, soundKey) = defaults[i];
      await into(emotions).insert(EmotionsCompanion.insert(
        name: name,
        colorHex: color,
        description: Value(desc),
        isDefault: const Value(true),
        sortOrder: Value(i),
        soundKey: Value(soundKey),
      ));
    }
  }

  /// v3 迁移：为已存在的默认心情按名称回填 sound_key。
  Future<void> _backfillDefaultSoundKeys() async {
    for (final entry in defaultEmotionSoundKeys.entries) {
      await (update(emotions)..where((t) => t.name.equals(entry.key)))
          .write(EmotionsCompanion(soundKey: Value(entry.value)));
    }
  }

  // ── Fragment CRUD ──

  Future<List<Fragment>> getAllFragments() {
    return (select(fragments)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<Fragment?> getFragmentById(int id) {
    return (select(fragments)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertFragment(FragmentsCompanion entry) {
    return into(fragments).insert(entry);
  }

  Future<bool> updateFragment(FragmentsCompanion entry) {
    return update(fragments).replace(entry);
  }

  Future<int> deleteFragment(int id) {
    return (delete(fragments)..where((t) => t.id.equals(id))).go();
  }

  // ── OpLog ──

  Future<List<OpLog>> getPendingOps() {
    return (select(opLogs)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  }

  Future<int> insertOpLog(OpLogsCompanion entry) {
    return into(opLogs).insert(entry);
  }

  Future<void> deleteOpLog(String clientOpId) {
    return (delete(opLogs)..where((t) => t.clientOpId.equals(clientOpId))).go();
  }

  Future<void> clearOpLogs() {
    return delete(opLogs).go();
  }

  // ── Emotion CRUD ──

  Future<List<Emotion>> getAllEmotions() {
    return (select(emotions)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<Emotion?> getEmotionByName(String name) {
    return (select(emotions)..where((t) => t.name.equals(name)))
        .getSingleOrNull();
  }

  Future<int> insertEmotion(EmotionsCompanion entry) {
    return into(emotions).insert(entry);
  }

  Future<bool> updateEmotion(EmotionsCompanion entry) {
    return update(emotions).replace(entry);
  }

  Future<int> deleteEmotion(int id) {
    return (delete(emotions)..where((t) => t.id.equals(id))).go();
  }

  Future<int> maxEmotionSortOrder() async {
    final q = selectOnly(emotions)
      ..addColumns([emotions.sortOrder.max()])
      ..limit(1);
    final row = await q.getSingle();
    return row.read(emotions.sortOrder.max()) ?? 0;
  }

  /// 设置指定心情的隐藏状态。
  Future<void> setEmotionHidden(int id, bool hidden) {
    return (update(emotions)..where((t) => t.id.equals(id)))
        .write(EmotionsCompanion(hidden: Value(hidden)));
  }

  // ── AudioLibrary CRUD ──

  Future<List<AudioLibraryEntry>> getAllAudioTracks() {
    return (select(audioLibrary)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<int> insertAudioTrack(AudioLibraryCompanion entry) {
    return into(audioLibrary).insert(entry);
  }

  Future<int> deleteAudioTrack(int id) {
    return (delete(audioLibrary)..where((t) => t.id.equals(id))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'xiguang.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
