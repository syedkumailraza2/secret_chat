import 'package:flutter/material.dart';

import '../services/cycle_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';

/// Today hero: "CURRENT RHYTHM" eyebrow, headline, massive "DAY 17" and the
/// "Follicular phase · Day 17 of 29" line. Null snapshot = no history yet.
class CycleHeader extends StatelessWidget {
  const CycleHeader({super.key, required this.snapshot});

  final CycleSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = snapshot;
    final sub = AppText.bodyMd.copyWith(color: c.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              'CURRENT RHYTHM',
              style: AppText.labelSm.copyWith(color: c.onSurfaceVariant, letterSpacing: 0.1 * 11),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Your cycle, at a glance.', style: AppText.headlineLgMobile.copyWith(color: c.onSurface)),
        const SizedBox(height: AppSpacing.xs + AppSpacing.sm),
        Text(
          s == null ? 'DAY —' : 'DAY ${s.cycleDay}',
          style: AppText.displayHeroMobile.copyWith(
            color: c.primary,
            height: 1,
            letterSpacing: -0.025 * 56,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          s == null
              ? TextSpan(children: [
                  const TextSpan(text: 'No cycle yet · '),
                  TextSpan(
                    text: 'Log your first period to begin',
                    style: sub.copyWith(color: c.onSurface).weight(500),
                  ),
                ])
              : TextSpan(children: [
                  TextSpan(text: '${s.phase.label} phase · '),
                  TextSpan(
                    text: 'Day ${s.cycleDay} of ${s.cycleLength}',
                    style: sub.copyWith(color: c.onSurface).weight(500),
                  ),
                ]),
          style: sub,
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}
