class IslandLayoutPreferences {
  const IslandLayoutPreferences({
    this.favorites = const {},
    this.order = const [],
  });

  final Set<String> favorites;
  final List<String> order;

  bool isFavorite(String visualKey) => favorites.contains(visualKey);

  Map<String, Object> toJson() => {
        'favorites': favorites.toList(),
        'order': order,
      };

  static IslandLayoutPreferences fromJson(Object? value) {
    if (value is! Map) return const IslandLayoutPreferences();
    final rawFavorites = value['favorites'];
    final rawOrder = value['order'];
    return IslandLayoutPreferences(
      favorites: Set.unmodifiable(
        rawFavorites is List
            ? rawFavorites.whereType<String>().toSet()
            : <String>{},
      ),
      order: List.unmodifiable(
        rawOrder is List ? rawOrder.whereType<String>() : const <String>[],
      ),
    );
  }
}
