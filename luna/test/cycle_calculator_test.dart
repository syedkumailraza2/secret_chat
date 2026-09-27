import 'package:flutter_test/flutter_test.dart';
import 'package:luna/models/period.dart';
import 'package:luna/services/cycle_calculator.dart';
import 'package:luna/utils/date_utils.dart';

Period p(DateTime start, [DateTime? end, String flow = 'medium']) => Period()
  ..startDate = dayKey(start)
  ..endDate = end == null ? null : dayKey(end)
  ..flow = flow;

/// Periods starting at [first] then separated by [gaps]; each lasts [len] days.
List<Period> history(DateTime first, List<int> gaps, {int len = 5}) {
  final out = <Period>[];
  var s = dayKey(first);
  out.add(p(s, addDays(s, len - 1)));
  for (final g in gaps) {
    s = addDays(s, g);
    out.add(p(s, addDays(s, len - 1)));
  }
  return out;
}

void main() {
  group('phaseRanges', () {
    test('matches the Today timeline design for a 29-day cycle', () {
      final r = CycleCalculator.phaseRanges(29, 5);
      expect(r.map((e) => [e.phase, e.startDay, e.endDay]).toList(), [
        [CyclePhase.menstrual, 1, 5],
        [CyclePhase.follicular, 6, 14],
        [CyclePhase.ovulation, 15, 17],
        [CyclePhase.luteal, 18, 29],
      ]);
    });

    for (var len = 21; len <= 40; len++) {
      for (final pLen in [3, 5, 7]) {
        test('contiguous and covering 1..$len (period $pLen)', () {
          final r = CycleCalculator.phaseRanges(len, pLen);
          expect(r.first.startDay, 1);
          expect(r.last.endDay, len);
          for (var i = 1; i < r.length; i++) {
            expect(r[i].startDay, r[i - 1].endDay + 1, reason: 'gap/overlap at $i');
          }
          for (final x in r) {
            expect(x.length, greaterThan(0));
          }
          expect(r.fold<int>(0, (a, x) => a + x.length), len);

          // Phase order is always menstrual → (follicular) → ovulation → luteal.
          expect(r.first.phase, CyclePhase.menstrual);
          expect(r.first.endDay, pLen);
          final ov = r.firstWhere((x) => x.phase == CyclePhase.ovulation);
          expect(ov.startDay, greaterThan(pLen));
          expect(ov.length, 3);
          if (len - 14 > pLen) {
            // Ovulation ~14 days before the next period.
            expect(ov.startDay, len - 14);
          }
          expect(r.last.phase, CyclePhase.luteal);

          // phaseForDay agrees with the ranges for every day.
          for (var d = 1; d <= len; d++) {
            final expected = r.firstWhere((x) => x.contains(d)).phase;
            expect(CycleCalculator.phaseForDay(d, len, pLen), expected);
          }
        });
      }
    }

    test('degenerate inputs still produce contiguous ranges', () {
      for (final (len, pLen) in [(1, 1), (5, 10), (15, 7), (21, 21), (10, 0)]) {
        final r = CycleCalculator.phaseRanges(len, pLen);
        expect(r.first.startDay, 1);
        expect(r.last.endDay, len);
        for (var i = 1; i < r.length; i++) {
          expect(r[i].startDay, r[i - 1].endDay + 1);
        }
      }
    });

    test('days past the expected length stay luteal (late period)', () {
      expect(CycleCalculator.phaseForDay(35, 28, 5), CyclePhase.luteal);
      expect(CycleCalculator.phaseForDay(0, 28, 5), CyclePhase.menstrual);
    });
  });

  group('cycleDay / predictNextPeriod', () {
    test('cycle day is 1 on the start day', () {
      final s = DateTime(2026, 9, 1);
      expect(CycleCalculator.cycleDay(s, s), 1);
      expect(CycleCalculator.cycleDay(s, DateTime(2026, 9, 23)), 23);
      // Time of day is irrelevant.
      expect(CycleCalculator.cycleDay(DateTime(2026, 9, 1, 23, 59), DateTime(2026, 9, 2, 0, 1)), 2);
    });

    test('next period = start + cycle length (across month/year)', () {
      expect(CycleCalculator.predictNextPeriod(DateTime(2026, 9, 1), 28), DateTime.utc(2026, 9, 29));
      expect(CycleCalculator.predictNextPeriod(DateTime(2026, 12, 20), 30), DateTime.utc(2027, 1, 19));
      expect(CycleCalculator.predictNextPeriod(DateTime(2028, 2, 1), 29), DateTime.utc(2028, 3, 1));
    });
  });

  group('snapshot', () {
    test('null with no history', () {
      expect(
        CycleCalculator.snapshot(periods: [], defaultCycleLength: 28, defaultPeriodLength: 5),
        isNull,
      );
    });

    test('null when all periods are in the future', () {
      final now = DateTime(2026, 9, 23);
      expect(
        CycleCalculator.snapshot(
          periods: [p(DateTime(2026, 10, 1))],
          defaultCycleLength: 28,
          defaultPeriodLength: 5,
          now: now,
        ),
        isNull,
      );
    });

    test('single period uses the defaults', () {
      final now = DateTime(2026, 9, 23, 14);
      final s = CycleCalculator.snapshot(
        periods: [p(DateTime(2026, 9, 10), DateTime(2026, 9, 14))],
        defaultCycleLength: 30,
        defaultPeriodLength: 6,
        now: now,
      )!;
      expect(s.cycleDay, 14);
      expect(s.cycleLength, 30);
      // Period length comes from the one finished period (5 days).
      expect(s.periodLength, 5);
      expect(s.nextPeriodStart, DateTime.utc(2026, 10, 10));
      expect(s.daysUntilNextPeriod, 17);
      expect(s.lastPeriodStart, DateTime.utc(2026, 9, 10));
      expect(s.phase, CycleCalculator.phaseForDay(14, 30, 5));
      expect(s.isLate, isFalse);
      expect(s.isIrregular, isFalse);
      expect(s.progress, inInclusiveRange(0.0, 1.0));
    });

    test('uses the average of recent cycles', () {
      final periods = history(DateTime(2026, 1, 1), [27, 29, 28, 30]); // avg 28.5 → 29 (round)
      final last = periods.last.startDate;
      final s = CycleCalculator.snapshot(
        periods: periods,
        defaultCycleLength: 35,
        defaultPeriodLength: 5,
        now: addDays(last, 3),
      )!;
      expect(s.cycleLength, 29);
      expect(s.cycleDay, 4);
      expect(s.phase, CyclePhase.menstrual);
      expect(s.nextPeriodStart, addDays(last, 29));
    });

    test('late period has negative days-until and luteal phase', () {
      final s = CycleCalculator.snapshot(
        periods: [p(DateTime(2026, 8, 1), DateTime(2026, 8, 5))],
        defaultCycleLength: 28,
        defaultPeriodLength: 5,
        now: DateTime(2026, 9, 3),
      )!;
      expect(s.cycleDay, 34);
      expect(s.isLate, isTrue);
      expect(s.daysUntilNextPeriod, -5);
      expect(s.phase, CyclePhase.luteal);
      expect(s.progress, 1.0);
      expect(s.isIrregular, isFalse);
    });

    test('irregular beyond cycle day 45', () {
      final start = DateTime(2026, 7, 1);
      CycleSnapshot snapAt(int day) => CycleCalculator.snapshot(
            periods: [p(start, DateTime(2026, 7, 5))],
            defaultCycleLength: 28,
            defaultPeriodLength: 5,
            now: addDays(start, day - 1),
          )!;
      expect(snapAt(45).isIrregular, isFalse);
      expect(snapAt(46).isIrregular, isTrue);
    });

    test('ignores periods that start after "now"', () {
      final s = CycleCalculator.snapshot(
        periods: [p(DateTime(2026, 9, 1), DateTime(2026, 9, 5)), p(DateTime(2026, 9, 30))],
        defaultCycleLength: 28,
        defaultPeriodLength: 5,
        now: DateTime(2026, 9, 23),
      )!;
      expect(s.lastPeriodStart, DateTime.utc(2026, 9, 1));
    });

    test('unsorted input is handled', () {
      final periods = history(DateTime(2026, 1, 1), [28, 28, 28]).reversed.toList();
      final s = CycleCalculator.snapshot(
        periods: periods,
        defaultCycleLength: 30,
        defaultPeriodLength: 5,
        now: DateTime(2026, 3, 30),
      )!;
      expect(s.lastPeriodStart, DateTime.utc(2026, 3, 26));
      expect(s.cycleLength, 28);
    });
  });

  group('averages', () {
    test('cycleLengths drops implausible gaps (<15 or >90)', () {
      final periods = history(DateTime(2025, 1, 1), [28, 10, 30, 120, 29, 15, 90, 91]);
      expect(CycleCalculator.cycleLengths(periods), [28, 30, 29, 15, 90]);
    });

    test('periodLengths skips ongoing periods', () {
      final periods = [
        p(DateTime(2026, 1, 1), DateTime(2026, 1, 5)),
        p(DateTime(2026, 1, 29), DateTime(2026, 2, 3)),
        p(DateTime(2026, 2, 26)),
      ];
      expect(CycleCalculator.periodLengths(periods), [5, 6]);
      expect(CycleCalculator.averagePeriodLength(periods), 5.5);
    });

    test('average and lastN', () {
      final periods = history(DateTime(2025, 1, 1), [20, 30, 30, 30]);
      expect(CycleCalculator.averageCycleLength(periods), 27.5);
      expect(CycleCalculator.averageCycleLength(periods, lastN: 3), 30);
      expect(CycleCalculator.averageCycleLength(periods, lastN: 10), 27.5);
      expect(CycleCalculator.averageCycleLength([p(DateTime(2026, 1, 1))]), isNull);
    });

    test('variation σ (population) needs ≥2 cycles', () {
      expect(CycleCalculator.cycleVariation(history(DateTime(2026, 1, 1), [28])), isNull);
      expect(CycleCalculator.cycleVariation(history(DateTime(2026, 1, 1), [28, 28, 28])), 0);
      // 26, 30 → mean 28, σ 2
      expect(CycleCalculator.cycleVariation(history(DateTime(2026, 1, 1), [26, 30])), closeTo(2, 1e-9));
      // 25, 28, 31 → σ = sqrt(6)
      expect(CycleCalculator.cycleVariation(history(DateTime(2026, 1, 1), [25, 28, 31])),
          closeTo(2.449489743, 1e-6));
    });

    test('effective lengths fall back to defaults and use last 6', () {
      expect(CycleCalculator.effectiveCycleLength([], 31), 31);
      expect(CycleCalculator.effectivePeriodLength([p(DateTime(2026, 1, 1))], 4), 4);
      final periods = history(DateTime(2024, 1, 1), [40, 40, 28, 28, 28, 28, 28, 28]);
      expect(CycleCalculator.effectiveCycleLength(periods, 30), 28);
      expect(CycleCalculator.effectivePeriodLength(periods, 3), 5);
    });
  });

  group('periodOn', () {
    final now = DateTime(2026, 9, 23);

    test('finished period covers start..end inclusive', () {
      final periods = [p(DateTime(2026, 9, 1), DateTime(2026, 9, 5))];
      Period? on(DateTime d) => CycleCalculator.periodOn(periods, d, ongoingLength: 5, now: now);
      expect(on(DateTime(2026, 8, 31)), isNull);
      expect(on(DateTime(2026, 9, 1)), same(periods.first));
      expect(on(DateTime(2026, 9, 5, 23, 59)), same(periods.first));
      expect(on(DateTime(2026, 9, 6)), isNull);
    });

    test('ongoing period covers ongoingLength days', () {
      final periods = [p(DateTime(2026, 9, 21))];
      Period? on(DateTime d) => CycleCalculator.periodOn(periods, d, ongoingLength: 5, now: now);
      expect(on(DateTime(2026, 9, 21)), isNotNull);
      expect(on(DateTime(2026, 9, 25)), isNotNull);
      expect(on(DateTime(2026, 9, 26)), isNull);
    });

    test('ongoing period longer than expected extends to today', () {
      final periods = [p(DateTime(2026, 9, 10))];
      Period? on(DateTime d) => CycleCalculator.periodOn(periods, d, ongoingLength: 5, now: now);
      expect(on(DateTime(2026, 9, 20)), isNotNull);
      expect(on(DateTime(2026, 9, 23)), isNotNull);
      expect(on(DateTime(2026, 9, 24)), isNull);
    });
  });

  group('isPredictedPeriodDay', () {
    final snap = CycleCalculator.snapshot(
      periods: [p(DateTime(2026, 9, 1), DateTime(2026, 9, 5))],
      defaultCycleLength: 28,
      defaultPeriodLength: 5,
      now: DateTime(2026, 9, 10),
    );

    test('null snapshot → false', () {
      expect(CycleCalculator.isPredictedPeriodDay(null, DateTime(2026, 9, 29)), isFalse);
    });

    test('projects the next 3 cycles', () {
      bool pred(DateTime d) => CycleCalculator.isPredictedPeriodDay(snap, d);
      // Next: Sep 29 – Oct 3
      expect(pred(DateTime(2026, 9, 28)), isFalse);
      expect(pred(DateTime(2026, 9, 29)), isTrue);
      expect(pred(DateTime(2026, 10, 3, 22)), isTrue);
      expect(pred(DateTime(2026, 10, 4)), isFalse);
      // +28: Oct 27 – 31, +56: Nov 24 – 28
      expect(pred(DateTime(2026, 10, 27)), isTrue);
      expect(pred(DateTime(2026, 11, 28)), isTrue);
      // 4th cycle not projected by default.
      expect(pred(DateTime(2026, 12, 22)), isFalse);
      expect(CycleCalculator.isPredictedPeriodDay(snap, DateTime(2026, 12, 22), cycles: 4), isTrue);
    });
  });

  group('dayInfo', () {
    test('relative to the most recent period on/before the date', () {
      final periods = history(DateTime(2026, 1, 1), [28]);
      expect(
        CycleCalculator.dayInfo(periods, DateTime(2025, 12, 31), cycleLength: 28, periodLength: 5),
        isNull,
      );
      final a = CycleCalculator.dayInfo(periods, DateTime(2026, 1, 10), cycleLength: 28, periodLength: 5)!;
      expect(a.day, 10);
      expect(a.phase, CyclePhase.follicular);
      final b = CycleCalculator.dayInfo(periods, DateTime(2026, 1, 29), cycleLength: 28, periodLength: 5)!;
      expect(b.day, 1);
      expect(b.phase, CyclePhase.menstrual);
    });
  });

  group('dayKey math is DST / timezone robust', () {
    test('dayKey is UTC midnight of the local calendar day', () {
      final k = dayKey(DateTime(2026, 3, 8, 23, 59));
      expect(k.isUtc, isTrue);
      expect([k.year, k.month, k.day, k.hour, k.minute], [2026, 3, 8, 0, 0]);
      // An already-normalized key is stable.
      expect(dayKey(k), k);
    });

    // US DST starts 2026-03-08, ends 2026-11-01; EU: 2026-03-29 / 2026-10-25.
    // Whatever the host timezone, local wall-clock dates must count whole days.
    for (final (a, b, expected) in [
      (DateTime(2026, 3, 7, 23), DateTime(2026, 3, 9, 1), 2),
      (DateTime(2026, 3, 28, 12), DateTime(2026, 3, 30, 0), 2),
      (DateTime(2026, 10, 24, 0, 30), DateTime(2026, 10, 26, 23, 30), 2),
      (DateTime(2026, 10, 31, 23, 59), DateTime(2026, 11, 2), 2),
      (DateTime(2026, 1, 1), DateTime(2027, 1, 1), 365),
      (DateTime(2028, 1, 1), DateTime(2029, 1, 1), 366),
    ]) {
      test('daysBetween($a, $b) == $expected', () {
        expect(daysBetween(a, b), expected);
        expect(daysBetween(b, a), -expected);
      });
    }

    test('addDays walks calendar days across DST changes', () {
      var d = dayKey(DateTime(2026, 3, 1));
      for (var i = 0; i < 400; i++) {
        final next = addDays(d, 1);
        expect(next.difference(d).inHours, 24);
        expect(next.hour, 0);
        d = next;
      }
      expect(addDays(DateTime(2026, 3, 7, 22), 2), DateTime.utc(2026, 3, 9));
      expect(addDays(DateTime(2026, 11, 1, 1, 30), -1), DateTime.utc(2026, 10, 31));
    });

    test('a 28-day cycle spanning a DST change predicts the same weekday', () {
      final start = DateTime(2026, 2, 20); // Friday; DST switches inside this cycle
      final next = CycleCalculator.predictNextPeriod(start, 28);
      expect(next, DateTime.utc(2026, 3, 20));
      expect(next.weekday, start.weekday);
      expect(CycleCalculator.cycleDay(start, DateTime(2026, 3, 19, 23, 30)), 28);
    });

    test('local and UTC representations of the same calendar day agree', () {
      final local = DateTime(2026, 9, 23, 0, 5);
      expect(dayKey(local), DateTime.utc(2026, 9, 23));
      expect(daysBetween(local, DateTime.utc(2026, 9, 23)), 0);
    });
  });
}
