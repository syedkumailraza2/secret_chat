import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_log.dart';
import '../providers/cycle_provider.dart';
import '../providers/log_provider.dart';
import '../services/cycle_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';
import 'log_today_sheet.dart';

/// "Editorial inspection sheet" for the calendar's selected day.
class DayDetail extends StatelessWidget {
  const DayDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final logs = context.watch<LogProvider>();
    final cycle = context.watch<CycleProvider>();
    final date = logs.selectedDate;
    final log = logs.selectedLog;
    final isFuture = date.isAfter(today());
    final predicted = isFuture && (cycle.isPredictedPeriodDay(date) || cycle.isPeriodDay(date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TitleRow(date: date, subtitle: _subtitle(cycle, date, isFuture), log: log),
        const SizedBox(height: AppSpacing.md),
        if (isFuture)
          _Message(
            predicted
                ? 'Your period may arrive around this day. This is an estimate based on your recent cycles.'
                : 'This day hasn’t arrived yet. You can check in once it does.',
          )
        else if (log == null) ...[
          const _Message('Nothing logged for this day yet. A quick check-in helps Luna learn your rhythm.'),
          const SizedBox(height: AppSpacing.md),
          _OutlinedPill(
            label: 'Add check-in',
            expand: true,
            onTap: () => showLogTodaySheet(context, date: date),
          ),
        ] else
          ..._logged(context, c, date, log),
      ],
    );
  }

  String? _subtitle(CycleProvider cycle, DateTime date, bool isFuture) {
    final info = cycle.dayInfo(date);
    if (info == null) return null;
    var day = info.day;
    var phase = info.phase;
    // Project future days onto the predicted cycle instead of counting past its end.
    if (isFuture && day > cycle.cycleLength) {
      day = (day - 1) % cycle.cycleLength + 1;
      phase = CycleCalculator.phaseForDay(day, cycle.cycleLength, cycle.periodLength);
    }
    final prefix = isFuture ? 'Estimated cycle day' : 'Cycle day';
    return '$prefix $day · ${phase.label} phase';
  }

  List<Widget> _logged(BuildContext context, AppColors c, DateTime date, DailyLog log) {
    final pills = [
      if (log.flow != null && log.flow != 'none') 'Flow · ${labelFor(flowOptions, log.flow!)}',
      if (log.mood != null) 'Mood · ${labelFor(moodOptions, log.mood!)}',
      for (final s in log.symptoms) labelFor(symptomOptions, s),
    ];
    final note = log.note?.trim();
    final label = AppText.labelSm.copyWith(color: c.outline, letterSpacing: 11 * 0.05);

    return [
      if (pills.isNotEmpty) ...[
        Text('SYMPTOMS & OBSERVATIONS', style: label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in pills)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: c.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(p, style: AppText.labelMd.copyWith(color: c.onSurfaceVariant)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (note != null && note.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.base),
            border: Border.all(color: c.outlineVariant.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('REFLECTION', style: label),
              const SizedBox(height: 6),
              Text(
                '“$note”',
                style: AppText.headlineSm.copyWith(
                  color: c.onSurface,
                  fontStyle: FontStyle.italic,
                  height: 1.625,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: _OutlinedPill(
                label: 'Edit check-in',
                expand: true,
                onTap: () => showLogTodaySheet(context, date: date),
              ),
            ),
            const SizedBox(width: 12),
            _OutlinedPill(
              label: 'Delete',
              muted: true,
              onTap: () => _confirmDelete(context, date),
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _confirmDelete(BuildContext context, DateTime date) async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: c.inverseSurface.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Delete this check-in?', style: AppText.headlineSm.copyWith(color: c.primary)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your entry for ${formatMonthDay(date)} will be removed from this device. This can’t be undone.',
                style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _OutlinedPill(
                      label: 'Keep',
                      expand: true,
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _OutlinedPill(
                    label: 'Delete',
                    danger: true,
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<LogProvider>().deleteLog(date);
    }
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.date, required this.subtitle, required this.log});

  final DateTime date;
  final String? subtitle;
  final DailyLog? log;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loggedAt = log?.loggedAt;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatMonthDay(date), style: AppText.headlineMd.copyWith(color: c.primary)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppText.bodySm.copyWith(color: c.onSurfaceVariant)),
              ],
            ],
          ),
        ),
        if (loggedAt != null)
          Container(
            margin: const EdgeInsets.only(top: 8, left: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text('Logged ${formatTime(loggedAt)}', style: AppText.labelSm.copyWith(color: c.outline)),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.bodyMd.copyWith(color: context.colors.onSurfaceVariant));
}

/// Rounded-full outlined button used for Edit / Delete / Add check-in.
class _OutlinedPill extends StatelessWidget {
  const _OutlinedPill({
    required this.label,
    required this.onTap,
    this.expand = false,
    this.muted = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool expand;
  final bool muted;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = danger ? c.error : (muted ? c.outline : c.onSurface);
    final borderColor = danger
        ? c.error.withValues(alpha: 0.4)
        : c.outlineVariant.withValues(alpha: muted ? 0.6 : 1);
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: borderColor)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        highlightColor: c.surfaceContainer,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: expand ? 16 : 20, vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.labelLg.copyWith(color: fg),
          ),
        ),
      ),
    );
  }
}
