import 'package:freezed_annotation/freezed_annotation.dart';

import '../../fragment/domain/fragment.dart';

part 'date_group.freezed.dart';

/// 日期分组 — 时间河流中的一个日期节点
@freezed
class DateGroup with _$DateGroup {
  const factory DateGroup({
    required String dateLabel,
    required List<Fragment> fragments,
    @Default([]) List<String> emotionDots,
  }) = _DateGroup;
}
