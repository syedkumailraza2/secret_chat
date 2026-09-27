import 'package:intl/intl.dart';

/// Normalizes any DateTime to midnight UTC of its *local* calendar day.
/// Every date stored in Isar goes through this, so day math is immune to
/// DST shifts and timezone offsets.
DateTime dayKey(DateTime d) => DateTime.utc(d.year, d.month, d.day);

DateTime today() => dayKey(DateTime.now());

/// Whole days from [a] to [b] (both normalized first).
int daysBetween(DateTime a, DateTime b) =>
    dayKey(b).difference(dayKey(a)).inDays;

DateTime addDays(DateTime d, int days) {
  final k = dayKey(d);
  return DateTime.utc(k.year, k.month, k.day + days);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Monday-first grid of 42 days (6 weeks) covering [month].
List<DateTime> monthGrid(DateTime month) {
  final first = DateTime.utc(month.year, month.month, 1);
  final lead = (first.weekday - DateTime.monday) % 7;
  final start = addDays(first, -lead);
  return List.generate(42, (i) => addDays(start, i));
}

String formatShort(DateTime d) => DateFormat('MMM d').format(d); // Oct 5
String formatLong(DateTime d) => DateFormat('EEEE, MMMM d').format(d); // Tuesday, September 23
String formatMonthDay(DateTime d) => DateFormat('MMMM d').format(d); // September 23
String formatMonth(DateTime d) => DateFormat('MMMM').format(d);
String formatTime(DateTime d) => DateFormat('h:mm a').format(d.toLocal());
