import '../../fragment/domain/fragment.dart';

class DateGroup {
  const DateGroup({
    required this.dateLabel,
    required this.fragments,
    this.emotionDots = const [],
  });

  final String dateLabel;
  final List<Fragment> fragments;
  final List<String> emotionDots;
}
