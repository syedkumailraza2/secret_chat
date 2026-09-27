import 'package:flutter/material.dart';

import '../database/isar_service.dart';
import '../models/app_settings.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._db);

  final IsarService _db;
  AppSettings _settings = AppSettings();
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get loaded => _loaded;
  bool get onboardingComplete => _settings.onboardingComplete;
  int get cycleLength => _settings.defaultCycleLength;
  int get periodLength => _settings.defaultPeriodLength;
  bool get biometricLockEnabled => _settings.biometricLockEnabled;
  bool get periodReminderEnabled => _settings.periodReminderEnabled;
  bool get dailyReminderEnabled => _settings.dailyReminderEnabled;

  /// Hour/minute of the daily reminder; defaults to 8:00 PM.
  TimeOfDay get reminderTime {
    final t = _settings.reminderTime;
    return t == null ? const TimeOfDay(hour: 20, minute: 0) : TimeOfDay(hour: t.hour, minute: t.minute);
  }

  ThemeMode get themeMode => switch (_settings.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> load() async {
    _settings = await _db.getSettings();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _update(void Function(AppSettings s) change) async {
    change(_settings);
    await _db.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> completeOnboarding({required int cycleLength, required int periodLength}) =>
      _update((s) {
        s.defaultCycleLength = cycleLength;
        s.defaultPeriodLength = periodLength;
        s.onboardingComplete = true;
      });

  Future<void> setCycleLength(int v) => _update((s) => s.defaultCycleLength = v);
  Future<void> setPeriodLength(int v) => _update((s) => s.defaultPeriodLength = v);
  Future<void> setPeriodReminder(bool v) => _update((s) => s.periodReminderEnabled = v);
  Future<void> setDailyReminder(bool v) => _update((s) => s.dailyReminderEnabled = v);
  Future<void> setReminderTime(TimeOfDay t) =>
      _update((s) => s.reminderTime = DateTime(2000, 1, 1, t.hour, t.minute));
  Future<void> setBiometricLock(bool v) => _update((s) => s.biometricLockEnabled = v);

  Future<void> setThemeMode(ThemeMode m) => _update((s) => s.themeMode = switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });

  /// Called after "Delete all data": back to a fresh, un-onboarded state.
  Future<void> reset() async {
    _settings = AppSettings();
    notifyListeners();
  }
}
