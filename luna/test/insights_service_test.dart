import 'package:flutter_test/flutter_test.dart';
import 'package:luna/models/daily_log.dart';
import 'package:luna/models/period.dart';
import 'package:luna/services/cycle_calculator.dart';
import 'package:luna/services/insights_service.dart';
import 'package:luna/utils/date_utils.dart';

Period _period(DateTime start, int length) => Period()
  ..startDate = dayKey(start)
  ..endDate = addDays(start, length - 1)
  ..flow = 'medium';

/// Periods starting on 2026-01-01 separated by [gaps] days.
List<Period> _history(List<int> gaps, {int periodLength = 5}) {
  var d = DateTime.utc(2026, 1, 1);
  final out = [_period(d, periodLength)];
  for (final g in gaps) {
    d = addDays(d, g);
    out.add(_period(d, periodLength));
  }
  return out;
}

DailyLog _log(DateTime date, {List<String> symptoms = const [], String? mood}) => DailyLog()
  ..date = dayKey(date)
  ..symptoms = [...symptoms]
  ..mood = mood;

Insights _compute(List<Period> periods, [List<DailyLog> logs = const [], int window = 6]) =>
    InsightsService.compute(
      periods: periods,
      logs: logs,
      baselineCycleLength: 28,
      baselinePeriodLength: 5,
      window: window,
    );

void main() {
  test('falls back to baseline and an honest message without history', () {
    final i = _compute([]);
    expect(i.trackedCycles, 0);
    expect(i.averageCycle, 28);
    expect(i.averagePeriod, 5);
    expect(i.cycleFromHistory, isFalse);
    expect(i.shortest, isNull);
    expect(i.bars, isEmpty);
    expect(i.consistency, InsightsService.emptyMessage);
    expect(i.symptoms, isEmpty);
    expect(i.mood, isNull);
  });

  test('averages, extremes and bars over the selected window', () {
    final periods = _history([28, 30, 29, 31, 29, 28, 35], periodLength: 6);
    final i = _compute(periods, const [], 6);
    expect(i.trackedCycles, 7);
    expect(i.bars.map((b) => b.length), [30, 29, 31, 29, 28, 35]);
    expect(i.bars.last.label, 'Recent');
    expect(i.bars.first.label, 'Cycle 1');
    expect(i.bars.first.periodLength, 6);
    expect(i.shortest, 28);
    expect(i.longest, 35);
    expect(i.averageCycle, 30); // 182 / 6 = 30.33
    expect(i.averagePeriod, 6);
    expect(i.averages[3], closeTo((29 + 28 + 35) / 3, 1e-9));
    expect(i.averages[12], closeTo(210 / 7, 1e-9));

    final three = _compute(periods, const [], 3);
    expect(three.bars.length, 3);
    expect(three.shortest, 28);
  });

  test('consistency wording follows the standard deviation', () {
    expect(_compute(_history([28, 31, 29, 30])).consistency,
        'Your recent cycles have ranged from 28–31 days, showing consistent rhythm.');
    expect(_compute(_history([26, 32, 27, 33])).consistency, contains('fairly regular'));
    expect(_compute(_history([22, 38, 25, 40])).consistency, contains('more variable'));
    expect(_compute(_history([28])).consistency, startsWith('Your one tracked cycle lasted 28 days'));
  });

  test('symptoms are mapped to the phase and cycle days they cluster on', () {
    final periods = _history([28, 28, 28]);
    final logs = <DailyLog>[
      for (final p in periods) ...[
        _log(p.startDate, symptoms: ['cramps'], mood: 'good'),
        _log(addDays(p.startDate, 1), symptoms: ['cramps', 'fatigue'], mood: 'good'),
        _log(addDays(p.startDate, 25), symptoms: ['fatigue', 'bloating'], mood: 'low'),
        _log(addDays(p.startDate, 26), symptoms: ['fatigue'], mood: 'good'),
      ],
    ];
    final i = _compute(periods, logs);
    expect(i.symptoms.map((s) => s.id), ['fatigue', 'cramps']);

    final cramps = i.symptoms[1];
    expect(cramps.label, 'Cramps');
    expect(cramps.phaseCounts[CyclePhase.menstrual], 8);
    expect(cramps.sentence,
        'Most often logged around the beginning of your period (Days 1–2).');

    final fatigue = i.symptoms[0];
    expect(fatigue.phaseCounts[CyclePhase.luteal], 8);
    expect(fatigue.sentence, 'Most often logged in the days before your period (Days 26–27).');

    expect(i.mood!.label, 'Good');
    expect(i.mood!.percent, 75);
    expect(i.mood!.sentence, 'Your most frequently logged mood is “Good” (75% of days).');
  });

  test('symptoms logged before any period are counted but not placed', () {
    final i = _compute([], [_log(DateTime.utc(2025, 5, 1), symptoms: ['headache'])]);
    expect(i.symptoms.single.count, 1);
    expect(i.symptoms.single.phaseCounts, isEmpty);
    expect(i.symptoms.single.sentence, contains('not yet linked'));
  });
}
