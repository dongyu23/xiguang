import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/island_repository.dart';

final selectedIslandProvider = StateProvider<IslandModel?>((ref) => null);
