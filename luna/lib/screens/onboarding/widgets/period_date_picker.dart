import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import '../../../utils/date_utils.dart';

/// Monday-first month calendar used to pick the last period start.
/// Days after today are disabled.
class PeriodDatePicker extends StatefulWidget {
  const PeriodDatePicker({super.key, required this.selected, required this.onSelected});

  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  @override
  State<PeriodDatePicker> createState() => _PeriodDatePickerState();
}

class _PeriodDatePickerState extends State<PeriodDatePicker> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final base = widget.selected ?? today();
    _month = DateTime.utc(base.year, base.month);
  }

  bool get _isCurrentMonth {
    final t = today();
    return _month.year == t.year && _month.month == t.month;
  }

  void _shift(int delta) =>
      setState(() => _month = DateTime.utc(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = today();

    // Drop trailing weeks that sit entirely in the next month.
    final grid = monthGrid(_month);
    final weeks = <List<DateTime>>[
      for (var i = 0; i < grid.length; i += 7)
        if (grid[i].month == _month.month || grid[i + 6].month == _month.month)
          grid.sublist(i, i + 7),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Month navigation
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.outlineVariant.withValues(alpha: 0.3))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Chevron(
                icon: Symbols.chevron_left,
                label: 'Previous month',
                onTap: () => _shift(-1),
              ),
              Flexible(
                child: Text(
                  DateFormat('MMMM y').format(_month),
                  textAlign: TextAlign.center,
                  style: AppText.headlineSm.copyWith(color: c.primary, fontStyle: FontStyle.italic),
                ),
              ),
              _Chevron(
                icon: Symbols.chevron_right,
                label: 'Next month',
                onTap: _isCurrentMonth ? null : () => _shift(1),
              ),
            ],
          ),
        ),
        // Weekday initials
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: AppText.labelSm.copyWith(
                      color: c.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (var w = 0; w < weeks.length; w++)
          Padding(
            padding: EdgeInsets.only(top: w == 0 ? 0 : 8),
            child: Row(children: [for (final day in weeks[w]) Expanded(child: _dayCell(day, now))]),
          ),
      ],
    );
  }

  Widget _dayCell(DateTime day, DateTime now) {
    final c = context.colors;
    Widget cell;
    if (day.month != _month.month) {
      cell = Text(
        '${day.day}',
        style: AppText.bodySm.copyWith(color: c.outlineVariant.withValues(alpha: 0.5)),
      );
    } else {
      final future = day.isAfter(now);
      final selected = widget.selected != null && isSameDay(day, widget.selected!);
      cell = GestureDetector(
        onTap: future ? null : () => widget.onSelected(day),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.primaryContainer : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${day.day}',
            style: selected
                ? AppText.bodyMd.copyWith(color: c.surface).weight(600)
                : AppText.bodyMd.copyWith(
                    color: future ? c.onSurface.withValues(alpha: 0.3) : c.onSurface,
                  ),
          ),
        ),
      );
    }
    return SizedBox(height: 44, child: Center(child: cell));
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 20,
            weight: 200,
            color: onTap == null ? c.onSurfaceVariant.withValues(alpha: 0.3) : c.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
