import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/timeline_query.dart';

final timelineFilterProvider = StateProvider<TimelineQuery>((ref) {
  return const TimelineQuery();
});
