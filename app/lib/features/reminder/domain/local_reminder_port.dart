import '../../fragment/domain/fragment.dart';
import 'reminder_settings.dart';

abstract interface class LocalReminderPort {
  Future<bool> requestPermission();
  Future<void> schedule({
    required ReminderSettings settings,
    required List<Fragment> fragments,
    required bool showPreview,
  });
}
