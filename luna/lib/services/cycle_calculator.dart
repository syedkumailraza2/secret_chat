import 'dart:math' as math;

import '../models/period.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';

enum CyclePhase {
  menstrual('Period', 'Menstrual'),
  follicular('Follicular', 'Follicular'),
  ovulation('Ovulation', 'Ovulation'),
  luteal('Luteal', 'Luteal');

  const CyclePhase(this.shortLabel, this.label);

  /// Label used on the Today timeline ("PERIOD", "FOLLICULAR", ...).
  final String shortLabel;
  final String label;
}

class PhaseRange {
  const PhaseRange(this.phase, this.startDay, this.endDay);
  final CyclePhase phase;
  final int startDay; // 1-based, inclusive
  final int endDay; // inclusive
  int get length => endDay - startDay + 1;
  bool contains(int day) => day >= startDay && day <= endDay;
}

/// Everything the Today screen needs about "now".
class CycleSnapshot {
  const CycleSnapshot({
    required this.cycleDay,
    required this.cycleLength,
    required this.periodLength,
    required this.phase,
    required this.phases,
    required this.lastPeriodStart,
    required this.nextPeriodStart,
    required this.daysUntilNextPeriod,
  });

  final int cycleDay;
  final int cycleLength;
  final int periodLength;
  final CyclePhase phase;
  final List<PhaseRange> phases;
  final DateTime lastPeriodStart;
  final DateTime nextPeriodStart;

  /// Negative when the period is late.
  final int daysUntilNextPeriod;

  bool get isLate => daysUntilNextPeriod < 0;
  bool get isIrregular => cycleDay > irregularCycleDay;

  /// 0..1 position of today on the cycle timeline (clamped).
  double get progress =>
      ((cycleDay - 0.5) / cycleLength).clamp(0.0, 1.0).toDouble();
}

/// Pure, UI-free cycle math. All dates are normalized with [dayKey].
class CycleCalculator {
  CycleCalculator._();

  /// Cycle Day = (today - last period start) + 1
  static int cycleDay(DateTime lastPeriodStart, DateTime today) =>
      daysBetween(lastPeriodStart, today) + 1;

  /// Predicted = last period start + average cycle length
  static DateTime predictNextPeriod(DateTime lastPeriodStart, int cycleLength) =>
      addDays(lastPeriodStart, cycleLength);

  /// Ovulation is estimated 14 days before the next period; the window spans
  /// that day and the two after it (matches the Today timeline design:
  /// 29-day cycle → Period 1–5, Follicular 6–14, Ovulation 15–17, Luteal 18–29).
  static List<PhaseRange> phaseRanges(int cycleLength, int periodLength) {
    final len = math.max(cycleLength, 1);
    final pLen = periodLength.clamp(1, len);
    var ovStart = len - 14;
    // Short cycles: keep ovulation after the period ends.
    if (ovStart <= pLen) ovStart = math.min(pLen + 1, len);
    final ovEnd = math.min(ovStart + 2, len);

    return [
      PhaseRange(CyclePhase.menstrual, 1, pLen),
      if (ovStart - 1 >= pLen + 1)
        PhaseRange(CyclePhase.follicular, pLen + 1, ovStart - 1),
      if (ovStart > pLen) PhaseRange(CyclePhase.ovulation, ovStart, ovEnd),
      if (len >= ovEnd + 1) PhaseRange(CyclePhase.luteal, ovEnd + 1, len),
    ];
  }

  static CyclePhase phaseForDay(int day, int cycleLength, int periodLength) {
    final ranges = phaseRanges(cycleLength, periodLength);
    for (final r in ranges) {
      if (r.contains(day)) return r.phase;
    }
    // Beyond the expected length (late period) we remain in the luteal phase.
    return day < 1 ? CyclePhase.menstrual : CyclePhase.luteal;
  }

  static List<Period> _sorted(List<Period> periods) =>
      [...periods]..sort((a, b) => a.startDate.compareTo(b.startDate));

  /// Gaps (in days) between consecutive period starts, oldest first.
  /// Implausible gaps (< 15 or > 90 days, e.g. missed logging) are dropped.
  static List<int> cycleLengths(List<Period> periods) {
    final s = _sorted(periods);
    final out = <int>[];
    for (var i = 1; i < s.length; i++) {
      final gap = daysBetween(s[i - 1].startDate, s[i].startDate);
      if (gap >= 15 && gap <= 90) out.add(gap);
    }
    return out;
  }

  /// Length in days of each *finished* period, oldest first.
  static List<int> periodLengths(List<Period> periods) => [
        for (final p in _sorted(periods))
          if (p.endDate != null) daysBetween(p.startDate, p.endDate!) + 1,
      ];

  static double? _mean(List<int> xs) =>
      xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;

  static List<int> _lastN(List<int> xs, int? n) =>
      n == null || xs.length <= n ? xs : xs.sublist(xs.length - n);

  /// Average cycle length over the last [lastN] cycles (all when null).
  static double? averageCycleLength(List<Period> periods, {int? lastN}) =>
      _mean(_lastN(cycleLengths(periods), lastN));

  static double? averagePeriodLength(List<Period> periods, {int? lastN}) =>
      _mean(_lastN(periodLengths(periods), lastN));

  /// Population standard deviation of cycle lengths (regularity σ in days).
  static double? cycleVariation(List<Period> periods, {int? lastN}) {
    final xs = _lastN(cycleLengths(periods), lastN);
    if (xs.length < 2) return null;
    final m = _mean(xs)!;
    final v = xs.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / xs.length;
    return math.sqrt(v);
  }

  /// Cycle length to predict with: the recent average when history exists,
  /// otherwise the user's baseline from onboarding/settings.
  static int effectiveCycleLength(List<Period> periods, int fallback) {
    final avg = averageCycleLength(periods, lastN: 6);
    return avg == null ? fallback : avg.round();
  }

  static int effectivePeriodLength(List<Period> periods, int fallback) {
    final avg = averagePeriodLength(periods, lastN: 6);
    return avg == null ? fallback : avg.round();
  }

  /// Returns null when there is no period history yet.
  static CycleSnapshot? snapshot({
    required List<Period> periods,
    required int defaultCycleLength,
    required int defaultPeriodLength,
    DateTime? now,
  }) {
    final t = dayKey(now ?? DateTime.now());
    final past = _sorted(periods).where((p) => !p.startDate.isAfter(t)).toList();
    if (past.isEmpty) return null;

    final last = past.last;
    final cycleLength = effectiveCycleLength(past, defaultCycleLength);
    final periodLength = effectivePeriodLength(past, defaultPeriodLength);
    final day = cycleDay(last.startDate, t);
    final next = predictNextPeriod(last.startDate, cycleLength);

    return CycleSnapshot(
      cycleDay: day,
      cycleLength: cycleLength,
      periodLength: periodLength,
      phase: phaseForDay(day, cycleLength, periodLength),
      phases: phaseRanges(cycleLength, periodLength),
      lastPeriodStart: last.startDate,
      nextPeriodStart: next,
      daysUntilNextPeriod: daysBetween(t, next),
    );
  }

  /// The period (if any) covering [date]. An ongoing period (no end date)
  /// is assumed to cover [ongoingLength] days, or up to today if longer.
  static Period? periodOn(
    List<Period> periods,
    DateTime date, {
    required int ongoingLength,
    DateTime? now,
  }) {
    final d = dayKey(date);
    final t = dayKey(now ?? DateTime.now());
    for (final p in periods) {
      final end = p.endDate ??
          _later(addDays(p.startDate, ongoingLength - 1), t);
      if (!d.isBefore(p.startDate) && !d.isAfter(end)) return p;
    }
    return null;
  }

  /// True when [date] falls inside a *predicted* future period.
  /// Projects [cycles] cycles ahead of the snapshot.
  static bool isPredictedPeriodDay(
    CycleSnapshot? snap,
    DateTime date, {
    int cycles = 3,
  }) {
    if (snap == null) return false;
    final d = dayKey(date);
    for (var i = 0; i < cycles; i++) {
      final start = addDays(snap.nextPeriodStart, i * snap.cycleLength);
      final end = addDays(start, snap.periodLength - 1);
      if (!d.isBefore(start) && !d.isAfter(end)) return true;
    }
    return false;
  }

  /// Cycle day and phase for any date, relative to the most recent period
  /// start on/before it. Null if no period precedes [date].
  static ({int day, CyclePhase phase})? dayInfo(
    List<Period> periods,
    DateTime date, {
    required int cycleLength,
    required int periodLength,
  }) {
    final d = dayKey(date);
    Period? anchor;
    for (final p in _sorted(periods)) {
      if (!p.startDate.isAfter(d)) anchor = p;
    }
    if (anchor == null) return null;
    final day = cycleDay(anchor.startDate, d);
    return (day: day, phase: phaseForDay(day, cycleLength, periodLength));
  }

  static DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
}
