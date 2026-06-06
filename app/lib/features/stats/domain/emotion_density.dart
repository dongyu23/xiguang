class EmotionDensity {
  const EmotionDensity({required this.period, required this.emotions});

  final String period;
  final List<EmotionDensityItem> emotions;
}

class EmotionDensityItem {
  const EmotionDensityItem({
    required this.name,
    required this.count,
    required this.percentage,
  });

  final String name;
  final int count;
  final double percentage;
}
