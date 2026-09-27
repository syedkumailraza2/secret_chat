import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/isar_service.dart';
import '../models/period.dart';
import '../services/cycle_calculator.dart';
import '../utils/date_utils.dart';

/// Period history plus everything derived from it.
/// Baseline lengths come from [SettingsProvider] via `ChangeNotifierProxyProvider`.
class CycleProvider extends ChangeNotifier {
  CycleProvider(this._db) {
    _sub = _db.watchPeriods().listen((_) => load());
  }

  final IsarService _db;
  late final StreamSubscription<void> _sub;

  List<Period> _periods = [];
  int _defaultCycleLength = 28;
  int _defaultPeriodLength = 5;
  CycleSnapshot? _snapshot;

  /// Oldest first.
  List<Period> get periods => List.unmodifiable(_periods);
  bool get hasHistory => _periods.isNotEmpty;
  CycleSnapshot? get snapshot => _snapshot;

  int get cycleLength => _snapshot?.cycleLength ??
      CycleCalculator.effectiveCycleLength(_periods, _defaultCycleLength);
  int get periodLength => _snapshot?.periodLength ??
      CycleCalculator.effectivePeriodLength(_periods, _defaultPeriodLength);

  Period? get ongoingPeriod {
    for (final p in _periods.reversed) {
      if (p.endDate == null) return p;
    }
    return null;
  }

  void updateDefaults(int cycleLength, int periodLength) {
    if (cycleLength == _defaultCycleLength && periodLength == _defaultPeriodLength) return;
    _defaultCycleLength = cycleLength;
    _defaultPeriodLength = periodLength;
    _recompute();
  }

  Future<void> load() async {
    _periods = await _db.getPeriods();
    _recompute();
  }

  /// Re-evaluate "today" (e.g. on app resume after midnight or a clock change).
  void refresh() => _recompute();

  void _recompute() {
    _snapshot = CycleCalculator.snapshot(
      periods: _periods,
      defaultCycleLength: _defaultCycleLength,
      defaultPeriodLength: _defaultPeriodLength,
    );
    notifyListeners();
  }

  // ---- Queries ----------------------------------------------------------

  Period? periodOn(DateTime date) =>
      CycleCalculator.periodOn(_periods, date, ongoingLength: periodLength);

  bool isPeriodDay(DateTime date) => periodOn(date) != null;

  bool isPredictedPeriodDay(DateTime date) =>
      !isPeriodDay(date) && CycleCalculator.isPredictedPeriodDay(_snapshot, date);

  ({int day, CyclePhase phase})? dayInfo(DateTime date) => CycleCalculator.dayInfo(
        _periods,
        date,
        cycleLength: cycleLength,
        periodLength: periodLength,
      );

  // ---- Mutations --------------------------------------------------------

  /// Starts a period on [date]. If [date] already falls inside a period this
  /// is a no-op. An earlier ongoing period is closed the day before.
  Future<void> startPeriod(DateTime date, {String flow = 'medium'}) async {
    await _startPeriod(date, flow);
    await load();
  }

  Future<void> _startPeriod(DateTime date, String flow) async {
    final d = dayKey(date);
    final covering = periodOn(d);
    if (covering != null) return;

    // Merge with a period that starts just after (user back-filling a day).
    for (final p in _periods) {
      if (daysBetween(d, p.startDate) == 1) {
        p.startDate = d;
        await _db.updatePeriod(p);
        return;
      }
    }
    for (final p in _periods) {
      if (p.endDate == null && p.startDate.isBefore(d)) {
        p.endDate = addDays(d, -1);
        await _db.updatePeriod(p);
      }
    }
    await _db.savePeriod(Period()
      ..startDate = d
      ..flow = flow);
  }

  /// Ends the period covering (or most recently before) [date].
  Future<void> endPeriod(DateTime date) async {
    final d = dayKey(date);
    Period? target = periodOn(d);
    if (target == null) {
      for (final p in _periods) {
        if (!p.startDate.isAfter(d)) target = p;
      }
    }
    if (target == null) return;
    target.endDate = d;
    await _db.updatePeriod(target);
    await load();
  }

  // Mutations reload immediately so chained calls (start → end) see fresh
  // state without waiting on the watch stream.
  Future<void> savePeriod(Period p) async {
    await _db.savePeriod(p);
    await load();
  }

  Future<void> deletePeriod(int id) async {
    await _db.deletePeriod(id);
    await load();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
