import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../providers/cycle_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../../utils/constants.dart';
import '../../utils/date_utils.dart';
import 'widgets/onboarding_step.dart';
import 'widgets/period_date_picker.dart';
import 'widgets/stepper.dart';

/// Three-step first-run flow: intro, last period start, cycle baselines.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _saving = false;

  /// Null when the user isn't sure / hasn't had one recently.
  DateTime? _lastPeriodStart;
  int _cycleLength = 29;
  int _periodLength = 5;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    final cycle = context.read<CycleProvider>();
    final settings = context.read<SettingsProvider>();

    try {
      final start = _lastPeriodStart;
      if (start != null) {
        await cycle.startPeriod(start);
        final end = addDays(start, _periodLength - 1);
        if (end.isBefore(today())) {
          await cycle.load(); // make sure the new period is in memory before closing it
          await cycle.endPeriod(end);
        }
      }
      await settings.completeOnboarding(cycleLength: _cycleLength, periodLength: _periodLength);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) _go(_page - 1);
      },
      child: Scaffold(
        body: PageView(
          controller: _pages,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _IntroStep(onContinue: () => _go(1)),
            _LastPeriodStep(
              selected: _lastPeriodStart,
              onSelected: (d) => setState(() => _lastPeriodStart = d),
              onBack: () => _go(0),
              onUnsure: () {
                setState(() => _lastPeriodStart = null);
                _go(2);
              },
              onContinue: () => _go(2),
            ),
            _BaselinesStep(
              cycleLength: _cycleLength,
              periodLength: _periodLength,
              onCycleChanged: (v) => setState(() => _cycleLength = v),
              onPeriodChanged: (v) => setState(() => _periodLength = v),
              onBack: () => _go(1),
              onFinish: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Step 1 --------------------------------------------------------------

class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hairline = BorderSide(color: c.outlineVariant.withValues(alpha: 0.4));

    return OnboardingStep(
      step: 1,
      ctaLabel: 'Continue',
      ctaTrailing: Text(
        '→',
        style: AppText.bodyLg.copyWith(color: c.surface, fontSize: 16).weight(300),
      ),
      onCta: onContinue,
      footnote: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.lock, size: 15, weight: 200, color: c.outline.withValues(alpha: 0.75)),
            const SizedBox(width: 8),
            Text(
              'No account or email required.',
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(color: c.onSurfaceVariant.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'INTRODUCTION',
              style: AppText.labelSm.copyWith(color: c.secondary, letterSpacing: 1.1),
            ),
            const SizedBox(height: 8),
            Text(
              'Meet Luna.',
              style: AppText.displayHeroMobile.copyWith(
                color: c.primary,
                height: 1.25,
                letterSpacing: -1.4,
              ),
            ),
            const SizedBox(height: 12 + 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Text(
                'Your simple, private period tracker.',
                style: AppText.bodyLg.copyWith(color: c.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 40),
            DecoratedBox(
              decoration: BoxDecoration(border: Border(top: hairline)),
              child: Column(
                children: [
                  const _FeatureRow(
                    title: '100% on-device',
                    tag: 'ENCRYPTED',
                    body:
                        'Your bodily health data never leaves your device. No cloud sync, no tracking.',
                  ),
                  Divider(height: 1, thickness: 1, color: hairline.color),
                  const _FeatureRow(
                    title: 'Calm, effortless check-ins',
                    tag: '20 SEC/DAY',
                    body:
                        'Designed to be opened once a day for 20 seconds. No overwhelming dashboards.',
                  ),
                  Divider(height: 1, thickness: 1, color: hairline.color),
                  const _FeatureRow(
                    title: 'Clear cycle awareness',
                    tag: 'HARMONY',
                    body: 'Rhythm observations crafted with quiet reverence for your body.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.title, required this.tag, required this.body});

  final String title;
  final String tag;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(title, style: AppText.headlineSm.copyWith(color: c.primary)),
              ),
              const SizedBox(width: 8),
              Text(
                tag,
                style: AppText.labelSm.copyWith(
                  color: c.secondary,
                  fontSize: 10.4,
                  letterSpacing: 1.04,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              body,
              style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant, height: 1.625),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Step 2 --------------------------------------------------------------

class _LastPeriodStep extends StatelessWidget {
  const _LastPeriodStep({
    required this.selected,
    required this.onSelected,
    required this.onBack,
    required this.onUnsure,
    required this.onContinue,
  });

  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onBack;
  final VoidCallback onUnsure;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return OnboardingStep(
      step: 2,
      onBack: onBack,
      ctaLabel: 'Continue',
      ctaTrailing: Icon(Symbols.arrow_forward, size: 18, weight: 200, color: c.surface),
      onCta: selected == null ? null : onContinue,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'When did your last period start?',
              style: AppText.headlineLgMobile.copyWith(
                color: c.primary,
                height: 1.25,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Select the approximate date. You can always refine this later in your calendar.',
              style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant, height: 1.625),
            ),
            const SizedBox(height: 32 + 8),
            PeriodDatePicker(selected: selected, onSelected: onSelected),
            const SizedBox(height: 32),
            Center(
              child: GestureDetector(
                onTap: onUnsure,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    "I'm not sure / haven't had one recently",
                    textAlign: TextAlign.center,
                    style: AppText.bodySm.copyWith(
                      color: c.onSurfaceVariant.withValues(alpha: 0.8),
                      decoration: TextDecoration.underline,
                      decorationColor: c.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ---- Step 3 --------------------------------------------------------------

class _BaselinesStep extends StatelessWidget {
  const _BaselinesStep({
    required this.cycleLength,
    required this.periodLength,
    required this.onCycleChanged,
    required this.onPeriodChanged,
    required this.onBack,
    required this.onFinish,
  });

  final int cycleLength;
  final int periodLength;
  final ValueChanged<int> onCycleChanged;
  final ValueChanged<int> onPeriodChanged;
  final VoidCallback onBack;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return OnboardingStep(
      step: 3,
      onBack: onBack,
      background: const _GrainBackground(),
      ctaLabel: 'Start tracking',
      ctaTrailing: Icon(Symbols.arrow_forward, size: 14, weight: 200, color: c.surface),
      onCta: onFinish,
      footnote: Text(
        'PRIVATE & ENCRYPTED ON DEVICE',
        textAlign: TextAlign.center,
        style: AppText.labelSm.copyWith(
          color: c.onSurfaceVariant.withValues(alpha: 0.6),
          letterSpacing: 0.55,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tell us about your usual cycle.',
              style: AppText.headlineLgMobile.copyWith(color: c.primary, letterSpacing: -0.8),
            ),
            const SizedBox(height: 12),
            Text(
              'Luna uses these baselines to estimate upcoming phases until your personal history builds.',
              style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant, height: 1.625),
            ),
            const SizedBox(height: 56),
            BaselineStepper(
              title: 'Cycle length',
              caption: 'Estimated interval',
              helper: 'Typical range is 24–35 days.',
              semanticName: 'cycle length',
              value: cycleLength,
              min: minCycleLength,
              max: maxCycleLength,
              onChanged: onCycleChanged,
            ),
            const SizedBox(height: 56),
            BaselineStepper(
              title: 'Period duration',
              caption: 'Bleed phase',
              helper: 'Typical range is 3–7 days.',
              semanticName: 'period duration',
              value: periodLength,
              min: minPeriodLength,
              max: maxPeriodLength,
              onChanged: onPeriodChanged,
            ),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(Symbols.all_inclusive, size: 15, weight: 200, color: c.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All estimations will adapt automatically as you record your rhythms over time.',
                    style: AppText.bodySm.copyWith(
                      color: c.onSurfaceVariant.withValues(alpha: 0.9),
                      fontStyle: FontStyle.italic,
                      height: 1.625,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dotted editorial grain plus a soft warm glow in the top-right corner.
class _GrainBackground extends StatelessWidget {
  const _GrainBackground();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _DotGridPainter(c.outlineVariant.withValues(alpha: 0.4))),
        ),
        Positioned(
          top: -160,
          right: -160,
          child: Container(
            width: 384,
            height: 384,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  c.secondaryContainer.withValues(alpha: 0.2),
                  c.secondaryContainer.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 24.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
