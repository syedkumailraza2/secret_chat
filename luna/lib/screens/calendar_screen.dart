import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../providers/cycle_provider.dart';
import '../providers/log_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import '../utils/date_utils.dart';
import '../widgets/calendar_grid.dart';
import '../widgets/day_detail.dart';
import '../widgets/secret_trigger.dart';

/// Month calendar with period history, predictions and the selected day's check-in.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final selected = context.read<LogProvider>().selectedDate;
    _month = DateTime.utc(selected.year, selected.month);
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime.utc(_month.year, _month.month + delta));

  void _onDayTap(DateTime d) {
    context.read<LogProvider>().selectDate(d);
    if (d.month != _month.month) setState(() => _month = DateTime.utc(d.year, d.month));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final snapshot = context.select<CycleProvider, DateTime?>((p) => p.snapshot?.nextPeriodStart);
    final bottom = MediaQuery.paddingOf(context).bottom + 110;

    return ColoredBox(
      color: c.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onAccount: () => MainShell.goToTab(context, 3)),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(AppSpacing.margin, AppSpacing.xs, AppSpacing.margin, bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _MonthTitle(
                      month: _month,
                      onPrev: () => _shiftMonth(-1),
                      onNext: () => _shiftMonth(1),
                    ),
                    const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                    CalendarLegend(nextPeriod: snapshot),
                    const SizedBox(height: AppSpacing.md),
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragEnd: (d) {
                        final v = d.primaryVelocity ?? 0;
                        if (v.abs() > 200) _shiftMonth(v < 0 ? 1 : -1);
                      },
                      child: CalendarGrid(month: _month, onDayTap: _onDayTap),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Divider(color: c.outlineVariant.withValues(alpha: 0.3)),
                    const SizedBox(height: AppSpacing.md),
                    const DayDetail(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAccount});
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // The spa icon and the wordmark sit apart in this spaceBetween row,
          // so each carries its own trigger to keep the layout unchanged.
          SecretTrigger(
            child: Icon(Symbols.spa, size: 22.4, weight: 200, color: c.primary),
          ),
          SecretTrigger(
            child: Text(
              'Luna',
              style: AppText.headlineMd.copyWith(color: c.primary, letterSpacing: -0.025 * 28),
            ),
          ),
          GestureDetector(
            onTap: onAccount,
            child: Icon(Symbols.account_circle, size: 24, weight: 200, color: c.primary),
          ),
        ],
      ),
    );
  }
}

class _MonthTitle extends StatelessWidget {
  const _MonthTitle({required this.month, required this.onPrev, required this.onNext});

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget chevron(IconData icon, VoidCallback onTap, String label) => Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(icon, size: 19.2, weight: 200, color: c.onSurfaceVariant),
            ),
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  formatMonth(month),
                  style: AppText.headlineLgMobile.copyWith(color: c.primary, letterSpacing: -0.025 * 32),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${month.year}',
                style: AppText.labelMd.copyWith(color: c.outline, letterSpacing: 0.05 * 12),
              ),
            ],
          ),
        ),
        chevron(Symbols.chevron_left, onPrev, 'Previous month'),
        const SizedBox(width: 4),
        chevron(Symbols.chevron_right, onNext, 'Next month'),
      ],
    );
  }
}
