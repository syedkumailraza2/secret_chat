import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:luna/database/isar_service.dart';
import 'package:luna/models/app_settings.dart';
import 'package:luna/models/daily_log.dart';
import 'package:luna/models/period.dart';

void main() {
  late Directory dir;
  late Isar isar;
  late IsarService db;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luna_isar_test');
    isar = await Isar.open(
      IsarService.schemas,
      directory: dir.path,
      name: 'test_${DateTime.now().microsecondsSinceEpoch}',
      inspector: false,
    );
    db = IsarService.forTesting(isar);
  });

  tearDown(() async {
    if (isar.isOpen) await isar.close(deleteFromDisk: true);
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  group('periods', () {
    test('save normalizes dates and returns oldest first', () async {
      await db.savePeriod(Period()
        ..startDate = DateTime(2026, 9, 1, 15, 30)
        ..endDate = DateTime(2026, 9, 5, 23)
        ..flow = 'heavy');
      await db.savePeriod(Period()
        ..startDate = DateTime(2026, 8, 3, 8)
        ..flow = 'light');

      final all = await db.getPeriods();
      expect(all.length, 2);
      expect(all.first.startDate, DateTime.utc(2026, 8, 3));
      expect(all.first.endDate, isNull);
      expect(all.last.startDate, DateTime.utc(2026, 9, 1));
      expect(all.last.endDate, DateTime.utc(2026, 9, 5));
      expect(all.last.flow, 'heavy');
    });

    test('update and delete', () async {
      final id = await db.savePeriod(Period()
        ..startDate = DateTime(2026, 9, 1)
        ..flow = 'medium');
      final p = (await db.getPeriods()).single;
      expect(p.id, id);

      p.endDate = DateTime(2026, 9, 4);
      await db.updatePeriod(p);
      final updated = (await db.getPeriods()).single;
      expect(updated.id, id);
      expect(updated.endDate, DateTime.utc(2026, 9, 4));

      expect(await db.deletePeriod(id), isTrue);
      expect(await db.getPeriods(), isEmpty);
      expect(await db.deletePeriod(id), isFalse);
    });

    test('watchPeriods fires on change', () async {
      final fired = db.watchPeriods().first;
      await db.savePeriod(Period()
        ..startDate = DateTime(2026, 9, 1)
        ..flow = 'medium');
      await expectLater(fired.timeout(const Duration(seconds: 2)), completes);
    });
  });

  group('daily logs', () {
    test('one log per day: saving the same day replaces it', () async {
      await db.saveDailyLog(DailyLog()
        ..date = DateTime(2026, 9, 23, 8)
        ..flow = 'light'
        ..symptoms = ['cramps']
        ..mood = 'low');
      await db.saveDailyLog(DailyLog()
        ..date = DateTime(2026, 9, 23, 21, 45)
        ..flow = 'medium'
        ..symptoms = ['headache', 'bloating']
        ..note = 'evening');

      final all = await db.getAllDailyLogs();
      expect(all.length, 1);
      final log = all.single;
      expect(log.date, DateTime.utc(2026, 9, 23));
      expect(log.flow, 'medium');
      expect(log.symptoms, ['headache', 'bloating']);
      expect(log.mood, isNull);
      expect(log.note, 'evening');
    });

    test('get by date, sorted list, delete', () async {
      for (final d in [25, 21, 23]) {
        await db.saveDailyLog(DailyLog()
          ..date = DateTime(2026, 9, d)
          ..mood = 'good');
      }
      final all = await db.getAllDailyLogs();
      expect(all.map((l) => l.date.day), [21, 23, 25]);

      final found = await db.getDailyLogForDate(DateTime(2026, 9, 23, 17));
      expect(found, isNotNull);
      expect(found!.date, DateTime.utc(2026, 9, 23));
      expect(await db.getDailyLogForDate(DateTime(2026, 9, 22)), isNull);

      expect(await db.deleteDailyLog(DateTime(2026, 9, 23, 9)), isTrue);
      expect(await db.getDailyLogForDate(DateTime(2026, 9, 23)), isNull);
      expect((await db.getAllDailyLogs()).length, 2);
    });

    test('editing a fetched log keeps a single row', () async {
      await db.saveDailyLog(DailyLog()..date = DateTime(2026, 9, 23));
      final log = (await db.getDailyLogForDate(DateTime(2026, 9, 23)))!;
      log.symptoms = [...log.symptoms, 'fatigue'];
      await db.saveDailyLog(log);
      final all = await db.getAllDailyLogs();
      expect(all.length, 1);
      expect(all.single.symptoms, ['fatigue']);
    });
  });

  group('settings', () {
    test('defaults when nothing saved', () async {
      final s = await db.getSettings();
      expect(s.id, 0);
      expect(s.defaultCycleLength, 28);
      expect(s.defaultPeriodLength, 5);
      expect(s.onboardingComplete, isFalse);
      expect(s.biometricLockEnabled, isFalse);
      expect(s.themeMode, 'system');
      expect(await isar.appSettings.count(), 0);
    });

    test('save round-trips and stays a singleton', () async {
      await db.saveSettings(AppSettings()
        ..id = 42
        ..defaultCycleLength = 31
        ..onboardingComplete = true
        ..reminderTime = DateTime(2000, 1, 1, 21, 15)
        ..themeMode = 'dark');
      await db.saveSettings((await db.getSettings())..biometricLockEnabled = true);

      expect(await isar.appSettings.count(), 1);
      final s = await db.getSettings();
      expect(s.id, 0);
      expect(s.defaultCycleLength, 31);
      expect(s.onboardingComplete, isTrue);
      expect(s.biometricLockEnabled, isTrue);
      expect(s.reminderTime!.hour, 21);
      expect(s.reminderTime!.minute, 15);
      expect(s.themeMode, 'dark');
    });
  });

  test('clearAll wipes every collection', () async {
    await db.savePeriod(Period()
      ..startDate = DateTime(2026, 9, 1)
      ..flow = 'medium');
    await db.saveDailyLog(DailyLog()..date = DateTime(2026, 9, 1));
    await db.saveSettings(AppSettings()..onboardingComplete = true);

    await db.clearAll();

    expect(await db.getPeriods(), isEmpty);
    expect(await db.getAllDailyLogs(), isEmpty);
    expect(await isar.appSettings.count(), 0);
    expect((await db.getSettings()).onboardingComplete, isFalse);
  });
}
