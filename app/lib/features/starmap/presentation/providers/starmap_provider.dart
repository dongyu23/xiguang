import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../domain/star_graph.dart';

final starGraphProvider = FutureProvider<StarGraph>((ref) async {
  return ref.watch(starMapRepositoryProvider).load();
});
