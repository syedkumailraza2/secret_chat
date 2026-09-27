import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/daily_log.dart';
import '../models/period.dart';
import '../utils/date_utils.dart';

/// Single access point to the on-device database.
class IsarService {
  IsarService._(this.isar);

  static IsarService? _instance;
  static IsarService get instance {
    final i = _instance;
    if (i == null) throw StateError('IsarService.init() has not been called');
    return i;
  }

  final Isar isar;

  static final schemas = [PeriodSchema, DailyLogSchema, AppSettingsSchema];

  static Future<IsarService> init({String? directory, String name = 'luna'}) async {
    if (_instance != null) return _instance!;
    final dir = directory ?? (await getApplicationDocumentsDirectory()).path;
    final isar = await Isar.open(schemas, directory: dir, name: name);
    return _instance = IsarService._(isar);
  }

  /// Test hook: wrap an already-open Isar instance.
  static IsarService forTesting(Isar isar) => _instance = IsarService._(isar);

  // ---- Periods ----------------------------------------------------------

  Future<int> savePeriod(Period p) {
    p.startDate = dayKey(p.startDate);
    if (p.endDate != null) p.endDate = dayKey(p.endDate!);
    return isar.writeTxn(() => isar.periods.put(p));
  }

  Future<int> updatePeriod(Period p) => savePeriod(p);

  // Isar stores instants and hands DateTimes back in *local* time, so a
  // stored dayKey (UTC midnight) would read as the previous evening west of
  // UTC. Convert back to UTC so y/m/d match the key that was written.
  static Period _fixPeriod(Period p) {
    p.startDate = p.startDate.toUtc();
    p.endDate = p.endDate?.toUtc();
    return p;
  }

  static DailyLog _fixLog(DailyLog l) => l..date = l.date.toUtc();

  /// All periods, oldest first.
  Future<List<Period>> getPeriods() async =>
      (await isar.periods.where().sortByStartDate().findAll()).map(_fixPeriod).toList();

  Future<bool> deletePeriod(int id) =>
      isar.writeTxn(() => isar.periods.delete(id));

  Stream<void> watchPeriods() => isar.periods.watchLazy(fireImmediately: false);

  // ---- Daily logs -------------------------------------------------------

  Future<int> saveDailyLog(DailyLog log) {
    log.date = dayKey(log.date);
    return isar.writeTxn(() => isar.dailyLogs.put(log));
  }

  Future<DailyLog?> getDailyLogForDate(DateTime date) async {
    final l = await isar.dailyLogs.where().dateEqualTo(dayKey(date)).findFirst();
    return l == null ? null : _fixLog(l);
  }

  Future<List<DailyLog>> getAllDailyLogs() async =>
      (await isar.dailyLogs.where().sortByDate().findAll()).map(_fixLog).toList();

  Future<bool> deleteDailyLog(DateTime date) => isar.writeTxn(
      () => isar.dailyLogs.where().dateEqualTo(dayKey(date)).deleteFirst());

  Stream<void> watchDailyLogs() =>
      isar.dailyLogs.watchLazy(fireImmediately: false);

  // ---- Settings ---------------------------------------------------------

  Future<AppSettings> getSettings() async =>
      await isar.appSettings.get(0) ?? AppSettings();

  Future<void> saveSettings(AppSettings s) {
    s.id = 0;
    return isar.writeTxn(() => isar.appSettings.put(s));
  }

  // ---- Danger zone ------------------------------------------------------

  /// Hard reset: wipes every collection.
  Future<void> clearAll() => isar.writeTxn(() => isar.clear());
}
