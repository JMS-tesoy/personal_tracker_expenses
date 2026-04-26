// lib/features/reminders/services/local_notification_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/reminder_model.dart';

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Initialization ──────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  // ── Permission ──────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (android != null) {
        final bool? granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }

      final IOSFlutterLocalNotificationsPlugin? ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      if (ios != null) {
        final bool? granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      return false;
    } catch (e) {
      debugPrint('LocalNotificationService.requestPermission error: $e');
      return false;
    }
  }

  // ── Schedule from model ─────────────────────────────────────────────────────

  Future<int?> scheduleFromReminderModel(ReminderModel reminder) async {
    if (reminder.remindAt.isBefore(DateTime.now())) {
      debugPrint(
        'LocalNotificationService: remind_at is in the past — skipping.',
      );
      return null;
    }

    final int notifId =
        reminder.notificationId ?? _stableIdFromUuid(reminder.id);

    final String body = reminder.message?.isNotEmpty == true
        ? reminder.message!
        : _defaultBody(reminder);

    return scheduleReminder(
      id: notifId,
      title: reminder.title,
      body: body,
      remindAt: reminder.remindAt,
    );
  }

  Future<int?> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime remindAt,
  }) async {
    if (!_initialized) await initialize();
    if (remindAt.isBefore(DateTime.now())) return null;

    try {
      final tz.TZDateTime tzRemindAt = tz.TZDateTime.from(remindAt, tz.local);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'reminders_channel',
            'Reminders',
            channelDescription: 'App reminders for bills, loans, and more',
            importance: Importance.high,
            priority: Priority.high,
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzRemindAt,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      return id;
    } catch (e) {
      debugPrint('LocalNotificationService.scheduleReminder error: $e');
      return null;
    }
  }

  // ── Cancel ──────────────────────────────────────────────────────────────────

  Future<void> cancelReminder(int id) async {
    if (!_initialized) await initialize();
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('LocalNotificationService.cancelReminder error: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) await initialize();
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('LocalNotificationService.cancelAll error: $e');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  int _stableIdFromUuid(String uuid) {
    final String clean = uuid.replaceAll('-', '');
    return clean.hashCode.abs() % 2147483647;
  }

  String _defaultBody(ReminderModel reminder) {
    return switch (reminder.targetType) {
      'bill' => 'Your bill reminder is due.',
      'loan' => 'Loan payday payment is due.',
      'person' => 'You have a responsibility reminder.',
      'payment' => 'Payment reminder.',
      _ => reminder.title,
    };
  }
}
