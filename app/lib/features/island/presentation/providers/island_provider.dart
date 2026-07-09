import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/island_model.dart';

final selectedIslandProvider = StateProvider<IslandModel?>((ref) => null);
