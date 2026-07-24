import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/archive_models.dart';

export '../../../app/providers.dart'
    show fragmentRepositoryProvider, localArchiveRepositoryProvider;

final exportLocalArchiveProvider = Provider<ExportLocalArchive>((ref) {
  return ExportLocalArchive(ref);
});

class ExportLocalArchive {
  const ExportLocalArchive(this._ref);

  final Ref _ref;

  Stream<ArchiveProgress> call(ArchiveExportRequest request) {
    return _ref.read(localArchiveRepositoryProvider).exportArchive(request);
  }
}
