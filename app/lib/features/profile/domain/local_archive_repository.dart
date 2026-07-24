import 'archive_models.dart';

abstract interface class LocalArchiveRepositoryPort {
  Future<ArchivePreflight> preflightExport();

  Stream<ArchiveProgress> exportArchive(ArchiveExportRequest request);

  Future<ArchiveImportPreview> inspectArchive(String zipPath);

  Stream<ArchiveProgress> importArchive(ArchiveImportRequest request);

  Future<void> verifyArchive(String zipPath);
}
