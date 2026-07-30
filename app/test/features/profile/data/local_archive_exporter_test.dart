import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiguang/features/profile/data/local_archive_exporter.dart';
import 'package:xiguang/features/profile/domain/archive_models.dart';
import 'package:xiguang/features/shared/data/api_client.dart';
import 'package:xiguang/features/shared/data/local/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late AppDatabase database;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('xiguang-archive-test-');
    database = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'xiguang.night_mode_option': 2,
      'xiguang.sync.config.enabled': true,
    });
    PackageInfo.setMockInitialValues(
      appName: '隙光',
      packageName: 'com.xiguang.app',
      version: '1.0.0-test',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('missing required local media blocks a formal archive', () async {
    await database.into(database.fragments).insert(FragmentsCompanion.insert(
          publicId: const Value('fragment-missing'),
          contentText: const Value('缺失媒体'),
          mediaUrls: const Value('["/definitely/missing/image.jpg"]'),
          createdAt: Value(DateTime.utc(2026, 7, 11)),
          updatedAt: Value(DateTime.utc(2026, 7, 11)),
        ));
    final exporter = _exporter(database, root);

    final preflight = await exporter.preflightExport();

    expect(preflight.canExport, isFalse);
    expect(
      exporter
          .exportArchive(const ArchiveExportRequest(
            sourceAccountPublicId: 'user-1',
            username: 'tester',
          ))
          .drain<void>(),
      throwsA(isA<ArchiveIntegrityException>()),
    );
  });

  test('v1 zip verifies, restores safely, and is idempotent', () async {
    final media = File('${root.path}/photo.png');
    await media.writeAsBytes(const [137, 80, 78, 71, 13, 10, 26, 10]);
    await database.into(database.fragments).insert(FragmentsCompanion.insert(
          publicId: const Value('fragment-1'),
          contentText: const Value('一束测试的光'),
          emotion: const Value('平静'),
          tags: const Value('["归档"]'),
          mediaUrls: Value(jsonEncode([media.path])),
          createdAt: Value(DateTime.utc(2026, 7, 11, 1, 15)),
          updatedAt: Value(DateTime.utc(2026, 7, 11, 1, 20)),
        ));
    final exporter = _exporter(database, root);
    final events = await exporter
        .exportArchive(const ArchiveExportRequest(
          sourceAccountPublicId: 'user-1',
          username: 'tester',
        ))
        .toList();
    final result = events.last.exportResult!;

    await exporter.verifyArchive(result.zipPath);
    if (Platform.isMacOS || Platform.isLinux) {
      final standardUnzip = await Process.run('unzip', ['-t', result.zipPath]);
      expect(standardUnzip.exitCode, 0,
          reason: '${standardUnzip.stdout}\n${standardUnzip.stderr}');
    }
    final preview = await exporter.inspectArchive(result.zipPath);
    expect(preview.duplicates, 1);
    expect(preview.conflicts, 0);

    final restoredDb = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(restoredDb.close);
    final restored = _exporter(restoredDb, root);
    final first = await restored
        .importArchive(ArchiveImportRequest(zipPath: result.zipPath))
        .toList();
    expect(first.last.importResult!.added, 1);
    expect((await restoredDb.getAllFragments()).single.contentText, '一束测试的光');

    final second = await restored
        .importArchive(ArchiveImportRequest(zipPath: result.zipPath))
        .toList();
    expect(second.last.importResult!.added, 0);
    expect(second.last.importResult!.skipped, 1);
  });

  test('unknown archive versions are rejected', () async {
    final file = File('${root.path}/unknown-version.zip');
    await _writeContractZip(file, version: 99);

    expect(
      _exporter(database, root).verifyArchive(file.path),
      throwsA(isA<ArchiveIntegrityException>()),
    );
  });

  test('path traversal entries are rejected before extraction', () async {
    final file = File('${root.path}/unsafe.zip');
    await _writeContractZip(file, version: 1, unsafeEntry: '../outside.txt');

    expect(
      _exporter(database, root).verifyArchive(file.path),
      throwsA(isA<ArchiveIntegrityException>()),
    );
  });
}

LocalArchiveExporter _exporter(AppDatabase db, Directory root) {
  return LocalArchiveExporter(
    database: db,
    api: ApiClient(baseUrl: 'http://127.0.0.1:1/api/v1'),
    temporaryDirectory: () async => root,
    documentsDirectory: () async => root,
  );
}

Future<void> _writeContractZip(
  File file, {
  required int version,
  String? unsafeEntry,
}) async {
  final files = <String, String>{
    'README.md': '# test',
    'manifest.json': jsonEncode({
      'format': 'xiguang-archive',
      'version': version,
      'archive_id': 'test-archive',
      'exported_at': DateTime.utc(2026, 7, 11).toIso8601String(),
      'source_account_public_id': 'user-1',
      'counts': <String, int>{},
      'media': <String, dynamic>{},
    }),
    'data/fragments.json': '[]',
    'data/relations.json': '[]',
    'data/islands.json': '[]',
    'data/emotions.json': '[]',
    'data/audio_library.json': '[]',
    'data/preferences.json': '{}',
    'data/account.json': '{}',
  };
  files['checksums.sha256'] = files.entries
      .map((entry) =>
          '${sha256.convert(utf8.encode(entry.value))}  ${entry.key}')
      .join('\n');
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  if (unsafeEntry != null) {
    archive.addFile(ArchiveFile.string(unsafeEntry, 'unsafe'));
  }
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
}
