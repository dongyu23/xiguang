import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/archive_models.dart';

export '../../../app/providers.dart'
    show fragmentRepositoryProvider, localArchiveRepositoryProvider;

final exportLocalArchiveProvider = Provider<ExportLocalArchive>((ref) {
  return ExportLocalArchive(ref);
});

final localArchiveActionsProvider = Provider<LocalArchiveActions>((ref) {
  return LocalArchiveActions(ref);
});

class ExportLocalArchive {
  const ExportLocalArchive(this._ref);

  final Ref _ref;

  Stream<ArchiveProgress> call(ArchiveExportRequest request) {
    return _ref.read(localArchiveRepositoryProvider).exportArchive(request);
  }
}

/// Application boundary for the complete local archive workflow.
class LocalArchiveActions {
  const LocalArchiveActions(this._ref);

  final Ref _ref;

  Future<ArchivePreflight> preflightExport() =>
      _ref.read(localArchiveRepositoryProvider).preflightExport();

  Stream<ArchiveProgress> exportArchive(ArchiveExportRequest request) =>
      _ref.read(localArchiveRepositoryProvider).exportArchive(request);

  Future<ArchiveImportPreview> inspectArchive(String zipPath) =>
      _ref.read(localArchiveRepositoryProvider).inspectArchive(zipPath);

  Stream<ArchiveProgress> importArchive(ArchiveImportRequest request) =>
      _ref.read(localArchiveRepositoryProvider).importArchive(request);

  Future<void> verifyArchive(String zipPath) =>
      _ref.read(localArchiveRepositoryProvider).verifyArchive(zipPath);
}
