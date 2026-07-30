import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();
  BoolColumn get isSynced =>
      boolean().named('is_synced').withDefault(const Constant(false))();
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
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

@DataClassName('RelationTypeEntry')
class RelationTypes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // 关系类型名，用户可见，如"回声"
  IntColumn get colorHex => integer().named('color_hex')();
  TextColumn get iconKey => text() // 图标标识，用于前端映射 IconData
      .named('icon_key')
      .withDefault(const Constant('auto_awesome_rounded'))();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get isDefault =>
      boolean().named('is_default').withDefault(const Constant(false))();
  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();
  BoolColumn get hidden =>
      boolean().named('hidden').withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}

@DataClassName('LocalRelationEntry')
class LocalRelations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().named('server_id').nullable()();
  TextColumn get publicId => text().named('public_id')();
  TextColumn get sourcePublicId => text().named('source_public_id')();
  TextColumn get targetPublicId => text().named('target_public_id')();
  TextColumn get relationType => text().named('relation_type')();
  TextColumn get note => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {publicId}
      ];
}

@DataClassName('LocalIslandEntry')
class LocalIslands extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().named('server_id').nullable()();
  TextColumn get publicId => text().named('public_id')();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('manual'))();
  BoolColumn get isManual =>
      boolean().named('is_manual').withDefault(const Constant(true))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {publicId}
      ];
}

@DataClassName('LocalIslandMemberEntry')
class LocalIslandMembers extends Table {
  TextColumn get islandPublicId => text().named('island_public_id')();
  TextColumn get fragmentPublicId => text().named('fragment_public_id')();

  @override
  Set<Column> get primaryKey => {islandPublicId, fragmentPublicId};
}

@DataClassName('MediaAssetEntry')
class MediaAssets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fragmentPublicId => text().named('fragment_public_id')();
  TextColumn get source => text()();
  TextColumn get localPath => text().named('local_path').nullable()();
  TextColumn get objectKey => text().named('object_key').nullable()();
  TextColumn get mimeType => text().named('mime_type')();
  IntColumn get fileSize => integer().named('file_size')();
  TextColumn get sha256 => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {fragmentPublicId, sha256}
      ];
}

@DataClassName('ArchiveImportJobEntry')
class ArchiveImportJobs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get archiveId => text().named('archive_id')();
  TextColumn get archivePath => text().named('archive_path')();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get reportJson =>
      text().named('report_json').withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {archiveId}
      ];
}

@DriftDatabase(tables: [
  Fragments,
  OpLogs,
  Emotions,
  AudioLibrary,
  RelationTypes,
  LocalRelations,
  LocalIslands,
  LocalIslandMembers,
  MediaAssets,
  ArchiveImportJobs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Explicit executor injection keeps repositories deterministic in tests and
  /// prevents feature code from creating a second app database implicitly.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaultEmotions();
          await _seedDefaultRelationTypes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Drift uses the current table definition here, so a direct
            // v1 -> v4 upgrade already creates every emotion column. Do not
            // run the incremental ALTER TABLE steps below for this branch.
            if (!await _tableExists('emotions')) {
              await m.createTable(emotions);
            }
            await _seedDefaultEmotions();
            if (to >= 4 && !await _tableExists('audio_library')) {
              await m.createTable(audioLibrary);
            }
          } else {
            if (from < 3) {
              // v3: 心情增加 sound_key 列，并为已有默认心情绑定声音
              if (!await _columnExists('emotions', 'sound_key')) {
                await m.addColumn(emotions, emotions.soundKey);
              }
              await _backfillDefaultSoundKeys();
            }
            if (from < 4) {
              // v4: 心情增加 is_user_default / hidden 列；新增音频库表
              if (!await _columnExists('emotions', 'is_user_default')) {
                await m.addColumn(emotions, emotions.isUserDefault);
              }
              if (!await _columnExists('emotions', 'hidden')) {
                await m.addColumn(emotions, emotions.hidden);
              }
              if (!await _tableExists('audio_library')) {
                await m.createTable(audioLibrary);
              }
            }
          }
          if (from < 5) {
            if (!await _columnExists('fragments', 'updated_at')) {
              await m.addColumn(fragments, fragments.updatedAt);
            }
            if (!await _tableExists('local_relations')) {
              await m.createTable(localRelations);
            }
            if (!await _tableExists('local_islands')) {
              await m.createTable(localIslands);
            }
            if (!await _tableExists('local_island_members')) {
              await m.createTable(localIslandMembers);
            }
            if (!await _tableExists('media_assets')) {
              await m.createTable(mediaAssets);
            }
            if (!await _tableExists('archive_import_jobs')) {
              await m.createTable(archiveImportJobs);
            }
          }
          if (from < 6) {
            if (!await _columnExists('fragments', 'is_deleted')) {
              await m.addColumn(fragments, fragments.isDeleted);
            }
            if (!await _columnExists('fragments', 'deleted_at')) {
              await m.addColumn(fragments, fragments.deletedAt);
            }
          }
          if (from < 7) {
            // v7: 新增 relation_types 表（用户可自定义织线类型）
            if (!await _tableExists('relation_types')) {
              await m.createTable(relationTypes);
              await _seedDefaultRelationTypes();
            }
          }
          if (from < 5) {
            await _backfillFragmentMetadata();
          }
        },
      );

  Future<bool> _tableExists(String name) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
      variables: [Variable<String>(name)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<bool> _columnExists(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info("$table")').get();
    return rows.any((row) => row.read<String>('name') == column);
  }

  Future<void> _backfillFragmentMetadata() async {
    final rows = await select(fragments).get();
    const uuid = Uuid();
    for (final row in rows) {
      if (row.publicId.isNotEmpty && row.updatedAt != null) continue;
      await (update(fragments)..where((table) => table.id.equals(row.id)))
          .write(FragmentsCompanion(
        publicId:
            row.publicId.isEmpty ? Value(uuid.v4()) : const Value.absent(),
        updatedAt: Value(row.updatedAt ?? row.createdAt),
      ));
    }
  }

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

  /// 默认织线类型 - 与 CLAUDE.md 关系类型清单一致：
  /// 回声/伏笔/余震/平行宇宙/小小救命/潮汐/旧光（7 个，全部 isDefault 不可删）
  Future<void> _seedDefaultRelationTypes() async {
    const defaults = <(String, int, String, String)>[
      ('回声', 0xFFB8A4D4, '一束光在另一束里轻轻回应。', 'auto_awesome_rounded'),
      ('伏笔', 0xFFA4B8D4, '更早的那束，原来早就埋下了线索。', 'edit_note_rounded'),
      ('余震', 0xFF8FB8A4, '情绪还在继续，没有马上过去。', 'trip_origin_rounded'),
      ('平行宇宙', 0xFF8E96A8, '同时存在的另一种可能。', 'grain_rounded'),
      ('小小救命', 0xFFD4A4A4, '那一次被接住了。', 'favorite_border_rounded'),
      ('潮汐', 0xFFA4C4D4, '来来去去，有自己的节律。', 'waves_rounded'),
      ('旧光', 0xFFB9B9A8, '很久以前的，又被想起。', 'circle_rounded'),
    ];
    for (var i = 0; i < defaults.length; i++) {
      final (name, color, desc, icon) = defaults[i];
      await into(relationTypes).insert(RelationTypesCompanion.insert(
        name: name,
        colorHex: color,
        iconKey: Value(icon),
        description: Value(desc),
        isDefault: const Value(true),
        sortOrder: Value(i),
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
    return (select(fragments)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<Fragment>> searchFragments(String query) {
    final pattern = '%${query.trim()}%';
    return (select(fragments)
          ..where((t) =>
              t.isDeleted.equals(false) &
              (t.contentText.like(pattern) |
                  t.tags.like(pattern) |
                  t.emotion.like(pattern)))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<Fragment>> getDeletedFragments() {
    return (select(fragments)
          ..where((t) => t.isDeleted.equals(true))
          ..orderBy([
            (t) => OrderingTerm.desc(t.deletedAt),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
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
    return (update(fragments)..where((t) => t.id.equals(id))).write(
      FragmentsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> restoreFragment(int id) {
    return (update(fragments)..where((t) => t.id.equals(id))).write(
      const FragmentsCompanion(
        isDeleted: Value(false),
        deletedAt: Value(null),
      ),
    );
  }

  Future<int> permanentlyDeleteFragment(int id) {
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

  // ── RelationType CRUD ──

  Future<List<RelationTypeEntry>> getAllRelationTypes() {
    return (select(relationTypes)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<RelationTypeEntry?> getRelationTypeByName(String name) {
    return (select(relationTypes)..where((t) => t.name.equals(name)))
        .getSingleOrNull();
  }

  Future<int> insertRelationType(RelationTypesCompanion entry) {
    return into(relationTypes).insert(entry);
  }

  Future<bool> updateRelationType(RelationTypesCompanion entry) {
    return update(relationTypes).replace(entry);
  }

  Future<int> deleteRelationType(int id) {
    return (delete(relationTypes)..where((t) => t.id.equals(id))).go();
  }

  Future<int> maxRelationTypeSortOrder() async {
    final q = selectOnly(relationTypes)
      ..addColumns([relationTypes.sortOrder.max()])
      ..limit(1);
    final row = await q.getSingle();
    return row.read(relationTypes.sortOrder.max()) ?? 0;
  }

  Future<void> setRelationTypeHidden(int id, bool hidden) {
    return (update(relationTypes)..where((t) => t.id.equals(id)))
        .write(RelationTypesCompanion(hidden: Value(hidden)));
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
