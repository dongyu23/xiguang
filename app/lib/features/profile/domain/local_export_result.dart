class LocalExportResult {
  const LocalExportResult({
    required this.directoryPath,
    required this.markdownPath,
    required this.fragmentCount,
    required this.mediaCount,
  });

  final String directoryPath;
  final String markdownPath;
  final int fragmentCount;
  final int mediaCount;
}
