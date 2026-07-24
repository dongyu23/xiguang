enum ArchivePhase {
  preflight,
  media,
  generate,
  compress,
  verify,
  save,
  restore,
  cloud,
}

class ArchiveIssue {
  const ArchiveIssue({required this.code, required this.message, this.source});

  final String code;
  final String message;
  final String? source;
}

class ArchivePreflight {
  const ArchivePreflight({
    required this.fragmentCount,
    required this.mediaCount,
    required this.estimatedBytes,
    this.issues = const [],
  });

  final int fragmentCount;
  final int mediaCount;
  final int estimatedBytes;
  final List<ArchiveIssue> issues;
  bool get canExport => issues.isEmpty;
}

class ArchiveExportRequest {
  const ArchiveExportRequest({
    required this.sourceAccountPublicId,
    required this.username,
    this.nickname = '',
  });

  final String sourceAccountPublicId;
  final String username;
  final String nickname;
}

class ArchiveImportRequest {
  const ArchiveImportRequest({required this.zipPath});

  final String zipPath;
  String get conflictPolicy => 'keepExisting';
}

class ArchiveExportResult {
  const ArchiveExportResult({
    required this.archiveId,
    required this.zipPath,
    required this.fragmentCount,
    required this.mediaCount,
    required this.bytes,
  });

  final String archiveId;
  final String zipPath;
  final int fragmentCount;
  final int mediaCount;
  final int bytes;
}

class ArchiveImportPreview {
  const ArchiveImportPreview({
    required this.archiveId,
    required this.exportedAt,
    required this.sourceAccountPublicId,
    required this.counts,
    required this.additions,
    required this.duplicates,
    required this.conflicts,
  });

  final String archiveId;
  final DateTime exportedAt;
  final String sourceAccountPublicId;
  final Map<String, int> counts;
  final int additions;
  final int duplicates;
  final int conflicts;
}

class ArchiveImportResult {
  const ArchiveImportResult({
    required this.added,
    required this.skipped,
    required this.conflicts,
    required this.pendingCloud,
    required this.reportPath,
  });

  final int added;
  final int skipped;
  final int conflicts;
  final int pendingCloud;
  final String reportPath;
}

class ArchiveProgress {
  const ArchiveProgress({
    required this.phase,
    required this.fraction,
    required this.message,
    this.processedFiles = 0,
    this.totalFiles = 0,
    this.exportResult,
    this.importResult,
  });

  final ArchivePhase phase;
  final double fraction;
  final String message;
  final int processedFiles;
  final int totalFiles;
  final ArchiveExportResult? exportResult;
  final ArchiveImportResult? importResult;
}

class ArchiveIntegrityException implements Exception {
  const ArchiveIntegrityException(this.message, {this.issues = const []});

  final String message;
  final List<ArchiveIssue> issues;

  @override
  String toString() => message;
}
