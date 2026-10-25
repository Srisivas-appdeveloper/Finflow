import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/services/bill_reminders.dart';

/// Schedules local bill reminders. All data stays on the device; nothing is
/// sent anywhere.
abstract interface class ReminderScheduler {
  /// Asks the OS for notification permission (Android 13+). Returns whether
  /// notifications are allowed.
  Future<bool> requestPermission();

  /// Replaces all scheduled reminders with [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);

  Future<void> cancelAll();
}

/// Used in tests and when notifications are unavailable.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {}

  @override
  Future<void> cancelAll() async {}
}

/// [ReminderScheduler] using the platform notification system.
///
/// Uses inexact alarms (`inexactAllowWhileIdle`), which need no special
/// "exact alarm" permission and are batched by Android to save battery: a
/// reminder may arrive some minutes late, which is fine for a bill due date.
class LocalNotificationReminderScheduler implements ReminderScheduler {
  LocalNotificationReminderScheduler._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channel = AndroidNotificationDetails(
    'bill_reminders',
    'Bill reminders',
    channelDescription: 'Reminders before credit card bills are due',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_finflow',
  );

  static Future<ReminderScheduler> create() async {
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_finflow'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      return LocalNotificationReminderScheduler._(plugin);
    } catch (error, stack) {
      // Reminders are a convenience: never block app start-up on them.
      debugPrint('Reminders unavailable: $error\n$stack');
      return const NoopReminderScheduler();
    }
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await _plugin.cancelAll();
    // Android limits pending alarms per app; the nearest 40 are plenty.
    for (var i = 0; i < reminders.length && i < 40; i++) {
      final r = reminders[i];
      await _plugin.zonedSchedule(
        id: i,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: const NotificationDetails(
          android: _channel,
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: r.billId,
      );
    }
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
