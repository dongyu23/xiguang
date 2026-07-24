class ReminderSettings {
  const ReminderSettings({
    this.captureReminder = false,
    this.oldLightReminder = false,
    this.islandQuietReminder = false,
  });

  final bool captureReminder;
  final bool oldLightReminder;
  final bool islandQuietReminder;

  ReminderSettings copyWith({
    bool? captureReminder,
    bool? oldLightReminder,
    bool? islandQuietReminder,
  }) {
    return ReminderSettings(
      captureReminder: captureReminder ?? this.captureReminder,
      oldLightReminder: oldLightReminder ?? this.oldLightReminder,
      islandQuietReminder: islandQuietReminder ?? this.islandQuietReminder,
    );
  }
}
