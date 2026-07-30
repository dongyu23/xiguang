import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/archive_models.dart';

final localArchiveControllerProvider = Provider<LocalArchiveController>((ref) {
  return LocalArchiveController(ref);
});

class LocalArchiveController {
  const LocalArchiveController(this._ref);

  final Ref _ref;

  Future<ArchivePreflight> preflightExport() {
    return _ref.read(localArchiveRepositoryProvider).preflightExport();
  }

  Stream<ArchiveProgress> exportArchive(ArchiveExportRequest request) {
    return _ref.read(localArchiveRepositoryProvider).exportArchive(request);
  }

  Future<ArchiveImportPreview> inspectArchive(String path) {
    return _ref.read(localArchiveRepositoryProvider).inspectArchive(path);
  }

  Stream<ArchiveProgress> importArchive(ArchiveImportRequest request) {
    return _ref.read(localArchiveRepositoryProvider).importArchive(request);
  }

  Future<void> verifyArchive(String path) {
    return _ref.read(localArchiveRepositoryProvider).verifyArchive(path);
  }
}
