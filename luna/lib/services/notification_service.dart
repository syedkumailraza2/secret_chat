import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../providers/cycle_provider.dart';
import '../providers/settings_provider.dart';

/// Offline scheduled reminders via flutter_local_notifications.
///
/// Copy is deliberately discreet: notifications can appear on the lock
/// screen, so titles never mention periods.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _dailyId = 1;
  static const _periodId = 2;

  static const _channel = AndroidNotificationChannel(
    'luna_reminders',
    'Reminders',
    description: 'Gentle check-in reminders',
    importance: Importance.defaultImportance,
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Call once from main() before runApp. Never requests permission.
  Future<void> init() async {
    if (_ready || !_supported) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      _ready = true;
    } catch (e) {
      debugPrint('NotificationService.init failed: $e');
    }
  }

  /// Returns true when the OS granted notification permission.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: false, sound: true) ?? false;
      }
    } catch (e) {
      debugPrint('NotificationService.requestPermission failed: $e');
    }
    return false;
  }

  NotificationDetails get _details => NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          // Hide content on a secure lock screen.
          visibility: NotificationVisibility.private,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  /// Cancels everything and schedules what is enabled:
  /// - daily check-in at [dailyTime] when [dailyEnabled]
  /// - period heads-up 2 days before [nextPeriod] (at [dailyTime]) when [periodEnabled]
  Future<void> reschedule({
    required bool dailyEnabled,
    required bool periodEnabled,
    required TimeOfDay dailyTime,
    DateTime? nextPeriod,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final now = tz.TZDateTime.now(tz.local);

      if (dailyEnabled) {
        var at = tz.TZDateTime(
            tz.local, now.year, now.month, now.day, dailyTime.hour, dailyTime.minute);
        if (!at.isAfter(now)) {
          at = tz.TZDateTime(
              tz.local, now.year, now.month, now.day + 1, dailyTime.hour, dailyTime.minute);
        }
        await _plugin.zonedSchedule(
          id: _dailyId,
          scheduledDate: at,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'Luna',
          body: 'A gentle nudge — 20 seconds to log today.',
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }

      if (periodEnabled && nextPeriod != null) {
        // nextPeriod is a dayKey (UTC midnight of a local calendar day):
        // read its y/m/d as a local calendar date.
        final at = tz.TZDateTime(tz.local, nextPeriod.year, nextPeriod.month,
            nextPeriod.day - 2, dailyTime.hour, dailyTime.minute);
        if (at.isAfter(now)) {
          await _plugin.zonedSchedule(
            id: _periodId,
            scheduledDate: at,
            notificationDetails: _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: 'Luna',
            body: 'Your cycle may start in about 2 days.',
          );
        }
      }
    } catch (e) {
      debugPrint('NotificationService.reschedule failed: $e');
    }
  }

  /// Keeps scheduled reminders in sync with settings and predictions.
  /// Reschedules (debounced) only when an input actually changes.
  void bind(SettingsProvider settings, CycleProvider cycle) {
    String? lastKey;
    Timer? debounce;
    void sync() {
      final t = settings.reminderTime;
      final next = cycle.snapshot?.nextPeriodStart;
      final key = '${settings.dailyReminderEnabled}|${settings.periodReminderEnabled}|'
          '${t.hour}:${t.minute}|${next?.toIso8601String()}';
      if (key == lastKey) return;
      lastKey = key;
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 400), () {
        reschedule(
          dailyEnabled: settings.dailyReminderEnabled,
          periodEnabled: settings.periodReminderEnabled,
          dailyTime: t,
          nextPeriod: next,
        );
      });
    }

    settings.addListener(sync);
    cycle.addListener(sync);
    sync();
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
