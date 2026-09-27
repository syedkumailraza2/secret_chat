import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/isar_service.dart';
import '../models/daily_log.dart';
import '../utils/date_utils.dart';

/// Daily check-ins, keyed by `dayKey(date)`, plus the calendar's selected day.
class LogProvider extends ChangeNotifier {
  LogProvider(this._db) {
    _sub = _db.watchDailyLogs().listen((_) => load());
  }

  final IsarService _db;
  late final StreamSubscription<void> _sub;

  Map<DateTime, DailyLog> _logs = {};
  DateTime _selectedDate = today();
  DateTime _today = today();

  List<DailyLog> get allLogs => _logs.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  DateTime get selectedDate => _selectedDate;
  DailyLog? get selectedLog => _logs[_selectedDate];
  DailyLog? get todayLog => _logs[today()];

  DailyLog? logFor(DateTime date) => _logs[dayKey(date)];
  bool hasLog(DateTime date) => _logs.containsKey(dayKey(date));

  Future<void> load() async {
    final all = await _db.getAllDailyLogs();
    _logs = {for (final l in all) dayKey(l.date): l};
    notifyListeners();
  }

  /// Called when the calendar day may have changed (midnight, app resume,
  /// clock change). Keeps "today" selected if it was, and redraws listeners.
  void rollDay() {
    final now = today();
    if (now == _today) return;
    if (_selectedDate == _today) _selectedDate = now;
    _today = now;
    notifyListeners();
  }

  void selectDate(DateTime date) {
    _selectedDate = dayKey(date);
    notifyListeners();
  }

  /// Upserts the check-in for [date]. An entirely empty log deletes the row.
  Future<void> saveLog({
    required DateTime date,
    String? flow,
    List<String> symptoms = const [],
    String? mood,
    String? note,
  }) async {
    final log = DailyLog()
      ..date = dayKey(date)
      ..flow = flow
      ..symptoms = [...symptoms]
      ..mood = mood
      ..note = (note == null || note.trim().isEmpty) ? null : note.trim()
      ..loggedAt = DateTime.now();
    if (log.isEmpty) {
      await deleteLog(date);
      return;
    }
    final existing = _logs[log.date];
    if (existing != null) log.id = existing.id;
    _logs[log.date] = log; // optimistic
    notifyListeners();
    await _db.saveDailyLog(log);
  }

  Future<void> deleteLog(DateTime date) async {
    _logs.remove(dayKey(date));
    notifyListeners();
    await _db.deleteDailyLog(date);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
