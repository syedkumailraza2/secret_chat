import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cycle_provider.dart';
import '../providers/log_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import '../utils/date_utils.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Monday-first weekday row + 6-week month grid (calendar.html).
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({super.key, required this.month, required this.onDayTap});

  final DateTime month;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cycle = context.watch<CycleProvider>();
    final logs = context.watch<LogProvider>();
    final days = monthGrid(month);
    final now = today();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: c.surfaceContainerHigh.withValues(alpha: 0.6)),
            ),
          ),
          child: Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Text(
                    w.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppText.labelSm.copyWith(color: c.outline, letterSpacing: 11 * 0.05),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var week = 0; week < 6; week++)
          Padding(
            padding: EdgeInsets.only(top: week == 0 ? 0 : 10),
            child: Row(
              children: [
                for (final d in days.sublist(week * 7, week * 7 + 7))
                  Expanded(
                    child: _DayCell(
                      date: d,
                      inMonth: d.month == month.month,
                      isToday: isSameDay(d, now),
                      isSelected: isSameDay(d, logs.selectedDate),
                      isPeriod: !d.isAfter(now) && cycle.isPeriodDay(d),
                      // Future days of an ongoing period are still estimates.
                      isPredicted: d.isAfter(now) &&
                          (cycle.isPredictedPeriodDay(d) || cycle.isPeriodDay(d)),
                      hasLog: logs.hasLog(d),
                      onTap: () => onDayTap(d),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.isPeriod,
    required this.isPredicted,
    required this.hasLog,
    required this.onTap,
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final bool isPeriod;
  final bool isPredicted;
  final bool hasLog;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Light and dark mockups use different tokens for the same states.
    final periodFill = dark ? c.secondaryContainer : c.primaryContainer;
    final periodText = dark ? c.onSecondaryContainer : c.surface;
    final accent = dark ? c.primary : c.primaryContainer;

    Color? fill;
    Color text = c.onSurface;
    int weight = 400;
    Border? border;
    List<BoxShadow>? shadow;
    Widget? marker;
    var opacity = 1.0;

    if (isPeriod) {
      fill = periodFill;
      text = periodText;
      weight = 500;
      if (isToday || isSelected) {
        shadow = [BoxShadow(color: accent.withValues(alpha: 0.35), spreadRadius: 2)];
      }
    } else if (isToday) {
      fill = dark ? null : c.surfaceContainerLow;
      text = dark ? c.primaryFixed : c.primary;
      weight = 600;
      border = Border.all(color: accent, width: 2);
      shadow = [
        dark
            ? BoxShadow(color: c.primary.withValues(alpha: 0.18), blurRadius: 20)
            : BoxShadow(color: accent.withValues(alpha: 0.2), spreadRadius: 2),
      ];
    } else if (isPredicted) {
      text = dark ? c.secondary : c.primaryContainer;
      weight = 500;
      opacity = 0.85;
      marker = Positioned(
        bottom: -2,
        child: Text('~', style: TextStyle(fontSize: 9.6, height: 1, color: text)),
      );
    } else if (!inMonth) {
      text = c.outlineVariant.withValues(alpha: dark ? 0.5 : 1);
    }

    if (isSelected && !isToday && !isPeriod) {
      fill = c.surfaceContainerHigh;
      if (!isPredicted) text = c.primary;
      weight = 600;
    }

    final circle = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: border,
        boxShadow: shadow,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Center(
            child: Text(
            '${date.day}',
              style: AppText.bodySm.weight(weight).copyWith(color: text),
            ),
          ),
          ?marker,
          if (hasLog)
            Positioned(
              bottom: 4,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: isPeriod ? periodText : accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: isPredicted ? _Dashed(color: accent, child: Opacity(opacity: opacity, child: circle)) : circle,
        ),
      ),
    );
  }
}

/// Dashed 1px circle outline (Tailwind `border border-dashed`).
class _Dashed extends StatelessWidget {
  const _Dashed({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(foregroundPainter: _DashedCirclePainter(color.withValues(alpha: 0.85)), child: child);
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = (Offset.zero & size).deflate(0.5);
    const dashes = 18;
    const sweep = 2 * 3.141592653589793 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}

/// Legend row under the month title.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key, this.nextPeriod});

  final DateTime? nextPeriod;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? c.primary : c.primaryContainer;
    final label = AppText.labelSm.copyWith(color: c.onSurfaceVariant);

    Widget item(Widget dot, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [dot, const SizedBox(width: AppSpacing.xs), Text(text, style: label)],
        );

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        item(
          _dot(color: dark ? c.secondaryContainer : c.primaryContainer),
          'Confirmed period',
        ),
        item(
          CustomPaint(
            foregroundPainter: _DashedCirclePainter(accent),
            child: const SizedBox(width: 10, height: 10),
          ),
          nextPeriod == null ? 'Estimated period' : 'Estimated period (~${formatShort(nextPeriod!)})',
        ),
        item(
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.primary.withValues(alpha: 0.4)),
            ),
          ),
          'Today',
        ),
      ],
    );
  }

  Widget _dot({required Color color}) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
