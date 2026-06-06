import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../domain/date_group.dart';
import '../../domain/timeline_query.dart';

final timelineGroupsProvider = FutureProvider<List<DateGroup>>((ref) async {
  return ref.watch(timelineRepositoryProvider).list(const TimelineQuery());
});
