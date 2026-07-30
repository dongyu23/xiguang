class NoiseAudio {
  const NoiseAudio({
    required this.id,
    required this.name,
    required this.icon,
    required this.audioFile,
    required this.category,
    this.requiredTier = 'glimmer',
    this.locked = false,
  });

  final String id;
  final String name;
  final String icon;
  final String audioFile;
  final String category;
  final String requiredTier;
  final bool locked;

  NoiseAudio copyWith({bool? locked}) => NoiseAudio(
        id: id,
        name: name,
        icon: icon,
        audioFile: audioFile,
        category: category,
        requiredTier: requiredTier,
        locked: locked ?? this.locked,
      );
}
