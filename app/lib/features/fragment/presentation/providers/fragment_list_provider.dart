import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/fragment_repository.dart';

final fragmentListSnapshotProvider =
    StateProvider<List<LightFragmentModel>>((ref) {
  return seedFragments;
});
