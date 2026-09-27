import 'package:isar_community/isar.dart';

part 'app_settings.g.dart';

/// Singleton settings row (always id 0).
@collection
class AppSettings {
  Id id = 0;

  int defaultCycleLength = 28;
  int defaultPeriodLength = 5;

  bool onboardingComplete = false;

  /// Settings shows two independent reminders, so the plan's single
  /// `reminderEnabled` flag is split in two.
  bool periodReminderEnabled = false;
  bool dailyReminderEnabled = false;

  /// Only the hour/minute are used. Defaults to 8:00 PM when null.
  DateTime? reminderTime;

  bool biometricLockEnabled = false;
  String themeMode = 'system'; // 'system' | 'light' | 'dark'
}
