class SpaceTheme {
  const SpaceTheme({
    required this.id,
    required this.name,
    required this.primaryColorHex,
    required this.description,
    this.requiredTier = 'glimmer',
    this.locked = false,
    this.selected = false,
  });

  final String id;
  final String name;
  final String primaryColorHex;
  final String description;
  final String requiredTier;
  final bool locked;
  final bool selected;
}
