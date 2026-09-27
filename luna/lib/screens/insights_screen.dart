import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../providers/cycle_provider.dart';
import '../providers/log_provider.dart';
import '../providers/settings_provider.dart';
import '../services/insights_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import '../widgets/cycle_bars.dart';
import '../widgets/secret_trigger.dart';

/// Insights: on-device observations from logged cycles, symptoms and moods.
/// Port of luna-UI/insights.html.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _window = 6;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = context.watch<SettingsProvider>();
    final data = InsightsService.compute(
      periods: context.watch<CycleProvider>().periods,
      logs: context.watch<LogProvider>().allLogs,
      baselineCycleLength: settings.cycleLength,
      baselinePeriodLength: settings.periodLength,
      window: _window,
    );
    final bottom = 110 + MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: c.surface,
      child: Column(
        children: [
          const _Header(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.margin, AppSpacing.md, AppSpacing.margin, AppSpacing.xl + bottom),
              children: [
                _intro(c, data),
                _divider(c, 0.4),
                _numbers(c, data, settings),
                _divider(c, 0.3),
                _cycles(c, data, settings),
                _divider(c, 0.3),
                _patterns(c, data),
                _disclaimer(c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(AppColors c, double alpha) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        height: 1,
        color: c.outlineVariant.withValues(alpha: alpha),
      );

  Widget _intro(AppColors c, Insights data) {
    final n = data.trackedCycles;
    final subtitle = switch (n) {
      0 => 'No tracked cycles yet',
      1 => 'Observations based on 1 tracked cycle',
      _ => 'Observations based on $n tracked cycles',
    };
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CYCLE JOURNAL',
              style: AppText.labelSm.copyWith(color: c.secondary, letterSpacing: 11 * 0.1)),
          const SizedBox(height: 4),
          Text('What your cycle tells you',
              style: AppText.headlineLgMobile.copyWith(color: c.primary, height: 1.25)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: AppText.headlineSm
                  .weight(400)
                  .copyWith(color: c.onSurfaceVariant, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _numbers(AppColors c, Insights data, SettingsProvider settings) {
    Widget metric(int value, String label) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$value',
                    style: AppText.displayHeroMobile
                        .copyWith(color: c.primary, height: 1, letterSpacing: 56 * -0.025)),
                const SizedBox(width: 4),
                Text(value == 1 ? 'day' : 'days',
                    style: AppText.headlineSm
                        .copyWith(color: c.secondary, fontStyle: FontStyle.italic)),
              ],
            ),
            const SizedBox(height: 8),
            Text(label,
                style: AppText.labelMd
                    .weight(500)
                    .copyWith(color: c.onSurfaceVariant, letterSpacing: 12 * 0.025)),
          ],
        );

    final secondary = AppText.bodySm.copyWith(color: c.secondary, letterSpacing: 13 * 0.025);
    final Widget range = data.shortest == null
        ? Text('Based on your starting baseline', style: secondary)
        : Text.rich(
            TextSpan(style: secondary, children: [
              TextSpan(text: 'Shortest ${data.shortest}d'),
              TextSpan(text: '  ·  ', style: TextStyle(color: c.outlineVariant)),
              TextSpan(text: 'Longest ${data.longest}d'),
            ]),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: metric(data.averageCycle, 'Average cycle')),
                  const SizedBox(width: AppSpacing.gutter),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(left: AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: c.outlineVariant.withValues(alpha: 0.3)),
                        ),
                      ),
                      child: metric(data.averagePeriod, 'Average period'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md + AppSpacing.xs),
            child: Row(
              children: [
                Expanded(child: range),
                if (data.trackedCycles > InsightsService.windows.first) _windowPicker(c, data),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Subtle "3 · 6 · 12" selector for how many recent cycles to average.
  Widget _windowPicker(AppColors c, Insights data) {
    return Semantics(
      label: 'Average over last cycles',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final n in InsightsService.windows)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _window = n),
              child: Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: n == _window ? c.secondaryContainer : null,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text('$n',
                    style: AppText.labelSm.copyWith(
                        color: n == _window ? c.onSecondaryContainer : c.outline)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cycles(AppColors c, Insights data, SettingsProvider settings) {
    final bars = data.hasCycles
        ? data.bars
        : [
            CycleBar(
              length: settings.cycleLength,
              periodLength: settings.periodLength.clamp(1, settings.cycleLength),
              label: 'Baseline',
            ),
          ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your cycles', style: AppText.headlineSm.weight(400).copyWith(color: c.primary)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            data.hasCycles ? '“${data.consistency}”' : data.consistency,
            style: AppText.bodyMd.copyWith(
                color: c.onSurfaceVariant, fontStyle: FontStyle.italic, height: 1.625),
          ),
          const SizedBox(height: AppSpacing.md),
          CycleBars(bars: bars, muted: !data.hasCycles),
          const CycleBarsLegend(),
        ],
      ),
    );
  }

  Widget _patterns(AppColors c, Insights data) {
    final dots = [c.primaryContainer, c.secondary, c.secondaryFixedDim];
    final rows = <(Color, String, String)>[
      for (var i = 0; i < data.symptoms.length; i++)
        (dots[i % dots.length], data.symptoms[i].label, data.symptoms[i].sentence),
      if (data.mood != null) (c.tertiaryFixedDim, 'Mood', data.mood!.sentence),
    ];
    if (rows.isEmpty) {
      rows.add((
        c.outlineVariant,
        'Nothing logged yet',
        'Symptoms and moods you log each day will appear here.',
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your patterns', style: AppText.headlineSm.weight(400).copyWith(color: c.primary)),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _patternRow(c, rows[i], last: i == rows.length - 1),
          ],
        ],
      ),
    );
  }

  Widget _patternRow(AppColors c, (Color, String, String) row, {required bool last}) {
    final (dot, title, body) = row;
    return Container(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: c.outlineVariant.withValues(alpha: 0.2))),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: AppText.headlineSm.weight(400).copyWith(color: c.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Text(body,
                style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant, height: 1.625)),
          ),
        ],
      ),
    );
  }

  Widget _disclaimer(AppColors c) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, 0),
        child: Text(
          'Luna observations are based entirely on your personal logged history '
          'and are strictly non-diagnostic.',
          textAlign: TextAlign.center,
          style: AppText.bodySm
              .copyWith(color: c.outline, fontStyle: FontStyle.italic, height: 1.625),
        ),
      );
}

/// Top bar: spa · "Luna" · small "Insights" label, account icon → Settings.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: c.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin, vertical: AppSpacing.sm),
          child: Row(
            children: [
              SecretTrigger(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Symbols.spa, size: 20, weight: 300, color: c.primary),
                    const SizedBox(width: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('Luna',
                            style: AppText.headlineMd
                                .copyWith(color: c.primary, letterSpacing: 28 * -0.025)),
                        const SizedBox(width: 8),
                        Text('Insights',
                            style: AppText.labelSm
                                .weight(300)
                                .copyWith(color: c.onSurfaceVariant, letterSpacing: 11 * 0.05)),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Settings',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => MainShell.goToTab(context, 3),
                  child: Icon(Symbols.account_circle,
                      size: 24, weight: 300, color: c.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
