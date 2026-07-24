import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers.dart';
import '../domain/island_layout_preferences.dart';

final islandLayoutPreferencesProvider = AutoDisposeAsyncNotifierProvider<
    IslandLayoutPreferencesController,
    IslandLayoutPreferences>(IslandLayoutPreferencesController.new);

class IslandLayoutPreferencesController
    extends AutoDisposeAsyncNotifier<IslandLayoutPreferences> {
  late final String _storageKey;

  @override
  Future<IslandLayoutPreferences> build() async {
    final account =
        ref.read(authRepositoryProvider).currentSession?.publicId.trim();
    _storageKey =
        'xiguang.island_layout.v1.${account == null || account.isEmpty ? 'local' : account}';
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) {
      return const IslandLayoutPreferences();
    }
    try {
      return IslandLayoutPreferences.fromJson(jsonDecode(encoded));
    } on FormatException {
      return const IslandLayoutPreferences();
    }
  }

  Future<void> toggleFavorite(String visualKey) async {
    final current = state.valueOrNull ?? const IslandLayoutPreferences();
    final favorites = current.favorites.toSet();
    if (!favorites.remove(visualKey)) favorites.add(visualKey);
    await _save(IslandLayoutPreferences(
      favorites: Set.unmodifiable(favorites),
      order: current.order,
    ));
  }

  Future<void> swap(
    String visualKey,
    String targetVisualKey,
    List<String> currentOrder,
  ) async {
    if (visualKey == targetVisualKey) return;
    final current = state.valueOrNull ?? const IslandLayoutPreferences();
    final order = <String>[];
    for (final key in currentOrder) {
      if (!order.contains(key)) order.add(key);
    }
    final from = order.indexOf(visualKey);
    final target = order.indexOf(targetVisualKey);
    if (from < 0 || target < 0) return;
    final displaced = order[target];
    order[target] = order[from];
    order[from] = displaced;
    await _save(IslandLayoutPreferences(
      favorites: current.favorites,
      order: List.unmodifiable(order),
    ));
  }

  Future<void> _save(IslandLayoutPreferences value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(value.toJson()));
  }
}
