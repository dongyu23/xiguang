import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiguang/features/island/application/island_layout_controller.dart';

void main() {
  test('favorites and automatic island order persist', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    addTearDown(first.dispose);
    await first.read(islandLayoutPreferencesProvider.future);

    await first
        .read(islandLayoutPreferencesProvider.notifier)
        .toggleFavorite('island-7');
    await first.read(islandLayoutPreferencesProvider.notifier).swap(
      'island-3',
      'island-1',
      const ['island-1', 'island-2', 'island-3'],
    );

    final saved = first.read(islandLayoutPreferencesProvider).requireValue;
    expect(saved.isFavorite('island-7'), isTrue);
    expect(saved.order, ['island-3', 'island-2', 'island-1']);

    final second = ProviderContainer();
    addTearDown(second.dispose);
    final restored = await second.read(islandLayoutPreferencesProvider.future);
    expect(restored.isFavorite('island-7'), isTrue);
    expect(restored.order, ['island-3', 'island-2', 'island-1']);
  });
}
