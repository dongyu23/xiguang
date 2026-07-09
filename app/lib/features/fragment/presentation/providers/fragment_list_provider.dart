import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/fragment.dart';

final fragmentListSnapshotProvider = StateProvider<List<Fragment>>((ref) {
  return const [];
});
