import 'package:isar_community/isar.dart';

part 'daily_log.g.dart';

/// One check-in per calendar day.
@collection
class DailyLog {
  Id id = Isar.autoIncrement;

  /// Normalized to midnight UTC of the local calendar day (see `dayKey()`).
  @Index(unique: true, replace: true)
  late DateTime date;

  /// Flow intensity logged that day: 'none' | 'spotting' | 'light' | 'medium' | 'heavy'.
  String? flow;

  List<String> symptoms = []; // e.g. ['cramps', 'headache', 'bloating']
  String? mood; // e.g. 'good', 'okay', 'low'
  String? note;

  /// Wall-clock time the check-in was last saved (shown as "Logged 8:45 PM").
  DateTime? loggedAt;

  bool get isEmpty =>
      (flow == null || flow == 'none') &&
      symptoms.isEmpty &&
      mood == null &&
      (note == null || note!.trim().isEmpty);
}
