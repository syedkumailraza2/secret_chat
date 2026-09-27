import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/isar_service.dart';
import '../models/app_settings.dart';
import '../models/daily_log.dart';
import '../models/period.dart';
import '../utils/date_utils.dart';

enum ExportFormat { json, csv }

/// Writes the user's raw on-device data to a temp file and opens the
/// system share sheet. Nothing leaves the device unless the user shares it.
class ExportService {
  ExportService._();
  static final instance = ExportService._();

  static final _day = DateFormat('yyyy-MM-dd');
  static String _date(DateTime d) => _day.format(d);

  /// [origin] anchors the share popover on iPad.
  Future<void> exportAndShare(ExportFormat format, {Rect? origin}) async {
    final db = IsarService.instance;
    final settings = await db.getSettings();
    final periods = await db.getPeriods();
    final logs = await db.getAllDailyLogs();

    final content = format == ExportFormat.json
        ? buildJson(settings, periods, logs)
        : buildCsv(periods, logs);
    final ext = format == ExportFormat.json ? 'json' : 'csv';

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/luna-export-${_date(DateTime.now())}.$ext');
    await file.writeAsString(content, flush: true);

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: format == ExportFormat.json ? 'application/json' : 'text/csv')],
      subject: 'Luna data export',
      sharePositionOrigin: origin,
    ));
  }

  static String buildJson(AppSettings s, List<Period> periods, List<DailyLog> logs) {
    final t = s.reminderTime;
    final data = {
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': {
        'cycleLength': s.defaultCycleLength,
        'periodLength': s.defaultPeriodLength,
        'periodReminder': s.periodReminderEnabled,
        'dailyReminder': s.dailyReminderEnabled,
        'reminderTime': t == null
            ? '20:00'
            : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
        'appLock': s.biometricLockEnabled,
        'theme': s.themeMode,
      },
      'periods': [
        for (final p in periods)
          {
            'startDate': _date(p.startDate),
            'endDate': p.endDate == null ? null : _date(p.endDate!),
            'flow': p.flow,
          },
      ],
      'dailyLogs': [
        for (final l in logs)
          {
            'date': _date(l.date),
            'flow': l.flow,
            'symptoms': l.symptoms,
            'mood': l.mood,
            'note': l.note,
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// One row per day that has a check-in or falls inside a recorded period.
  static String buildCsv(List<Period> periods, List<DailyLog> logs) {
    final byDay = {for (final l in logs) dayKey(l.date): l};
    final periodDays = <DateTime>{};
    final todayKey = today();
    for (final p in periods) {
      final end = p.endDate ?? todayKey;
      for (var d = dayKey(p.startDate); !d.isAfter(end); d = addDays(d, 1)) {
        periodDays.add(d);
      }
    }
    final days = {...byDay.keys, ...periodDays}.toList()..sort();

    final rows = <List<String>>[
      ['date', 'in_period', 'flow', 'symptoms', 'mood', 'note'],
      for (final d in days)
        [
          _date(d),
          periodDays.contains(d) ? 'yes' : 'no',
          byDay[d]?.flow ?? '',
          byDay[d]?.symptoms.join(';') ?? '',
          byDay[d]?.mood ?? '',
          byDay[d]?.note ?? '',
        ],
    ];
    return '${rows.map((r) => r.map(_csvCell).join(',')).join('\r\n')}\r\n';
  }

  /// RFC 4180 quoting, plus a leading apostrophe to defuse spreadsheet formulas.
  static String _csvCell(String v) {
    var s = v;
    if (s.isNotEmpty && '=+-@'.contains(s[0])) s = "'$s";
    if (s.contains(RegExp(r'[",\r\n]'))) s = '"${s.replaceAll('"', '""')}"';
    return s;
  }
}
