import '../../fragment/domain/fragment.dart';
import 'local_export_result.dart';

abstract interface class LocalArchiveRepositoryPort {
  Future<LocalExportResult> exportFragments(List<Fragment> fragments);
}
