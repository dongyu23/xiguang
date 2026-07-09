import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/local_export_result.dart';

export '../../../app/providers.dart'
    show fragmentRepositoryProvider, localArchiveRepositoryProvider;

final exportLocalArchiveProvider = Provider<ExportLocalArchive>((ref) {
  return ExportLocalArchive(ref);
});

class ExportLocalArchive {
  const ExportLocalArchive(this._ref);

  final Ref _ref;

  Future<LocalExportResult> call() async {
    final fragments =
        await _ref.read(fragmentRepositoryProvider).listFragments();
    return _ref.read(localArchiveRepositoryProvider).exportFragments(fragments);
  }
}
