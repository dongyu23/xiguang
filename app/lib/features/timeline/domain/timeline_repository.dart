import 'date_group.dart';
import 'timeline_query.dart';

abstract interface class TimelineRepositoryContract {
  Future<List<DateGroup>> list(TimelineQuery query);
}
