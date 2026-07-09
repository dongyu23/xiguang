import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Fragments, OpLogs, Emotions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaultEmotions();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(emotions);
            await _seedDefaultEmotions();
          }
        },
      );

  /// 默认 7 个情绪种子数据（与 AppColors._emotionMap 对齐）。
  /// 颜色用 Color.value (int) 持久化。
  Future<void> _seedDefaultEmotions() async {
    const defaults = <(String, int, String)>[
      ('平静', 0xFF72A58F, '内心安静，没有波澜'),
      ('开心', 0xFFF0C78E, '有一点点想笑'),
      ('疲惫', 0xFF9EBBCC, '身体或心里有点累'),
      ('焦虑', 0xFFE9A18B, '心悬着，不太安稳'),
      ('失落', 0xFFC4C4C4, '空空的，说不上来'),
      ('被击中', 0xFFE8B88A, '被什么触动了'),
      ('混乱', 0xFFD9CCE8, '一团乱，理不清楚'),
    ];
    for (var i = 0; i < defaults.length; i++) {
      final (name, color, desc) = defaults[i];
      await into(emotions).insert(EmotionsCompanion.insert(
        name: name,
        colorHex: color,
        description: Value(desc),
        isDefault: const Value(true),
        sortOrder: Value(i),
      ));
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'xiguang.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
