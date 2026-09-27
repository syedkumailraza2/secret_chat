import 'dart:math' as math;

import '../models/daily_log.dart';
import '../models/period.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';
import '../utils/helpers.dart';
import 'cycle_calculator.dart';

/// One bar in "Your cycles": a completed cycle and the period that opened it.
class CycleBar {
  const CycleBar({required this.length, required this.periodLength, required this.label});
  final int length;
  final int periodLength;
  final String label; // "Cycle 1" … "Recent"
}

class SymptomPattern {
  const SymptomPattern({
    required this.id,
    required this.label,
    required this.count,
    required this.phaseCounts,
    required this.sentence,
  });
  final String id;
  final String label;

  /// Days this symptom was logged.
  final int count;

  /// Occurrences per cycle phase (only days that follow a logged period).
  final Map<CyclePhase, int> phaseCounts;
  final String sentence;
}

class MoodPattern {
  const MoodPattern({required this.id, required this.label, required this.percent});
  final String id;
  final String label;
  final int percent; // of days with a mood logged
  String get sentence =>
      'Your most frequently logged mood is “$label” ($percent% of days).';
}

class Insights {
  const Insights({
    required this.window,
    required this.trackedCycles,
    required this.averageCycle,
    required this.averagePeriod,
    required this.averages,
    required this.cycleFromHistory,
    required this.periodFromHistory,
    required this.shortest,
    required this.longest,
    required this.variation,
    required this.bars,
    required this.consistency,
    required this.symptoms,
    required this.mood,
  });

  /// Number of recent cycles the averages & bars cover (3, 6 or 12).
  final int window;

  /// All completed cycles on record.
  final int trackedCycles;

  /// Rounded; falls back to the baseline when there is no history.
  final int averageCycle;
  final int averagePeriod;

  /// Average cycle length over the last 3 / 6 / 12 cycles (null without data).
  final Map<int, double?> averages;
  final bool cycleFromHistory;
  final bool periodFromHistory;
  final int? shortest;
  final int? longest;

  /// Population σ in days over the window (null with < 2 cycles).
  final double? variation;

  /// Oldest first; the last bar is labelled "Recent".
  final List<CycleBar> bars;
  final String consistency;
  final List<SymptomPattern> symptoms;
  final MoodPattern? mood;

  bool get hasCycles => trackedCycles > 0;
}

/// Pure, on-device analytics for the Insights screen. No Flutter imports.
class InsightsService {
  InsightsService._();

  static const windows = [3, 6, 12];
  static const emptyMessage = 'Log a couple of cycles to see your patterns.';

  static Insights compute({
    required List<Period> periods,
    required List<DailyLog> logs,
    required int baselineCycleLength,
    required int baselinePeriodLength,
    int window = 6,
    int maxSymptoms = 2,
  }) {
    final sorted = [...periods]..sort((a, b) => a.startDate.compareTo(b.startDate));
    final allBars = _bars(sorted, baselinePeriodLength);
    final recent = allBars.length <= window ? allBars : allBars.sublist(allBars.length - window);
    final lengths = [for (final b in recent) b.length];

    final avgCycle = CycleCalculator.averageCycleLength(sorted, lastN: window);
    final avgPeriod = CycleCalculator.averagePeriodLength(sorted, lastN: window);
    final sigma = CycleCalculator.cycleVariation(sorted, lastN: window);
    final shortest = lengths.isEmpty ? null : lengths.reduce(math.min);
    final longest = lengths.isEmpty ? null : lengths.reduce(math.max);

    final cycleLen = avgCycle?.round() ?? baselineCycleLength;
    final periodLen = avgPeriod?.round() ?? baselinePeriodLength;

    return Insights(
      window: window,
      trackedCycles: allBars.length,
      averageCycle: cycleLen,
      averagePeriod: periodLen,
      averages: {
        for (final n in windows) n: CycleCalculator.averageCycleLength(sorted, lastN: n),
      },
      cycleFromHistory: avgCycle != null,
      periodFromHistory: avgPeriod != null,
      shortest: shortest,
      longest: longest,
      variation: sigma,
      bars: [
        for (var i = 0; i < recent.length; i++)
          CycleBar(
            length: recent[i].length,
            periodLength: recent[i].periodLength,
            label: i == recent.length - 1 ? 'Recent' : 'Cycle ${i + 1}',
          ),
      ],
      consistency: consistencySentence(lengths, sigma),
      symptoms: symptomPatterns(sorted, logs, cycleLen, periodLen, limit: maxSymptoms),
      mood: moodPattern(logs),
    );
  }

  /// Completed cycles (consecutive starts 15–90 days apart), oldest first.
  static List<CycleBar> _bars(List<Period> sorted, int fallbackPeriod) {
    final out = <CycleBar>[];
    for (var i = 1; i < sorted.length; i++) {
      final start = sorted[i - 1];
      final gap = daysBetween(start.startDate, sorted[i].startDate);
      if (gap < 15 || gap > 90) continue;
      final pLen = start.endDate == null
          ? fallbackPeriod
          : daysBetween(start.startDate, start.endDate!) + 1;
      out.add(CycleBar(length: gap, periodLength: pLen.clamp(1, gap), label: ''));
    }
    return out;
  }

  static String consistencySentence(List<int> lengths, double? sigma) {
    if (lengths.isEmpty) return emptyMessage;
    if (lengths.length == 1) {
      return 'Your one tracked cycle lasted ${lengths.first} days. '
          'Log another to see your rhythm.';
    }
    final lo = lengths.reduce(math.min);
    final hi = lengths.reduce(math.max);
    final s = sigma ?? 0;
    final rhythm = s <= 2
        ? 'showing consistent rhythm'
        : s <= 4
            ? 'showing a fairly regular rhythm'
            : 'showing a more variable rhythm';
    final span = lo == hi ? 'have each lasted $lo days' : 'have ranged from $lo–$hi days';
    return 'Your recent cycles $span, $rhythm.';
  }

  /// Top symptoms by frequency, each mapped to the cycle phase & day range
  /// where it clusters.
  static List<SymptomPattern> symptomPatterns(
    List<Period> periods,
    List<DailyLog> logs,
    int cycleLength,
    int periodLength, {
    int limit = 2,
  }) {
    final counts = <String, int>{};
    final days = <String, List<int>>{};
    for (final log in logs) {
      final info = CycleCalculator.dayInfo(periods, log.date,
          cycleLength: cycleLength, periodLength: periodLength);
      for (final s in log.symptoms.toSet()) {
        counts[s] = (counts[s] ?? 0) + 1;
        if (info != null) (days[s] ??= []).add(info.day);
      }
    }
    final ranked = counts.keys.toList()
      ..sort((a, b) {
        final c = counts[b]!.compareTo(counts[a]!);
        return c != 0 ? c : a.compareTo(b);
      });

    return [
      for (final id in ranked.take(limit))
        _pattern(id, counts[id]!, days[id] ?? const [], cycleLength, periodLength),
    ];
  }

  static SymptomPattern _pattern(
      String id, int count, List<int> cycleDays, int cycleLength, int periodLength) {
    final phaseCounts = <CyclePhase, int>{};
    final byPhase = <CyclePhase, List<int>>{};
    for (final d in cycleDays) {
      final p = CycleCalculator.phaseForDay(d, cycleLength, periodLength);
      phaseCounts[p] = (phaseCounts[p] ?? 0) + 1;
      (byPhase[p] ??= []).add(d);
    }

    String sentence;
    if (cycleDays.isEmpty) {
      sentence = 'Logged on ${pluralDays(count)} so far, not yet linked to a tracked period.';
    } else {
      // Dominant phase (ties go to the earlier phase).
      final phase = CyclePhase.values
          .reduce((a, b) => (phaseCounts[b] ?? 0) > (phaseCounts[a] ?? 0) ? b : a);
      final (lo, hi) = _peakRange(byPhase[phase]!);
      final range = lo == hi ? 'Day $lo' : 'Days $lo–$hi';
      final where = switch (phase) {
        CyclePhase.menstrual => lo <= 2
            ? 'around the beginning of your period'
            : 'during your period',
        CyclePhase.follicular => 'in the days after your period',
        CyclePhase.ovulation => 'around ovulation',
        CyclePhase.luteal => hi >= cycleLength - 5
            ? 'in the days before your period'
            : 'during the luteal phase',
      };
      sentence = 'Most often logged $where ($range).';
    }

    return SymptomPattern(
      id: id,
      label: labelFor(symptomOptions, id),
      count: count,
      phaseCounts: phaseCounts,
      sentence: sentence,
    );
  }

  /// The most-logged cycle day, widened over neighbouring days that were
  /// logged at least half as often.
  static (int, int) _peakRange(List<int> days) {
    final freq = <int, int>{};
    for (final d in days) {
      freq[d] = (freq[d] ?? 0) + 1;
    }
    var peak = freq.keys.first;
    for (final d in freq.keys) {
      if (freq[d]! > freq[peak]! || (freq[d] == freq[peak] && d < peak)) peak = d;
    }
    final threshold = freq[peak]! / 2;
    var lo = peak, hi = peak;
    while ((freq[lo - 1] ?? 0) >= threshold && (freq[lo - 1] ?? 0) > 0) {
      lo--;
    }
    while ((freq[hi + 1] ?? 0) >= threshold && (freq[hi + 1] ?? 0) > 0) {
      hi++;
    }
    return (lo, hi);
  }

  static MoodPattern? moodPattern(List<DailyLog> logs) {
    final counts = <String, int>{};
    for (final l in logs) {
      final m = l.mood;
      if (m != null && m.isNotEmpty) counts[m] = (counts[m] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final total = counts.values.reduce((a, b) => a + b);
    // Ties resolve in the order moods appear in the log sheet.
    int order(String id) {
      final i = moodOptions.indexWhere((o) => o.id == id);
      return i < 0 ? moodOptions.length : i;
    }

    final top = counts.keys.reduce((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      if (c != 0) return c > 0 ? b : a;
      return order(b) < order(a) ? b : a;
    });
    return MoodPattern(
      id: top,
      label: labelFor(moodOptions, top),
      percent: (counts[top]! * 100 / total).round(),
    );
  }
}
