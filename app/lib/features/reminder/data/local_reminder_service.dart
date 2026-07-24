import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../design/tokens/motion.dart';
import '../../fragment/domain/fragment.dart';
import '../domain/local_reminder_port.dart';
import '../domain/reminder_settings.dart';

class LocalReminderService implements LocalReminderPort {
  static const captureReminderId = 4101;
  static const oldLightReminderId = 4102;
  static const islandQuietReminderId = 4103;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    }
    if (Platform.isMacOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<void> schedule({
    required ReminderSettings settings,
    required List<Fragment> fragments,
    required bool showPreview,
  }) async {
    await initialize();
    await Future.wait([
      _plugin.cancel(id: captureReminderId),
      _plugin.cancel(id: oldLightReminderId),
      _plugin.cancel(id: islandQuietReminderId),
    ]);
    if (fragments.isEmpty) return;
    final sorted = [...fragments]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = sorted.first;
    final now = DateTime.now();

    if (settings.captureReminder) {
      await _schedule(
        captureReminderId,
        '给此刻留一点光',
        '有一阵没有捕光了。想写一句，也可以只放下一张图片。',
        _futureOrSoon(
            latest.createdAt.add(AppTiming.captureReminderDelay), now),
        '/capture',
      );
    }
    if (settings.oldLightReminder) {
      final old = sorted.cast<Fragment?>().firstWhere(
            (item) =>
                item!.createdAt.isBefore(now.subtract(AppTiming.oldLightAge)),
            orElse: () => null,
          );
      if (old != null) {
        final preview = old.contentText.trim().replaceAll(RegExp(r'\s+'), ' ');
        await _schedule(
          oldLightReminderId,
          '有一束旧光想见你',
          showPreview && preview.isNotEmpty
              ? (preview.length > 36 ? '${preview.substring(0, 36)}…' : preview)
              : '打开时间河，轻轻看一眼过去的自己。',
          now.add(AppTiming.oldLightReminderDelay),
          '/timeline',
        );
      }
    }
    if (settings.islandQuietReminder) {
      await _schedule(
        islandQuietReminderId,
        '有些小岛静了一阵',
        '如果你愿意，可以回去看看那些反复出现过的主题。',
        _futureOrSoon(
            latest.createdAt.add(AppTiming.islandQuietReminderDelay), now),
        '/universe',
      );
    }
  }

  DateTime _futureOrSoon(DateTime target, DateTime now) {
    return target.isAfter(now)
        ? target
        : now.add(AppTiming.reminderMinimumLead);
  }

  Future<void> _schedule(
      int id, String title, String body, DateTime when, String payload) {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'gentle_reminders',
        '柔光提醒',
        channelDescription: '旧光回访、捕光和小岛静默提醒',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
    return _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when.toUtc(), tz.UTC),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }
}
