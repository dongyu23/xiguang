import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/tokens/motion.dart';

/// UI state owned by the application shell, not by dependency injection.
enum NightModeOption { system, light, dark }

final nightModeOptionProvider = StateProvider<NightModeOption>(
  (ref) => NightModeOption.system,
);

final nightModeProvider = StateProvider<bool>((ref) => false);

final nightModeLoadedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final optionIndex = prefs.getInt('xiguang.night_mode_option');
  final option = optionIndex == null
      ? ((prefs.getBool('xiguang.night_mode') ?? false)
          ? NightModeOption.dark
          : NightModeOption.system)
      : NightModeOption.values[optionIndex];
  ref.read(nightModeOptionProvider.notifier).state = option;
  final isNight = resolveNightMode(option);
  ref.read(nightModeProvider.notifier).state = isNight;
  _startAutoSwitchTimer(ref);
  ref.onDispose(stopAutoSwitchTimer);
  return isNight;
});

bool resolveNightMode(NightModeOption option) {
  return switch (option) {
    NightModeOption.system =>
      TimeOfDay.now().hour < 6 || TimeOfDay.now().hour >= 18,
    NightModeOption.light => false,
    NightModeOption.dark => true,
  };
}

Timer? _autoSwitchTimer;

void _startAutoSwitchTimer(Ref ref) {
  _autoSwitchTimer?.cancel();
  _autoSwitchTimer = Timer.periodic(AppTiming.themeModePoll, (_) {
    final option = ref.read(nightModeOptionProvider);
    if (option == NightModeOption.system) {
      ref.read(nightModeProvider.notifier).state = resolveNightMode(option);
    }
  });
}

void stopAutoSwitchTimer() {
  _autoSwitchTimer?.cancel();
  _autoSwitchTimer = null;
}

Future<void> updateNightModeOption(
  WidgetRef ref,
  NightModeOption option,
) async {
  ref.read(nightModeOptionProvider.notifier).state = option;
  ref.read(nightModeProvider.notifier).state = resolveNightMode(option);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('xiguang.night_mode_option', option.index);
  await prefs.setBool('xiguang.night_mode', resolveNightMode(option));
}

/// App-shell UI state. Feature workflows must own their own state instead.
final aiPolishEnabledProvider = StateProvider<bool>((ref) => false);
final activeTabIndexProvider = StateProvider<int>((ref) => 0);
final scrollToTopSignalProvider = StateProvider<int>((ref) => 0);
