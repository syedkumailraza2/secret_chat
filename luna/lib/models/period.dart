import 'package:isar_community/isar.dart';

part 'period.g.dart';

/// A distinct menstrual bleed window. Dates are normalized with `dayKey()`.
@collection
class Period {
  Id id = Isar.autoIncrement;

  @Index()
  late DateTime startDate;

  /// Null while the period is ongoing.
  DateTime? endDate;

  /// 'spotting' | 'light' | 'medium' | 'heavy'
  late String flow;
}
