import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/daily_log.dart';
import '../providers/cycle_provider.dart';
import '../providers/log_provider.dart';
import '../services/cycle_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';
import '../utils/helpers.dart';
import '../widgets/cycle_header.dart';
import '../widgets/cycle_timeline.dart';
import '../widgets/log_button.dart';
import '../widgets/log_today_sheet.dart';
import '../widgets/secret_trigger.dart';

/// Today: hero, cycle timeline, next-period estimate, log CTA, today's log
/// and a small observed pattern.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _headerHeight = 58.0; // py-space-sm ×2 + headline-md line

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cycle = context.watch<CycleProvider>();
    final logs = context.watch<LogProvider>();
    final snap = cycle.snapshot;
    final mq = MediaQuery.paddingOf(context);
    final hairline = Container(height: 1, color: c.outlineVariant.withValues(alpha: 0.3));

    final sections = <Widget>[
      CycleHeader(snapshot: snap),
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
        child: CycleTimeline(
          phases: snap?.phases ?? CycleCalculator.phaseRanges(cycle.cycleLength, cycle.periodLength),
          current: snap?.phase,
          progress: snap?.progress,
        ),
      ),
      hairline,
      _Prediction(snapshot: snap),
      hairline,
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: snap == null
            ? LogButton(
                label: 'Log period start',
                caption: 'Your first entry sets the rhythm.',
                onPressed: () => showLogTodaySheet(context),
              )
            : LogButton(onPressed: () => showLogTodaySheet(context)),
      ),
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: _TodayLog(log: logs.todayLog),
      ),
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: _PatternNote(text: _pattern(logs.allLogs, cycle)),
      ),
    ];

    return Stack(
      children: [
        ListView.separated(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.margin,
            mq.top + _headerHeight + 1 + AppSpacing.md,
            AppSpacing.margin,
            // With extendBody, padding.bottom already includes the nav bar.
            math.max(mq.bottom + AppSpacing.lg, 110),
          ),
          itemCount: sections.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
          itemBuilder: (_, i) => sections[i],
        ),
        Positioned(top: 0, left: 0, right: 0, child: _TopBar(topInset: mq.top)),
      ],
    );
  }

  /// Most frequent symptom and the phase it usually lands in.
  static String _pattern(List<DailyLog> logs, CycleProvider cycle) {
    final counts = <String, int>{};
    final phases = <String, Map<CyclePhase, int>>{};
    for (final l in logs) {
      final info = cycle.dayInfo(l.date);
      for (final s in l.symptoms) {
        counts[s] = (counts[s] ?? 0) + 1;
        if (info != null) {
          final m = phases.putIfAbsent(s, () => {});
          m[info.phase] = (m[info.phase] ?? 0) + 1;
        }
      }
    }
    if (counts.isEmpty) return 'A few more check-ins and Luna will begin to notice your patterns.';

    final top = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    final name = labelFor(symptomOptions, top.key).toLowerCase();
    if (top.value < 3) return 'You’ve noted $name recently. Keep logging and a pattern may appear.';

    final byPhase = phases[top.key];
    if (byPhase != null && byPhase.isNotEmpty) {
      final best = byPhase.entries.reduce((a, b) => b.value > a.value ? b : a);
      if (best.value * 2 >= top.value) {
        final when = switch (best.key) {
          CyclePhase.menstrual => 'around the beginning of your cycle',
          CyclePhase.follicular => 'in the days after your period',
          CyclePhase.ovulation => 'around ovulation',
          CyclePhase.luteal => 'in the days before your period',
        };
        return 'You usually experience $name $when.';
      }
    }
    return '${capitalize(name)} is the symptom you log most often.';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.9),
            border: Border(bottom: BorderSide(color: c.outlineVariant.withValues(alpha: 0.3))),
          ),
          padding: EdgeInsets.only(top: topInset),
          child: SizedBox(
            height: HomeScreen._headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
              child: Row(
                children: [
                  SecretTrigger(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Symbols.spa, size: 20, weight: 200, color: c.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Luna',
                          style: AppText.headlineMd.copyWith(color: c.primary, letterSpacing: -0.025 * 28),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: 'Account Settings',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => MainShell.goToTab(context, 3),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Symbols.account_circle, size: 24, weight: 200, color: c.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Prediction extends StatelessWidget {
  const _Prediction({required this.snapshot});

  final CycleSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = snapshot;
    final big = AppText.headlineLgMobile.copyWith(color: c.primary);
    final body = AppText.bodyMd.copyWith(color: c.onSurfaceVariant);
    final small = AppText.bodySm.copyWith(color: c.outline);

    final String lead;
    final String rest;
    String? note;
    if (s == null) {
      lead = 'No estimate';
      rest = 'until your first period is logged';
    } else if (s.daysUntilNextPeriod == 0) {
      lead = 'Today';
      rest = 'your period is estimated to start';
    } else if (s.isLate) {
      lead = '${pluralDays(-s.daysUntilNextPeriod)} late';
      rest = 'past your estimated start';
      note = s.isIrregular
          ? 'It’s been a while since your last period. Cycles can vary with stress, travel or rest; if this continues, a check-in with a healthcare provider may help.'
          : 'A few days either way is common. Log your period when it begins.';
    } else {
      lead = pluralDays(s.daysUntilNextPeriod);
      rest = 'until your estimated period';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: lead, style: big),
              const WidgetSpan(child: SizedBox(width: 8)),
              TextSpan(text: rest, style: body),
            ]),
          ),
          const SizedBox(height: 4),
          if (s == null)
            Text('Log a period start and Luna will estimate the next one.', style: small)
          else
            Row(
              children: [
                Flexible(child: Text('${formatShort(s.nextPeriodStart)} · estimated start', style: small)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'ESTIMATE',
                    style: AppText.labelSm.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      color: c.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note, style: small.copyWith(color: c.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _TodayLog extends StatelessWidget {
  const _TodayLog({required this.log});

  final DailyLog? log;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = log;
    final rows = <(String, List<String>)>[
      ('Flow', [if (l?.flow != null) labelFor(flowOptions, l!.flow!)]),
      ('Mood', [if (l?.mood != null) labelFor(moodOptions, l!.mood!)]),
      ('Symptoms', [for (final s in l?.symptoms ?? const <String>[]) labelFor(symptomOptions, s)]),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text('Today’s log', style: AppText.headlineSm.copyWith(color: c.onSurface)),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showLogTodaySheet(context),
              child: Text('Edit', style: AppText.labelSm.copyWith(color: c.onSecondaryContainer)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < rows.length; i++)
          Container(
            decoration: i == 0
                ? null
                : BoxDecoration(
                    border: Border(top: BorderSide(color: c.outlineVariant.withValues(alpha: 0.2))),
                  ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Text(rows[i].$1, style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant)),
                const SizedBox(width: AppSpacing.gutter),
                Expanded(
                  child: rows[i].$2.isEmpty
                      ? Text(
                          'Not logged yet',
                          textAlign: TextAlign.right,
                          style: AppText.bodySm.copyWith(color: c.outline),
                        )
                      : Wrap(
                          alignment: WrapAlignment.end,
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [for (final v in rows[i].$2) _Pill(v)],
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(text, style: AppText.labelMd.copyWith(color: c.onSurface)),
    );
  }
}

class _PatternNote extends StatelessWidget {
  const _PatternNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A LITTLE PATTERN',
            style: AppText.labelSm.copyWith(
              color: c.onSecondaryContainer,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.1 * 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '“$text”',
            style: AppText.headlineSm.copyWith(
              color: c.primary,
              fontStyle: FontStyle.italic,
              height: 1.375,
            ),
          ),
        ],
      ),
    );
  }
}
