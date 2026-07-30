import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../shared/data/api_client.dart';
import '../../shared/data/local/app_database.dart';
import '../domain/archive_models.dart';
import '../domain/local_archive_repository.dart';

class LocalArchiveExporter implements LocalArchiveRepositoryPort {
  LocalArchiveExporter({
    required AppDatabase database,
    required ApiClient api,
    Future<Directory> Function()? temporaryDirectory,
    Future<Directory> Function()? documentsDirectory,
  })  : _db = database,
        _api = api,
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
        _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  static const format = 'xiguang-archive';
  static const version = 1;
  static const _maxEntries = 20000;
  static const _maxExpandedBytes = 10 * 1024 * 1024 * 1024;

  final AppDatabase _db;
  final ApiClient _api;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<Directory> Function() _documentsDirectory;

  @override
  Future<ArchivePreflight> preflightExport() async {
    final fragments = await _db.getAllFragments();
    var bytes = 0;
    var mediaCount = 0;
    final issues = <ArchiveIssue>[];
    for (final fragment in fragments) {
      for (final source in _stringList(fragment.mediaUrls)) {
        mediaCount++;
        final local = _localFile(source);
        if (local != null) {
          if (!await local.exists()) {
            issues.add(ArchiveIssue(
              code: 'media_missing',
              message: '本地媒体不存在',
              source: source,
            ));
          } else {
            bytes += await local.length();
          }
        }
      }
    }
    for (final audio in await _db.select(_db.audioLibrary).get()) {
      mediaCount++;
      final file = File(audio.filePath);
      if (!await file.exists()) {
        issues.add(ArchiveIssue(
          code: 'audio_library_missing',
          message: '个人声音库文件不存在：${audio.name}',
          source: audio.filePath,
        ));
      } else {
        bytes += await file.length();
      }
    }
    return ArchivePreflight(
      fragmentCount: fragments.length,
      mediaCount: mediaCount,
      estimatedBytes: bytes,
      issues: issues,
    );
  }

  @override
  Stream<ArchiveProgress> exportArchive(ArchiveExportRequest request) async* {
    final preflight = await preflightExport();
    yield ArchiveProgress(
      phase: ArchivePhase.preflight,
      fraction: .05,
      message: '已检查 ${preflight.fragmentCount} 束光',
      totalFiles: preflight.mediaCount,
    );
    if (!preflight.canExport) {
      throw ArchiveIntegrityException('归档预检失败', issues: preflight.issues);
    }

    final archiveId = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final tempRoot = await _temporaryDirectory();
    final work = Directory(p.join(tempRoot.path, 'xiguang-archive-$archiveId'));
    final content = Directory(p.join(work.path, 'content'));
    final output = Directory(p.join(work.path, 'output'));
    await content.create(recursive: true);
    await output.create(recursive: true);

    File? partial;
    try {
      final snapshot = await _readSnapshot();
      final mediaMap = <String, Map<String, dynamic>>{};
      final mediaBySource = <String, Map<String, dynamic>>{};
      final mediaSources = <_MediaSource>[];
      for (final fragment in snapshot.fragments) {
        for (final source in _stringList(fragment.mediaUrls)) {
          mediaSources.add(_MediaSource(source, fragment.publicId, false));
        }
      }
      for (final audio in snapshot.audioLibrary) {
        mediaSources.add(_MediaSource(audio.filePath, '', true));
      }
      final remoteURLs = await _exportURLs(mediaSources.map((e) => e.source));

      for (var i = 0; i < mediaSources.length; i++) {
        final source = mediaSources[i];
        final staged = await _stageSource(
          remoteURLs[source.source] ?? source.source,
          work,
          i,
        );
        if (!staged.mime.startsWith('image/') &&
            !staged.mime.startsWith('audio/')) {
          throw ArchiveIntegrityException('不支持的媒体类型：${source.source}');
        }
        final digest = await _shaFile(staged.file);
        final extension = staged.extension;
        final folder = source.library
            ? 'library'
            : staged.mime.startsWith('audio/')
                ? 'audio'
                : 'images';
        final relative = 'media/$folder/$digest$extension';
        final target = File(p.joinAll([content.path, ...relative.split('/')]));
        if (!await target.exists()) {
          await target.parent.create(recursive: true);
          await staged.file.copy(target.path);
        }
        final descriptor = <String, dynamic>{
          'path': relative,
          'mime': staged.mime,
          'size': await staged.file.length(),
          'sha256': digest,
        };
        mediaMap[relative] = descriptor;
        mediaBySource[source.source] = descriptor;
        if (source.fragmentPublicId.isNotEmpty) {
          await _db.into(_db.mediaAssets).insert(
                MediaAssetsCompanion.insert(
                  fragmentPublicId: source.fragmentPublicId,
                  source: source.source,
                  localPath: Value(_localFile(source.source)?.path),
                  objectKey: Value(_objectKey(source.source)),
                  mimeType: staged.mime,
                  fileSize: await staged.file.length(),
                  sha256: digest,
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
        if (staged.temporary) await staged.file.delete();
        yield ArchiveProgress(
          phase: ArchivePhase.media,
          fraction:
              .05 + .35 * ((i + 1) / mediaSources.length.clamp(1, 1 << 30)),
          message: '正在整理媒体 ${i + 1}/${mediaSources.length}',
          processedFiles: i + 1,
          totalFiles: mediaSources.length,
        );
      }

      final package = await PackageInfo.fromPlatform();
      final fragmentsJson = <Map<String, dynamic>>[];
      final fragmentPaths = <String, String>{};
      for (final fragment in snapshot.fragments) {
        final archivePublicId = fragment.publicId;
        if (archivePublicId.isEmpty) {
          throw const ArchiveIntegrityException('发现没有稳定 ID 的光片，已停止归档');
        }
        final local = fragment.createdAt.toLocal();
        final recordPath = 'records/${local.year}/${_two(local.month)}/'
            '${local.year}-${_two(local.month)}-${_two(local.day)}-'
            '${_two(local.hour)}${_two(local.minute)}-$archivePublicId.md';
        fragmentPaths[archivePublicId] = recordPath;
        fragmentsJson.add({
          'archive_id': archivePublicId,
          'public_id': archivePublicId,
          'content_text': fragment.contentText,
          'emotion': fragment.emotion,
          'status': fragment.status,
          'tags': _stringList(fragment.tags),
          'media': _stringList(fragment.mediaUrls)
              .map((source) => mediaBySource[source])
              .whereType<Map<String, dynamic>>()
              .toList(),
          'created_at': fragment.createdAt.toUtc().toIso8601String(),
          'updated_at': (fragment.updatedAt ?? fragment.createdAt)
              .toUtc()
              .toIso8601String(),
        });
      }

      final relationsJson = snapshot.relations
          .map((r) => {
                'archive_id': r.publicId,
                'public_id': r.publicId,
                'source_archive_id': r.sourcePublicId,
                'target_archive_id': r.targetPublicId,
                'relation_type': r.relationType,
                'note': r.note,
              })
          .toList();
      final membersByIsland = <String, List<String>>{};
      for (final member in snapshot.islandMembers) {
        membersByIsland
            .putIfAbsent(member.islandPublicId, () => [])
            .add(member.fragmentPublicId);
      }
      final islandsJson = snapshot.islands
          .map((island) => {
                'archive_id': island.publicId,
                'public_id': island.publicId,
                'name': island.name,
                'description': island.description,
                'status': island.status,
                'manual': island.isManual,
                'members': membersByIsland[island.publicId] ?? const <String>[],
              })
          .toList();
      final emotionsJson = snapshot.emotions
          .map((emotion) => {
                'name': emotion.name,
                'color_hex': emotion.colorHex,
                'description': emotion.description,
                'is_default': emotion.isDefault,
                'sort_order': emotion.sortOrder,
                'sound_key': emotion.soundKey,
                'is_user_default': emotion.isUserDefault,
                'hidden': emotion.hidden,
              })
          .toList();
      final audioJson = snapshot.audioLibrary
          .map((audio) => {
                'key': audio.key,
                'name': audio.name,
                'media': mediaBySource[audio.filePath],
                'created_at': audio.createdAt.toUtc().toIso8601String(),
              })
          .toList();
      final preferences = await _exportPreferences();

      await _writeJson(content, 'data/fragments.json', fragmentsJson);
      await _writeJson(content, 'data/relations.json', relationsJson);
      await _writeJson(content, 'data/islands.json', islandsJson);
      await _writeJson(content, 'data/emotions.json', emotionsJson);
      await _writeJson(content, 'data/audio_library.json', audioJson);
      await _writeJson(content, 'data/preferences.json', preferences);
      await _writeJson(content, 'data/account.json', {
        'public_id': request.sourceAccountPublicId,
        'username': request.username,
        'nickname': request.nickname,
      });
      await _writeRecords(content, fragmentsJson, relationsJson, fragmentPaths);

      final counts = <String, int>{
        'fragments': fragmentsJson.length,
        'relations': relationsJson.length,
        'islands': islandsJson.length,
        'emotions': emotionsJson.length,
        'audio_library': audioJson.length,
        'media': mediaMap.length,
      };
      final manifest = <String, dynamic>{
        'format': format,
        'version': version,
        'archive_id': archiveId,
        'exported_at': now.toIso8601String(),
        'app_version': package.version,
        'source_account_public_id': request.sourceAccountPublicId,
        'counts': counts,
        'files': {
          'fragments': 'data/fragments.json',
          'relations': 'data/relations.json',
          'islands': 'data/islands.json',
          'emotions': 'data/emotions.json',
          'audio_library': 'data/audio_library.json',
          'preferences': 'data/preferences.json',
          'account': 'data/account.json',
        },
        'media': mediaMap,
      };
      await _writeJson(content, 'manifest.json', manifest);
      await File(p.join(content.path, 'README.md')).writeAsString(
        '# 隙光完整数据归档\n\n'
        '这是隙光 Archive v1 明文 ZIP。它可能包含私人文字、图片和声音，请妥善保管。\n\n'
        '可在“我的 → 数据归档 → 从归档恢复”中安全合并恢复。\n',
        encoding: utf8,
      );
      await _writeChecksums(content);
      yield const ArchiveProgress(
        phase: ArchivePhase.generate,
        fraction: .58,
        message: '归档内容已生成',
      );

      final documents = await _documentsDirectory();
      final exportDir = Directory(p.join(documents.path, 'exports'));
      await exportDir.create(recursive: true);
      final name = '隙光归档-${_fileTimestamp(now.toLocal())}.zip';
      partial = File(p.join(exportDir.path, '$name.partial'));
      await _zipFiles(content, partial.path);
      yield const ArchiveProgress(
        phase: ArchivePhase.compress,
        fraction: .8,
        message: '压缩完成，正在重新校验',
      );
      await verifyArchive(partial.path);
      final target = File(p.join(exportDir.path, name));
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      partial = null;
      final result = ArchiveExportResult(
        archiveId: archiveId,
        zipPath: target.path,
        fragmentCount: fragmentsJson.length,
        mediaCount: mediaMap.length,
        bytes: await target.length(),
      );
      yield ArchiveProgress(
        phase: ArchivePhase.save,
        fraction: 1,
        message: '完整归档已生成并通过校验',
        exportResult: result,
      );
    } catch (_) {
      if (partial != null && await partial.exists()) await partial.delete();
      rethrow;
    } finally {
      if (await work.exists()) await work.delete(recursive: true);
    }
  }

  @override
  Future<ArchiveImportPreview> inspectArchive(String zipPath) async {
    final opened = await _openVerified(zipPath);
    final manifest = opened.manifest;
    final incoming = opened.jsonList('data/fragments.json');
    final local = await _db.getAllFragments();
    final localById = {for (final item in local) item.publicId: item};
    var additions = 0;
    var duplicates = 0;
    var conflicts = 0;
    for (final item in incoming) {
      final id = '${item['public_id'] ?? item['archive_id'] ?? ''}';
      final existing = localById[id];
      if (existing == null) {
        additions++;
      } else if (_sameFragment(existing, item)) {
        duplicates++;
      } else {
        conflicts++;
      }
    }
    return ArchiveImportPreview(
      archiveId: '${manifest['archive_id']}',
      exportedAt: DateTime.parse('${manifest['exported_at']}'),
      sourceAccountPublicId: '${manifest['source_account_public_id'] ?? ''}',
      counts: (manifest['counts'] as Map).map(
        (key, value) => MapEntry('$key', (value as num).toInt()),
      ),
      additions: additions,
      duplicates: duplicates,
      conflicts: conflicts,
    );
  }

  @override
  Stream<ArchiveProgress> importArchive(ArchiveImportRequest request) async* {
    yield const ArchiveProgress(
      phase: ArchivePhase.preflight,
      fraction: .05,
      message: '正在验证归档',
    );
    final opened = await _openVerified(request.zipPath);
    final archiveId = '${opened.manifest['archive_id']}';
    final documents = await _documentsDirectory();
    final mediaRoot = Directory(p.join(documents.path, 'archive_media'));
    final staging =
        Directory(p.join(documents.path, '.archive-staging-$archiveId'));
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);

    var added = 0;
    var skipped = 0;
    final conflicts = <Map<String, dynamic>>[];
    final createdMedia = <File>[];
    var committed = false;
    try {
      final mediaPaths = <String, String>{};
      final mediaEntries = opened.files.entries
          .where(
              (entry) => entry.key.startsWith('media/') && entry.value.isFile)
          .toList();
      for (var i = 0; i < mediaEntries.length; i++) {
        final entry = mediaEntries[i];
        final target = File(p.joinAll([staging.path, ...entry.key.split('/')]));
        await target.parent.create(recursive: true);
        await target.writeAsBytes(entry.value.bytes, flush: true);
        final finalPath =
            p.joinAll([mediaRoot.path, ...entry.key.split('/').skip(1)]);
        mediaPaths[entry.key] = finalPath;
        yield ArchiveProgress(
          phase: ArchivePhase.media,
          fraction:
              .1 + .25 * ((i + 1) / mediaEntries.length.clamp(1, 1 << 30)),
          message: '正在暂存媒体 ${i + 1}/${mediaEntries.length}',
          processedFiles: i + 1,
          totalFiles: mediaEntries.length,
        );
      }

      // All media must be durable before the database transaction can expose
      // restored records. Newly copied files are tracked and removed if the
      // transaction fails.
      await mediaRoot.create(recursive: true);
      for (final entity
          in staging.listSync(recursive: true).whereType<File>()) {
        final relative = p.relative(entity.path, from: staging.path);
        final target = File(p
            .joinAll([mediaRoot.path, ...relative.split(p.separator).skip(1)]));
        await target.parent.create(recursive: true);
        if (!await target.exists()) {
          await entity.copy(target.path);
          createdMedia.add(target);
        }
      }

      await _db.transaction(() async {
        final local = await _db.getAllFragments();
        final localById = {for (final item in local) item.publicId: item};
        for (final item in opened.jsonList('data/fragments.json')) {
          final publicId = '${item['public_id'] ?? item['archive_id'] ?? ''}';
          final existing = localById[publicId];
          if (existing != null) {
            if (_sameFragment(existing, item)) {
              skipped++;
            } else {
              conflicts.add({
                'type': 'fragment',
                'public_id': publicId,
                'resolution': 'kept_existing',
              });
            }
            continue;
          }
          final media = (item['media'] as List? ?? const [])
              .whereType<Map>()
              .map((m) => mediaPaths['${m['path']}'])
              .whereType<String>()
              .toList();
          await _db.into(_db.fragments).insert(FragmentsCompanion.insert(
                publicId: Value(publicId),
                contentText: Value('${item['content_text'] ?? ''}'),
                emotion: Value('${item['emotion'] ?? '说不清'}'),
                status: Value('${item['status'] ?? 'twilight'}'),
                tags: Value(jsonEncode(item['tags'] ?? const [])),
                mediaUrls: Value(jsonEncode(media)),
                createdAt: Value(DateTime.parse('${item['created_at']}')),
                updatedAt: Value(DateTime.parse(
                    '${item['updated_at'] ?? item['created_at']}')),
                isSynced: const Value(false),
              ));
          added++;
        }
        await _mergeRelations(opened, conflicts);
        await _mergeIslands(opened, conflicts);
        await _mergeEmotions(opened);
        await _mergeAudioLibrary(opened, mediaPaths);
        await _db.into(_db.archiveImportJobs).insert(
              ArchiveImportJobsCompanion.insert(
                archiveId: archiveId,
                archivePath: request.zipPath,
                status: const Value('pending_cloud'),
                reportJson: Value(jsonEncode({
                  'added': added,
                  'skipped': skipped,
                  'conflicts': conflicts,
                })),
              ),
              mode: InsertMode.insertOrReplace,
            );
      });
      committed = true;

      try {
        await _restorePreferences(opened.jsonMap('data/preferences.json'));
      } catch (_) {
        // Preferences are optional UI state; content recovery remains valid.
      }
      var pendingCloud = added;
      yield const ArchiveProgress(
        phase: ArchivePhase.cloud,
        fraction: .9,
        message: '本机恢复完成，正在协调云端',
      );
      try {
        await _coordinateCloud(opened, mediaPaths);
        pendingCloud = 0;
        await (_db.update(_db.archiveImportJobs)
              ..where((table) => table.archiveId.equals(archiveId)))
            .write(const ArchiveImportJobsCompanion(
          status: Value('completed'),
        ));
      } catch (_) {
        // Local recovery is authoritative. The persisted archive import job
        // is deliberately separate from the regular sync queue and can retry.
      }
      final report =
          File(p.join(documents.path, 'archive-import-$archiveId.json'));
      await report.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'archive_id': archiveId,
          'added': added,
          'skipped': skipped,
          'conflicts': conflicts,
          'pending_cloud': pendingCloud,
        }),
        encoding: utf8,
      );
      yield ArchiveProgress(
        phase: ArchivePhase.cloud,
        fraction: 1,
        message: conflicts.isEmpty ? '本机恢复完成，等待云端协调' : '本机恢复完成，已生成冲突报告',
        importResult: ArchiveImportResult(
          added: added,
          skipped: skipped,
          conflicts: conflicts.length,
          pendingCloud: pendingCloud,
          reportPath: report.path,
        ),
      );
    } catch (_) {
      if (!committed) {
        for (final file in createdMedia.reversed) {
          if (await file.exists()) await file.delete();
        }
      }
      rethrow;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<void> _coordinateCloud(
    _OpenedArchive opened,
    Map<String, String> mediaPaths,
  ) async {
    if (!_api.hasToken) throw StateError('offline');
    final manifest = opened.manifest;
    final session = await _api.post('/archive/imports', {
      'source_account_public_id': manifest['source_account_public_id'] ?? '',
      'manifest': manifest,
    });
    final sessionId = '${session['id'] ?? ''}';
    if (sessionId.isEmpty) throw StateError('archive session missing');
    try {
      final media = (manifest['media'] as Map? ?? const {})
          .values
          .whereType<Map>()
          .toList();
      for (var start = 0; start < media.length; start += 100) {
        final end = (start + 100).clamp(0, media.length);
        final batch = media.sublist(start, end);
        final urls = await _api.post(
          '/archive/imports/$sessionId/upload-urls',
          {
            'items': batch
                .map((item) => {
                      'sha256': item['sha256'],
                      'mime_type': item['mime'],
                      'file_size': item['size'],
                      'extension': p.extension('${item['path']}'),
                    })
                .toList(),
          },
        );
        final uploadItems = urls['items'] as List<dynamic>? ?? const [];
        for (final raw in uploadItems.whereType<Map>()) {
          final sha = '${raw['sha256'] ?? ''}';
          final descriptor = batch.cast<Map>().firstWhere(
                (item) => item['sha256'] == sha,
                orElse: () => const {},
              );
          final archivePath = '${descriptor['path'] ?? ''}';
          final localPath = mediaPaths[archivePath];
          final uploadURL = '${raw['upload_url'] ?? ''}';
          if (localPath == null || uploadURL.isEmpty) {
            throw StateError('media upload mapping missing');
          }
          await _api.uploadToSignedUrl(
            uploadURL,
            localPath,
            contentType: '${descriptor['mime'] ?? 'application/octet-stream'}',
          );
        }
      }

      final fragments = opened.jsonList('data/fragments.json');
      final relations = opened.jsonList('data/relations.json');
      final islands = opened.jsonList('data/islands.json');
      await _api.post('/archive/imports/$sessionId/commit', {
        'fragments': fragments
            .map((item) => {
                  ...item,
                  'media_sha256': (item['media'] as List? ?? const [])
                      .whereType<Map>()
                      .map((media) => media['sha256'])
                      .toList(),
                })
            .toList(),
        'relations': relations,
        'islands': islands,
      });
    } catch (_) {
      try {
        await _api.delete('/archive/imports/$sessionId');
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<void> verifyArchive(String zipPath) async {
    await _openVerified(zipPath);
  }

  Future<_Snapshot> _readSnapshot() async {
    late _Snapshot result;
    await _db.transaction(() async {
      result = _Snapshot(
        fragments: await _db.getAllFragments(),
        relations: await _db.select(_db.localRelations).get(),
        islands: await _db.select(_db.localIslands).get(),
        islandMembers: await _db.select(_db.localIslandMembers).get(),
        emotions: await _db.select(_db.emotions).get(),
        audioLibrary: await _db.select(_db.audioLibrary).get(),
      );
    });
    return result;
  }

  Future<_StagedMedia> _stageSource(
      String source, Directory work, int index) async {
    final data = _decodeDataUrl(source);
    if (data != null) {
      final file = File(p.join(work.path, 'source-$index${data.extension}'));
      await file.writeAsBytes(data.bytes, flush: true);
      return _StagedMedia(file, data.mime, data.extension, true);
    }
    final local = _localFile(source);
    if (local != null) {
      if (!await local.exists()) {
        throw ArchiveIntegrityException('媒体文件不存在：$source');
      }
      final extension = _safeExtension(local.path);
      return _StagedMedia(local, _mime(extension), extension, false);
    }
    final target =
        File(p.join(work.path, 'download-$index${_safeExtension(source)}'));
    try {
      await _api.downloadToFile(source, target.path);
    } catch (_) {
      throw ArchiveIntegrityException('无法从服务端补取媒体：$source');
    }
    if (!await target.exists() || await target.length() == 0) {
      throw ArchiveIntegrityException('服务端返回了空媒体：$source');
    }
    final extension = _safeExtension(source);
    return _StagedMedia(target, _mime(extension), extension, true);
  }

  Future<Map<String, String>> _exportURLs(Iterable<String> sources) async {
    final originalsByKey = <String, List<String>>{};
    for (final source in sources.toSet()) {
      final key = _objectKey(source);
      if (key != null) {
        originalsByKey.putIfAbsent(key, () => []).add(source);
      }
    }
    if (originalsByKey.isEmpty) return const {};
    final result = <String, String>{};
    final keys = originalsByKey.keys.toList();
    for (var start = 0; start < keys.length; start += 100) {
      final end = (start + 100).clamp(0, keys.length);
      final batch = keys.sublist(start, end);
      Map<String, dynamic> body;
      try {
        body = await _api.post('/media/export-urls', {'object_keys': batch});
      } catch (_) {
        throw const ArchiveIntegrityException('无法验证云端媒体归属，请检查网络和后端版本');
      }
      final items = body['items'] as List<dynamic>? ?? const [];
      for (final raw in items.whereType<Map>()) {
        final key = '${raw['object_key'] ?? ''}';
        final url = '${raw['download_url'] ?? ''}';
        if (key.isEmpty || url.isEmpty) continue;
        for (final original in originalsByKey[key] ?? const <String>[]) {
          result[original] = url;
        }
      }
      if (batch.any((key) =>
          !(originalsByKey[key] ?? const []).every(result.containsKey))) {
        throw const ArchiveIntegrityException('服务端没有返回全部必需媒体，已停止归档');
      }
    }
    return result;
  }

  String? _objectKey(String source) {
    final value = source.trim();
    if (value.startsWith('users/')) {
      return value;
    }
    if (value.startsWith('/media/users/')) {
      return value.substring('/media/'.length);
    }
    final uri = Uri.tryParse(value);
    if (uri != null && uri.path.startsWith('/media/users/')) {
      return uri.path.substring('/media/'.length);
    }
    return null;
  }

  File? _localFile(String source) {
    final value = source.trim();
    if (value.isEmpty || value.startsWith('data:')) return null;
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('/media/') ||
        value.startsWith('users/')) {
      return null;
    }
    if (value.startsWith('file:')) {
      try {
        return File(Uri.parse(value).toFilePath());
      } catch (_) {
        return File(value);
      }
    }
    return File(value);
  }

  _DataUrl? _decodeDataUrl(String value) {
    if (!value.startsWith('data:')) return null;
    final comma = value.indexOf(',');
    if (comma < 0 || !value.substring(0, comma).contains(';base64')) {
      throw const ArchiveIntegrityException('发现无效的内嵌媒体');
    }
    final mime = value.substring(5, value.indexOf(';'));
    try {
      return _DataUrl(base64Decode(value.substring(comma + 1)), mime,
          _extensionForMime(mime));
    } on FormatException {
      throw const ArchiveIntegrityException('内嵌媒体 Base64 校验失败');
    }
  }

  Future<_OpenedArchive> _openVerified(String path) async {
    final file = File(path);
    if (!await file.exists()) throw const ArchiveIntegrityException('归档文件不存在');
    final input = InputFileStream(path);
    Archive? archive;
    final files = <String, _ArchiveBytes>{};
    try {
      try {
        archive = ZipDecoder().decodeStream(input);
      } catch (_) {
        throw const ArchiveIntegrityException('不是有效的 ZIP 文件');
      }
      if (archive.length > _maxEntries) {
        throw const ArchiveIntegrityException('归档文件数量异常，已拒绝打开');
      }
      var expanded = 0;
      for (final entry in archive) {
        final name = entry.name.replaceAll('\\', '/');
        if (!_safeArchivePath(name) || entry.isSymbolicLink) {
          throw ArchiveIntegrityException('归档包含不安全路径：$name');
        }
        expanded += entry.size;
        if (expanded > _maxExpandedBytes) {
          throw const ArchiveIntegrityException('归档解压体积异常，已拒绝打开');
        }
        if (entry.isFile) {
          final bytes = entry.readBytes();
          if (bytes == null) {
            throw ArchiveIntegrityException('无法读取归档文件：$name');
          }
          files[name] = _ArchiveBytes(bytes);
        }
      }
    } finally {
      if (archive != null) {
        await Future.wait(archive.map((entry) => entry.close()));
      }
      await input.close();
    }
    for (final required in const [
      'README.md',
      'manifest.json',
      'checksums.sha256',
      'data/fragments.json',
      'data/relations.json',
      'data/islands.json',
      'data/emotions.json',
      'data/audio_library.json',
      'data/preferences.json',
      'data/account.json',
    ]) {
      if (!files.containsKey(required)) {
        throw ArchiveIntegrityException('归档缺少必需文件：$required');
      }
    }
    final manifest =
        _jsonObject(files['manifest.json']!.bytes, 'manifest.json');
    if (manifest['format'] != format || manifest['version'] != version) {
      throw const ArchiveIntegrityException('不支持的隙光归档格式或版本');
    }
    final mediaManifest = manifest['media'];
    if (mediaManifest is! Map) {
      throw const ArchiveIntegrityException('归档媒体清单格式错误');
    }
    for (final raw in mediaManifest.entries) {
      final path = '${raw.key}';
      final descriptor = raw.value;
      if (descriptor is! Map ||
          descriptor['path'] != path ||
          !path.startsWith('media/') ||
          !files.containsKey(path)) {
        throw ArchiveIntegrityException('归档媒体映射无效：$path');
      }
      final mime = '${descriptor['mime'] ?? ''}';
      final expectedSHA = '${descriptor['sha256'] ?? ''}';
      if ((!mime.startsWith('image/') && !mime.startsWith('audio/')) ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedSHA) ||
          p.basenameWithoutExtension(path) != expectedSHA ||
          sha256.convert(files[path]!.bytes).toString() != expectedSHA ||
          (descriptor['size'] as num?)?.toInt() != files[path]!.bytes.length) {
        throw ArchiveIntegrityException('归档媒体类型、大小或校验值无效：$path');
      }
    }
    final checksumLines =
        utf8.decode(files['checksums.sha256']!.bytes).split('\n');
    for (final line in checksumLines) {
      if (line.trim().isEmpty) continue;
      final separator = line.indexOf('  ');
      if (separator != 64) throw const ArchiveIntegrityException('校验清单格式错误');
      final expected = line.substring(0, separator);
      final name = line.substring(separator + 2);
      final entry = files[name];
      if (entry == null || sha256.convert(entry.bytes).toString() != expected) {
        throw ArchiveIntegrityException('文件校验失败：$name');
      }
    }
    return _OpenedArchive(manifest, files);
  }

  Future<void> _writeRecords(
    Directory root,
    List<Map<String, dynamic>> fragments,
    List<Map<String, dynamic>> relations,
    Map<String, String> paths,
  ) async {
    final index = StringBuffer('# 光片索引\n\n');
    for (final fragment in fragments) {
      final id = '${fragment['archive_id']}';
      final recordPath = paths[id]!;
      final relativeFromIndex = p.posix.relative(recordPath, from: 'records');
      final title =
          _markdownText('${fragment['content_text']}').split('\n').first;
      index.writeln(
          '- [${title.isEmpty ? '（空白光片）' : title}]($relativeFromIndex)');
      final created = DateTime.parse('${fragment['created_at']}').toLocal();
      final body = StringBuffer()
        ..writeln('# ${title.isEmpty ? '（空白光片）' : title}')
        ..writeln()
        ..writeln('- 时间：${created.toIso8601String()}')
        ..writeln('- 情绪：${_markdownText('${fragment['emotion']}')}')
        ..writeln(
            '- 标签：${(fragment['tags'] as List).map((e) => _markdownText('$e')).join('、')}')
        ..writeln()
        ..writeln('${fragment['content_text']}')
        ..writeln();
      for (final media in (fragment['media'] as List).whereType<Map>()) {
        final mediaPath = '${media['path']}';
        final relative =
            p.posix.relative(mediaPath, from: p.posix.dirname(recordPath));
        if ('${media['mime']}'.startsWith('image/')) {
          body.writeln('![图片]($relative)');
        } else {
          body.writeln('[播放声音]($relative)');
        }
      }
      final linked = relations.where((relation) =>
          relation['source_archive_id'] == id ||
          relation['target_archive_id'] == id);
      if (linked.isNotEmpty) body.writeln('\n## 织线\n');
      for (final relation in linked) {
        final other = relation['source_archive_id'] == id
            ? '${relation['target_archive_id']}'
            : '${relation['source_archive_id']}';
        final targetPath = paths[other];
        if (targetPath == null) {
          continue;
        }
        final relative =
            p.posix.relative(targetPath, from: p.posix.dirname(recordPath));
        body.writeln(
            '- ${_markdownText('${relation['relation_type']}')} → [另一束光]($relative)');
      }
      final file = File(p.joinAll([root.path, ...recordPath.split('/')]));
      await file.parent.create(recursive: true);
      await file.writeAsString(body.toString(), encoding: utf8);
    }
    final indexFile = File(p.join(root.path, 'records', 'index.md'));
    await indexFile.parent.create(recursive: true);
    await indexFile.writeAsString(index.toString(), encoding: utf8);
  }

  Future<void> _writeChecksums(Directory root) async {
    final entries = await root
        .list(recursive: true, followLinks: false)
        .where((e) => e is File)
        .cast<File>()
        .toList();
    entries.sort((a, b) => a.path.compareTo(b.path));
    final out = StringBuffer();
    for (final file in entries) {
      final relative =
          p.relative(file.path, from: root.path).split(p.separator).join('/');
      if (relative == 'checksums.sha256') continue;
      out.writeln('${await _shaFile(file)}  $relative');
    }
    await File(p.join(root.path, 'checksums.sha256'))
        .writeAsString(out.toString(), encoding: utf8);
  }

  Future<void> _zipFiles(Directory root, String outputPath) async {
    final files = await root
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    final encoder = ZipFileEncoder()..create(outputPath);
    try {
      for (final file in files) {
        final relative =
            p.relative(file.path, from: root.path).split(p.separator).join('/');
        await encoder.addFile(file, relative);
      }
    } finally {
      await encoder.close();
    }
  }

  Future<void> _writeJson(Directory root, String relative, Object value) async {
    final file = File(p.joinAll([root.path, ...relative.split('/')]));
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(value),
        encoding: utf8);
  }

  Future<Map<String, dynamic>> _exportPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'night_mode_option': prefs.getInt('xiguang.night_mode_option'),
      'sync_enabled': prefs.getBool('xiguang.sync.config.enabled'),
      'sync_frequency': prefs.getString('xiguang.sync.config.frequency'),
      'sync_wifi_only': prefs.getBool('xiguang.sync.config.wifi_only'),
    };
  }

  Future<void> _restorePreferences(Map<String, dynamic> values) async {
    final prefs = await SharedPreferences.getInstance();
    final night = values['night_mode_option'];
    if (night is int && night >= 0 && night <= 2) {
      await prefs.setInt('xiguang.night_mode_option', night);
    }
    if (values['sync_enabled'] is bool) {
      await prefs.setBool(
          'xiguang.sync.config.enabled', values['sync_enabled'] as bool);
    }
    if (values['sync_frequency'] is String) {
      await prefs.setString(
          'xiguang.sync.config.frequency', '${values['sync_frequency']}');
    }
    if (values['sync_wifi_only'] is bool) {
      await prefs.setBool(
          'xiguang.sync.config.wifi_only', values['sync_wifi_only'] as bool);
    }
  }

  Future<void> _mergeRelations(
      _OpenedArchive opened, List<Map<String, dynamic>> conflicts) async {
    final fragments = await _db.getAllFragments();
    final fragmentIds = fragments.map((e) => e.publicId).toSet();
    final existing = await _db.select(_db.localRelations).get();
    final existingIds = existing.map((e) => e.publicId).toSet();
    for (final item in opened.jsonList('data/relations.json')) {
      final publicId = '${item['public_id'] ?? item['archive_id'] ?? ''}';
      if (existingIds.contains(publicId)) continue;
      final source = '${item['source_archive_id'] ?? ''}';
      final target = '${item['target_archive_id'] ?? ''}';
      if (!fragmentIds.contains(source) || !fragmentIds.contains(target)) {
        conflicts.add({
          'type': 'relation',
          'public_id': publicId,
          'reason': 'missing_endpoint'
        });
        continue;
      }
      await _db.into(_db.localRelations).insert(LocalRelationsCompanion.insert(
            publicId: publicId,
            sourcePublicId: source,
            targetPublicId: target,
            relationType: '${item['relation_type'] ?? 'echo'}',
            note: Value(item['note']?.toString()),
          ));
    }
  }

  Future<void> _mergeIslands(
      _OpenedArchive opened, List<Map<String, dynamic>> conflicts) async {
    final existing = await _db.select(_db.localIslands).get();
    final existingIds = existing.map((e) => e.publicId).toSet();
    final fragmentIds =
        (await _db.getAllFragments()).map((e) => e.publicId).toSet();
    for (final item in opened.jsonList('data/islands.json')) {
      if (item['manual'] != true) continue;
      final id = '${item['public_id'] ?? item['archive_id'] ?? ''}';
      if (!existingIds.contains(id)) {
        await _db.into(_db.localIslands).insert(LocalIslandsCompanion.insert(
              publicId: id,
              name: '${item['name'] ?? ''}',
              description: Value('${item['description'] ?? ''}'),
              status: Value('${item['status'] ?? 'manual'}'),
              isManual: const Value(true),
            ));
      }
      for (final member in (item['members'] as List? ?? const [])) {
        final fragmentId = '$member';
        if (!fragmentIds.contains(fragmentId)) {
          conflicts.add({
            'type': 'island_member',
            'island_id': id,
            'fragment_id': fragmentId
          });
          continue;
        }
        await _db.into(_db.localIslandMembers).insert(
              LocalIslandMembersCompanion.insert(
                islandPublicId: id,
                fragmentPublicId: fragmentId,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    }
  }

  Future<void> _mergeEmotions(_OpenedArchive opened) async {
    final existing = await _db.select(_db.emotions).get();
    final names = existing.map((e) => e.name).toSet();
    for (final item in opened.jsonList('data/emotions.json')) {
      final name = '${item['name'] ?? ''}'.trim();
      if (name.isEmpty || names.contains(name)) continue;
      await _db.into(_db.emotions).insert(EmotionsCompanion.insert(
            name: name,
            colorHex: (item['color_hex'] as num?)?.toInt() ?? 0xFFC4C4C4,
            description: Value('${item['description'] ?? ''}'),
            isDefault: const Value(false),
            sortOrder:
                Value((item['sort_order'] as num?)?.toInt() ?? names.length),
            soundKey: Value(item['sound_key']?.toString()),
            isUserDefault: Value(item['is_user_default'] == true),
            hidden: Value(item['hidden'] == true),
          ));
      names.add(name);
    }
  }

  Future<void> _mergeAudioLibrary(
      _OpenedArchive opened, Map<String, String> mediaPaths) async {
    final existing = await _db.select(_db.audioLibrary).get();
    final keys = existing.map((e) => e.key).toSet();
    for (final item in opened.jsonList('data/audio_library.json')) {
      final key = '${item['key'] ?? ''}';
      final media = item['media'];
      if (key.isEmpty || keys.contains(key) || media is! Map) continue;
      final filePath = mediaPaths['${media['path']}'];
      if (filePath == null) throw ArchiveIntegrityException('个人声音库媒体映射缺失：$key');
      await _db.into(_db.audioLibrary).insert(AudioLibraryCompanion.insert(
            key: key,
            name: '${item['name'] ?? key}',
            filePath: filePath,
            createdAt: Value(
                DateTime.tryParse('${item['created_at']}') ?? DateTime.now()),
          ));
    }
  }

  bool _sameFragment(Fragment existing, Map<String, dynamic> incoming) {
    return existing.contentText == '${incoming['content_text'] ?? ''}' &&
        existing.emotion == '${incoming['emotion'] ?? '说不清'}' &&
        jsonEncode(_stringList(existing.tags)) ==
            jsonEncode(_stringList(incoming['tags']));
  }

  static Future<String> _shaFile(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();
  static List<String> _stringList(Object? value) => value is String
      ? ((jsonDecode(value) as List?) ?? const []).map((e) => '$e').toList()
      : (value as List? ?? const []).map((e) => '$e').toList();
  static bool _safeArchivePath(String value) {
    if (value.isEmpty ||
        value.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(value)) {
      return false;
    }
    return !value.split('/').contains('..');
  }

  static String _safeExtension(String source) {
    final extension =
        p.extension(Uri.tryParse(source)?.path ?? source).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension)
        ? extension
        : '.bin';
  }

  static String _mime(String extension) => switch (extension) {
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.heic' => 'image/heic',
        '.gif' => 'image/gif',
        '.mp3' => 'audio/mpeg',
        '.wav' => 'audio/wav',
        '.aac' => 'audio/aac',
        '.ogg' || '.opus' => 'audio/ogg',
        '.m4a' => 'audio/mp4',
        _ => 'application/octet-stream',
      };
  static String _extensionForMime(String mime) => switch (mime) {
        'image/jpeg' => '.jpg',
        'image/png' => '.png',
        'image/webp' => '.webp',
        'image/heic' => '.heic',
        'audio/mpeg' => '.mp3',
        'audio/wav' => '.wav',
        'audio/aac' => '.aac',
        'audio/ogg' => '.ogg',
        'audio/opus' => '.opus',
        _ when mime.startsWith('audio/') => '.m4a',
        _ => '.bin',
      };
  static Map<String, dynamic> _jsonObject(Uint8List bytes, String name) {
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ArchiveIntegrityException('JSON 文件无效：$name');
    }
  }

  static String _markdownText(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('[', '\\[')
      .replaceAll(']', '\\]');
  static String _two(int value) => value.toString().padLeft(2, '0');
  static String _fileTimestamp(DateTime value) =>
      '${value.year}-${_two(value.month)}-${_two(value.day)}-${_two(value.hour)}${_two(value.minute)}${_two(value.second)}';
}

class _Snapshot {
  const _Snapshot(
      {required this.fragments,
      required this.relations,
      required this.islands,
      required this.islandMembers,
      required this.emotions,
      required this.audioLibrary});
  final List<Fragment> fragments;
  final List<LocalRelationEntry> relations;
  final List<LocalIslandEntry> islands;
  final List<LocalIslandMemberEntry> islandMembers;
  final List<Emotion> emotions;
  final List<AudioLibraryEntry> audioLibrary;
}

class _MediaSource {
  const _MediaSource(this.source, this.fragmentPublicId, this.library);
  final String source;
  final String fragmentPublicId;
  final bool library;
}

class _StagedMedia {
  const _StagedMedia(this.file, this.mime, this.extension, this.temporary);
  final File file;
  final String mime;
  final String extension;
  final bool temporary;
}

class _DataUrl {
  const _DataUrl(this.bytes, this.mime, this.extension);
  final Uint8List bytes;
  final String mime;
  final String extension;
}

class _ArchiveBytes {
  const _ArchiveBytes(this.bytes);
  final Uint8List bytes;
  bool get isFile => true;
}

class _OpenedArchive {
  const _OpenedArchive(this.manifest, this.files);
  final Map<String, dynamic> manifest;
  final Map<String, _ArchiveBytes> files;
  List<Map<String, dynamic>> jsonList(String name) {
    try {
      return (jsonDecode(utf8.decode(files[name]!.bytes)) as List)
          .cast<Map<String, dynamic>>();
    } catch (_) {
      throw ArchiveIntegrityException('JSON 列表无效：$name');
    }
  }

  Map<String, dynamic> jsonMap(String name) =>
      LocalArchiveExporter._jsonObject(files[name]!.bytes, name);
}
