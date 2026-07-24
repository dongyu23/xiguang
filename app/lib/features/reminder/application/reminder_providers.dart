import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reminder_settings.dart';

const _captureKey = 'xiguang.reminder.capture';
const _oldLightKey = 'xiguang.reminder.old_light';
const _islandKey = 'xiguang.reminder.island_quiet';

final reminderSettingsProvider =
    AsyncNotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
  ReminderSettingsNotifier.new,
);

class ReminderSettingsNotifier extends AsyncNotifier<ReminderSettings> {
  @override
  Future<ReminderSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderSettings(
      captureReminder: prefs.getBool(_captureKey) ?? false,
      oldLightReminder: prefs.getBool(_oldLightKey) ?? false,
      islandQuietReminder: prefs.getBool(_islandKey) ?? false,
    );
  }

  Future<void> save(ReminderSettings value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_captureKey, value.captureReminder),
      prefs.setBool(_oldLightKey, value.oldLightReminder),
      prefs.setBool(_islandKey, value.islandQuietReminder),
    ]);
  }
}
