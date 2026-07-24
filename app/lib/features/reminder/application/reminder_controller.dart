import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import 'reminder_providers.dart';
import '../domain/reminder_settings.dart';

final reminderControllerProvider = Provider<ReminderController>((ref) {
  return ReminderController(ref);
});

class ReminderController {
  const ReminderController(this._ref);

  final Ref _ref;

  Future<bool> requestPermission() {
    return _ref.read(localReminderServiceProvider).requestPermission();
  }

  Future<void> saveAndSchedule(
    ReminderSettings settings, {
    required bool showPreview,
  }) async {
    await _ref.read(reminderSettingsProvider.notifier).save(settings);
    final fragments =
        await _ref.read(fragmentRepositoryProvider).listLocalFragments();
    await _ref.read(localReminderServiceProvider).schedule(
          settings: settings,
          fragments: fragments,
          showPreview: showPreview,
        );
  }
}
